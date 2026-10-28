--[[-------------------------------------------------------------------------
	CO gas — orchestration layer

	This file owns the public API (hg.COGasAdd), the wind field, the network
	layer and the admin commands. The actual gas dynamics live in
	sv_co_grid.lua (hg_co_physics 1) or in the legacy pocket simulation below
	(hg_co_physics 0).

	Both models expose the same public surface, so nothing else in the addon
	has to care which one is active:
		hg.COGasAdd(pos, peak, vel, norepl, gen, heat)
		hg.particles                       (legacy model only)
		hg.COGetConcentration(pos)         (nil when the grid is disabled)
		net "co_gas_vis" / "co_gas_grid"
---------------------------------------------------------------------------]]

hg.co = hg.co or {}
local co = hg.co

local math_min = math.min
local math_max = math.max
local math_Rand = math.Rand
local math_random = math.random
local math_floor = math.floor
local CurTime = CurTime
local TraceLine = util.TraceLine
local PointContents = util.PointContents
local Lerp = Lerp
local band = bit.band
local isvector = isvector
local istable = istable

local MASK = MASK_SOLID
local BLOCK = CONTENTS_SOLID
local SIM_RATE = 0.25
local MAX_POCKETS = 1200
local MOVE_MULT = 1
local MAX_GEN = 2
local TAIL_LIFE = 50
local PUFF_LIFE = 420
local SKY_DIST = 12000

local MAX_SEND = 800
local SEND_RADIUS = 6000

--[[-------------------------------------------------------------------------
	Wind field
	Shared with the grid solver through co.wind.
---------------------------------------------------------------------------]]
--[[-------------------------------------------------------------------------
	Wind field
	---------------------------------------------------------------------------
	The wind exists for exactly three jobs, all of them outdoors:

	  1. Dispersal in the open. Gas released outside is carried away and
	     diluted instead of hanging over the map forever.
	  2. Ventilation through openings. A doorway or a broken window is a face
	     with partial openness, so the wind blowing past it drags gas out of
	     the room (and pushes it in). A room with a way out clears; a sealed
	     room does not.
	  3. A reason to close the doors during a gas attack.

	Indoors the wind is deliberately zero - the outside wind does not blow
	through a closed room. What mixes a sealed room is turbulent diffusion
	(see hg_co_diffusion), which is how it works in reality.
---------------------------------------------------------------------------]]
local wind = Vector(0, 0, 0)
local nextWind = 0

local function updateWind(now)
	if nextWind < now then
		nextWind = now + math_Rand(10, 25)

		local ang = math_Rand(0, math.pi * 2)
		local spd = math_Rand(20, 55)
		wind.x = math.cos(ang) * spd
		wind.y = math.sin(ang) * spd
		wind.z = 0
	end

	co.wind = wind
end

util.AddNetworkString("co_gas_vis")
util.AddNetworkString("co_gas_grid")

--[[-------------------------------------------------------------------------
	Trace budgets for the legacy pocket model
---------------------------------------------------------------------------]]
local SKY_TRACE_BUDGET = 320
local GAP_TRACE_BUDGET = 1000
local skyTracesLeft = SKY_TRACE_BUDGET
local gapTracesLeft = GAP_TRACE_BUDGET

-- Reused trace description tables: util.TraceLine copies what it needs, so the
-- same table can be reused for every trace instead of allocating a new one
local trSky = { start = nil, endpos = Vector(), mask = MASK }
local trMove = { start = nil, endpos = nil, mask = MASK }
local trChild = { start = nil, endpos = nil, mask = MASK }
local trGap = { start = nil, endpos = nil, mask = MASK }
local trSlide = { start = nil, endpos = nil, mask = MASK }

-- Preallocated vectors used by the gap probing (rebuilt in place, never allocated)
local gapOffs = {
	Vector(), Vector(), Vector(), Vector(),
	Vector(0, 0, -20), Vector(0, 0, -42), Vector(0, 0, 18),
}
local tmpFrom = Vector()
local tmpEnd = Vector()
local tmpEnter = Vector()

local probes = {
	Vector(0, 0, 8),
	Vector(6, 0, 0),
	Vector(-6, 0, 0),
	Vector(0, 6, 0),
	Vector(0, -6, 0),
	Vector(0, 0, -8),
}

--[[-------------------------------------------------------------------------
	Public API
---------------------------------------------------------------------------]]
local function gasFreePos(pos)
	if band(PointContents(pos), BLOCK) == 0 then
		if util.IsInWorld(pos) then return pos end
		return nil
	end

	for i = 1, #probes do
		local p = pos + probes[i]
		if band(PointContents(p), BLOCK) == 0 and util.IsInWorld(p) then
			return p
		end
	end

	return nil
end

-- Legacy pocket creation (only used when hg_co_physics is 0)
local function pocketAdd(pos, peak, vel, norepl, gen, heat)
	if not isvector(pos) then return nil end

	local fixed = gasFreePos(pos)
	if not fixed then return nil end

	local now = CurTime()

	local particles = hg.particles
	if #particles >= MAX_POCKETS then
		table.remove(particles, 1)
	end

	local ppos = Vector(fixed.x, fixed.y, fixed.z)
	local vvel = vel and Vector(vel.x, vel.y, vel.z) or VectorRand(-40, 40)
	local pocket = { ppos, vvel, now + PUFF_LIFE, math.max(peak or 0.5, 0.1), now, 0 }
	pocket[12] = gen or 0
	if heat then
		pocket[13] = math_max(heat, 0)
	else
		pocket[13] = math_min(math_max(peak or 0.5, 0), 1)
	end
	pocket[14] = math_Rand(0, 100)
	if norepl then pocket[11] = false end
	particles[#particles + 1] = pocket

	return pocket
end

function hg.COGasAdd(pos, peak, vel, norepl, gen, heat)
	if not isvector(pos) then return nil end

	if co.physics:GetBool() then
		-- Grid model: the injection is a source term in the cell that holds
		-- this position. `peak` keeps its old meaning (relative strength),
		-- it is just scaled into concentration units.
		local amount = (peak or 0.5) * co.INJECT_SCALE
		return hg.COAddSource(pos, amount, heat and heat * 40 or 0)
	end

	return pocketAdd(pos, peak, vel, norepl, gen, heat)
end

--[[-------------------------------------------------------------------------
	Legacy pocket simulation
---------------------------------------------------------------------------]]
local function skyExposed(part, now)
	if (part[8] or 0) < now then
		-- Out of trace budget: keep the previous result and retry next tick
		if skyTracesLeft <= 0 then return part[7] end
		skyTracesLeft = skyTracesLeft - 1

		part[8] = now + 1

		local pos = part[1]
		trSky.start = pos
		trSky.endpos:SetUnpacked(pos.x, pos.y, pos.z + SKY_DIST)

		local tr = TraceLine(trSky)
		part[7] = tr.HitSky or not tr.Hit
	end

	return part[7]
end

local function newAim()
	local ang = math_Rand(0, math.pi * 2)
	local spd = math_Rand(60, 110)
	return Vector(math.cos(ang) * spd, math.sin(ang) * spd, 0), math_Rand(4, 9)
end

local function simPocket(part, dt, now)
	part[4] = part[4] or 0.5
	part[5] = part[5] or now

	local pos = part[1]
	local vel = part[2]

	local aim = part[10]
	if not isvector(aim) or (part[9] or 0) < now then
		local steer, ttl
		if isvector(aim) and math_random(2) == 1 then
			steer = Vector(aim.x, aim.y, 0) * math_Rand(0.8, 1.3)
			ttl = math_Rand(3, 7)
		else
			steer, ttl = newAim()
		end
		part[9] = now + ttl
		part[10] = steer
		aim = steer
	end

	if part[11] ~= false and (now - part[5]) >= 10 and (part[12] or 0) < MAX_GEN then
		part[11] = false

		for i = 1, 2 do
			local cpos = Vector(pos.x + math_Rand(-20, 20), pos.y + math_Rand(-20, 20), pos.z + math_Rand(-12, 12))
			trChild.start = pos
			trChild.endpos = cpos
			local ctr = TraceLine(trChild)
			if not ctr.Hit and not ctr.StartSolid then
				pocketAdd(cpos, (part[4] or 0.5) * 0.85, vel, false, (part[12] or 0) + 1, part[13])
			end
		end
	end

	local shift = vel * dt * MOVE_MULT
	local dist = shift:Length()
	if dist > 0.1 then
		trMove.start = pos
		trMove.endpos = pos + shift
		local tr = TraceLine(trMove)

		if tr.StartSolid then
			return true
		elseif tr.Hit then
			local nrm = tr.HitNormal
			local hit = tr.HitPos
			local rem = dist * (1 - tr.Fraction)

			if nrm.z < -0.4 then
				pos:Set(hit + nrm)
				vel.z = 0
			elseif nrm.z > 0.4 then
				pos:Set(hit + nrm)
				vel.z = 0
			else
				pos:Set(hit + nrm)
				vel.z = math_max(vel.z * 0.5, 0)
			end

			local steer
			local gapFound = false

			if nrm.z > -0.4 and nrm.z < 0.4 then
				local tan = aim - nrm * aim:Dot(nrm)
				if tan:Length2D() < 3 then
					tan = Vector(-nrm.y, nrm.x, 0)
				end
				tan:Normalize()

				-- Gap probing is the most expensive part of the simulation: only run it
				-- while we have budget left, otherwise retry it on the next tick
				if (part[15] or 0) < now and gapTracesLeft > 0 then
					part[15] = now + 0.5

					local side = Vector(-nrm.y, nrm.x, 0)
					if side:LengthSqr() < 1 then
						side = Vector(1, 0, 0)
					end
					side:Normalize()

					local offs = gapOffs
					offs[1]:SetUnpacked(side.x * 16, side.y * 16, 0)
					offs[2]:SetUnpacked(side.x * -16, side.y * -16, 0)
					offs[3]:SetUnpacked(side.x * 34, side.y * 34, 0)
					offs[4]:SetUnpacked(side.x * -34, side.y * -34, 0)

					for i = 1, #offs do
						if gapTracesLeft <= 0 then break end

						local off = offs[i]
						tmpFrom:SetUnpacked(pos.x + off.x, pos.y + off.y, pos.z + off.z)

						gapTracesLeft = gapTracesLeft - 1

						trGap.start = tmpFrom
						tmpEnd:SetUnpacked(tmpFrom.x - nrm.x * 32, tmpFrom.y - nrm.y * 32, tmpFrom.z - nrm.z * 32)
						trGap.endpos = tmpEnd
						local gap = TraceLine(trGap)

						if not gap.Hit and not gap.StartSolid then
							local dir = off - nrm * 14
							dir:Normalize()

							tmpEnter:SetUnpacked(tmpFrom.x - nrm.x * 6, tmpFrom.y - nrm.y * 6, tmpFrom.z - nrm.z * 6)
							if util.IsInWorld(tmpEnter) then
								pos:Set(tmpEnter)
							end

							steer = dir * math_Rand(70, 120)
							gapFound = true
							break
						end
					end
				end

				if not gapFound then
					steer = tan * math_Rand(70, 120)

					if rem > 2 then
						trSlide.start = pos
						trSlide.endpos = pos + tan * rem
						local slide = TraceLine(trSlide)
						if not slide.Hit and not slide.StartSolid then
							pos:Set(slide.HitPos)
						end
					end
				end
			else
				steer = newAim()
			end

			aim:Set(steer)
			part[9] = now + (gapFound and 2 or math_Rand(3, 7))
			vel.x = steer.x
			vel.y = steer.y
		else
			pos:Set(tr.HitPos)
		end
	end

	local ph = part[14] or 0
	local turbX = math.sin(now * 0.5 + ph) * 30
	local turbY = math.cos(now * 0.37 + ph * 1.3) * 30
	local wk = part[7] and 1 or 0.25
	local k = math_min(dt * 1.5, 1)

	vel.x = Lerp(k, vel.x, aim.x + wind.x * wk + turbX) + math_Rand(-2.5, 2.5)
	vel.y = Lerp(k, vel.y, aim.y + wind.y * wk + turbY) + math_Rand(-2.5, 2.5)

	local heat = part[13] or 0
	if heat > 0 then
		part[13] = math_max(heat - dt * 0.07, 0)
	end

	local riseTarget = heat > 0.05 and (10 + heat * 240) or -12
	vel.z = Lerp(math_min(dt * 2, 1), vel.z, riseTarget) + math_Rand(-3, 3)
	vel.z = math_max(-10, math_min(vel.z, 300))

	local peak = part[4]
	local age = now - part[5]
	local remain = part[3] - now

	if skyExposed(part, now) then
		part[4] = peak * 0.5
		if part[4] < 0.05 then
			part[3] = now
			part[4] = 0
			part[6] = 0
			return true
		end
	end

	part[6] = math_max(math_min(age / 2.5, 1) * math_min(remain / TAIL_LIFE, 1) * part[4], 0)
	return false
end

--[[-------------------------------------------------------------------------
	Networking
---------------------------------------------------------------------------]]
local sendPos = {}
local sendInt = {}
local sendCells = {}

local function getViewers()
	local viewers = nil
	for _, ply in ipairs(player.GetAll()) do
		if ply.COGasVis then
			viewers = viewers or {}
			viewers[#viewers + 1] = ply
		end
	end
	return viewers
end

-- Legacy: send pockets
local function sendPockets(viewers)
	local count = 0

	for i = 1, #hg.particles do
		if count >= MAX_POCKETS then break end

		local part = hg.particles[i]
		local inten = part[6]
		if inten and inten > 0.02 then
			count = count + 1
			sendPos[count] = part[1]
			sendInt[count] = inten
		end
	end

	net.Start("co_gas_vis")
	net.WriteUInt(count, 16)
	for i = 1, count do
		net.WriteVector(sendPos[i])
		net.WriteUInt(math_min(math_floor(sendInt[i] * 100 + 0.5), 255), 8)
	end
	net.Send(viewers)

	for i = 1, count do
		sendPos[i] = nil
		sendInt[i] = nil
	end
end

-- Grid: send the cells that carry gas near a viewer
local function sendGrid(viewers)
	local list, count = hg.COGetCells()
	if count <= 0 then return end

	local L = hg.COGetCellSize()
	local radiusSqr = SEND_RADIUS * SEND_RADIUS
	local sendCount = 0

	for i = 1, count do
		local cell = list[i]
		local c = cell.c
		if c > 0.02 then
			local p = cell.pos
			for j = 1, #viewers do
				if p:DistToSqr(viewers[j]:GetPos()) < radiusSqr then
					sendCount = sendCount + 1
					sendCells[sendCount] = cell
					break
				end
			end
		end
	end

	if sendCount <= 0 then return end

	-- Cap the payload: keep the strongest cells so the field looks stable
	if sendCount > MAX_SEND then
		table.sort(sendCells, function(a, b) return a.c > b.c end)
		for i = MAX_SEND + 1, sendCount do
			sendCells[i] = nil
		end
		sendCount = MAX_SEND
	end

	net.Start("co_gas_grid")
	net.WriteFloat(L)
	net.WriteUInt(sendCount, 16)
	for i = 1, sendCount do
		local cell = sendCells[i]
		-- Concentration is capped for the wire: anything above 1.0 already
		-- renders as fully opaque, and 0..1 fits comfortably in 8 bits.
		local c = cell.c
		if c > 1 then c = 1 end
		net.WriteVector(cell.pos)
		net.WriteUInt(math_min(math_floor(c * 100 + 0.5), 255), 8)
	end
	net.Send(viewers)

	for i = 1, sendCount do
		sendCells[i] = nil
	end
end

--[[-------------------------------------------------------------------------
	Commands
---------------------------------------------------------------------------]]
concommand.Add("hg_cogas", function(ply)
	if not (IsValid(ply) and ply:IsAdmin()) then return end
	local pos = ply:GetPos() + ply:GetAimVector() * 60
	pos.z = pos.z + 20

	if co.physics:GetBool() then
		-- Fill the surrounding volume, not a single point
		local L = hg.COGetCellSize()
		for i = 1, 24 do
			hg.COAddSource(pos + VectorRand(-L, L), 0.08, 15)
		end
		return
	end

	for i = 1, 24 do
		hg.COGasAdd(pos + VectorRand(-30, 30), 0.8)
	end
end)

concommand.Add("hg_covis", function(ply, _, args)
	if not (IsValid(ply) and ply:IsAdmin()) then return end

	local state
	if args[1] == "1" then
		state = true
	elseif args[1] == "0" then
		state = false
	else
		state = not ply.COGasVis
	end

	ply.COGasVis = state
	ply:ChatPrint("CO gas visibility: " .. (state and "ON" or "OFF"))
end)

--[[-------------------------------------------------------------------------
	Main tick
---------------------------------------------------------------------------]]
local lastSim = 0
local lastNet = 0

hook.Add("PostCleanupMap", "co_gas_cleanup", function()
	hg.particles = {}
	lastSim = 0
	lastNet = 0
end)

hook.Add("Think", "co_gas_sim", function()
	local now = CurTime()

	-- The wind field is shared by both models
	updateWind(now)

	local gridMode = co.physics:GetBool()

	if gridMode then
		-- Volumetric solver (sv_co_grid.lua)
		if hg.COGridThink then hg.COGridThink() end
	else
		-- Legacy pocket solver
		if lastSim + SIM_RATE <= now then
			local dt = math_min(now - lastSim, 0.5)
			lastSim = now

			skyTracesLeft = SKY_TRACE_BUDGET
			gapTracesLeft = GAP_TRACE_BUDGET

			local particles = hg.particles
			for i = #particles, 1, -1 do
				local part = particles[i]
				if not istable(part) or not isvector(part[1]) or not isvector(part[2]) or (part[3] or 0) < now or not util.IsInWorld(part[1]) then
					table.remove(particles, i)
					continue
				end

				if simPocket(part, dt, now) then
					table.remove(particles, i)
				end
			end

			while #particles > MAX_POCKETS do
				table.remove(particles, 1)
			end
		end
	end

	-- Network the visible gas twice per second
	if lastNet < now then
		lastNet = now + 0.5

		local viewers = getViewers()
		if viewers then
			if gridMode then
				sendGrid(viewers)
			else
				sendPockets(viewers)
			end
		end
	end
end)
