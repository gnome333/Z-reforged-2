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

local MASK = MASK_SOLID_BRUSHONLY
local SIM_RATE = 0.25
local MAX_POCKETS = 400
local MOVE_MULT = 12
local TAIL_LIFE = 35
local PUFF_LIFE = 200
local SKY_DIST = 2400

util.AddNetworkString("co_gas_vis")

local function gasFreePos(pos)
	if band(PointContents(pos), CONTENTS_SOLID) == 0 then return pos end

	local escape = Vector(pos.x, pos.y, pos.z)
	for i = 1, 14 do
		escape.z = escape.z + 10

		if band(PointContents(escape), CONTENTS_SOLID) == 0 then return escape end
	end

	return nil
end

function hg.COGasAdd(pos, peak, vel, norepl)
	if not isvector(pos) then return nil end

	local fixed = gasFreePos(pos)
	if not fixed then return nil end

	local now = CurTime()

	local birth = TraceLine({
		start = fixed,
		endpos = fixed + Vector(0, 0, SKY_DIST),
		mask = MASK
	})

	if birth.HitSky or not birth.Hit then return nil end

	local particles = hg.particles
	if #particles >= MAX_POCKETS then
		table.remove(particles, 1)
	end

	local ppos = Vector(fixed.x, fixed.y, fixed.z)
	local vvel = vel and Vector(vel.x, vel.y, vel.z) or VectorRand(-40, 40)
	local pocket = {ppos, vvel, now + PUFF_LIFE, math.max(peak or 0.5, 0.1), now, 0}
	if norepl then pocket[11] = false end
	particles[#particles + 1] = pocket

	return pocket
end

local function skyExposed(part, now)
	if (part[8] or 0) < now then
		part[8] = now + 0.4

		local pos = part[1]
		local tr = TraceLine({
			start = pos,
			endpos = pos + Vector(0, 0, SKY_DIST),
			mask = MASK
		})

		part[7] = tr.HitSky or not tr.Hit
	end

	return part[7]
end

local function newAim()
	local ang = math_Rand(0, math.pi * 2)
	local spd = math_Rand(60, 90)
	return Vector(math.cos(ang) * spd, math.sin(ang) * spd, 0), math_Rand(2.5, 5)
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

	if part[11] ~= false and (now - part[5]) >= 10 then
		part[11] = false

		local cpos = Vector(pos.x + math_Rand(-10, 10), pos.y + math_Rand(-10, 10), pos.z + math_Rand(-6, 6))
		hg.COGasAdd(cpos, part[4] or 0.5, vel, true)
	end

	local shift = vel * dt * MOVE_MULT
	local dist = shift:Length()
	if dist > 0.1 then
		local tr = TraceLine({
			start = pos,
			endpos = pos + shift,
			mask = MASK
		})

		if tr.StartSolid then
			local lift = gasFreePos(pos)
			if lift then
				pos:Set(lift)
			else
				pos:Add(tr.HitNormal)
				pos.z = pos.z + 10
			end

			vel.z = 8
		elseif tr.Hit then
			local nrm = tr.HitNormal
			local hit = tr.HitPos
			local rem = dist * (1 - tr.Fraction)

			if nrm.z < -0.4 then
				pos:Set(hit)
				pos.z = pos.z + 1
				vel.z = 0
			elseif nrm.z > 0.4 then
				pos:Set(hit)
				pos.z = pos.z - 1
				vel.z = 0
			else
				pos:Set(hit)
				pos:Add(nrm)
				vel.z = math_max(vel.z * 0.5, 0)
			end

			local steer
			if nrm.z > -0.4 and nrm.z < 0.4 then
				local tan = aim - nrm * aim:Dot(nrm)
				if tan:Length2D() < 3 then
					tan = Vector(-nrm.y, nrm.x, 0)
				end
				tan:Normalize()

				steer = tan * math_Rand(60, 90)

				if rem > 2 then
					local slide = TraceLine({
						start = pos,
						endpos = pos + tan * rem,
						mask = MASK
					})
					if not slide.Hit then
						pos:Set(slide.HitPos)
					end
				end
			else
				steer = newAim()
			end

			aim:Set(steer)
			part[9] = now + math_Rand(3, 7)
			vel.x = steer.x
			vel.y = steer.y
		else
			pos:Set(tr.HitPos)
		end
	end

	vel.x = Lerp(math_min(dt * 2.4, 0.85), vel.x, aim.x) + math_Rand(-3, 3)
	vel.y = Lerp(math_min(dt * 2.4, 0.85), vel.y, aim.y) + math_Rand(-3, 3)

	local decay = math_max(1 - dt * 0.2, 0.5)
	vel.z = (vel.z * decay + dt * 4) + math_Rand(-4, 4)
	vel.z = math_max(-8, math_min(vel.z, 24))

	local peak = part[4]
	local age = now - part[5]
	local remain = part[3] - now

	if skyExposed(part, now) then
		part[3] = math_min(part[3], now)
		part[4] = 0
		part[6] = 0
		return true
	end

	part[6] = math_max(math_min(age / 2.5, 1) * math_min(remain / TAIL_LIFE, 1) * peak, 0)
	return false
end

hook.Add("PostCleanupMap", "co_gas_cleanup", function()
	hg.particles = {}
end)

concommand.Add("hg_cogas", function(ply)
	if not (IsValid(ply) and ply:IsAdmin()) then return end
	local pos = ply:GetPos() + ply:GetAimVector() * 60
	pos.z = pos.z + 20
	hg.COGasAdd(pos, 0.8)
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

local lastSim = 0
local lastNet = 0

hook.Add("Think", "co_gas_sim", function()
	local now = CurTime()

	if lastNet < now then
		lastNet = now + 0.5

		local viewers = {}
		for _, ply in ipairs(player.GetAll()) do
			if ply.COGasVis then viewers[#viewers + 1] = ply end
		end

		if #viewers > 0 then
			local sendPos, sendInt = {}, {}
			local count = 0

			for i = 1, #hg.particles do
				local part = hg.particles[i]
				local inten = part[6]
				if inten and inten > 0.02 then
					count = count + 1
					sendPos[count] = part[1]
					sendInt[count] = inten
				end
			end

			net.Start("co_gas_vis")
			net.WriteUInt(math_min(count, 255), 8)
			for i = 1, count do
				net.WriteVector(sendPos[i])
				net.WriteUInt(math_floor(sendInt[i] * 100 + 0.5), 8)
			end
			net.Send(viewers)
		end
	end

	if lastSim > now then return end

	local dt = math_min(now - lastSim, 1)
	lastSim = now + SIM_RATE

	local particles = hg.particles
	for i = #particles, 1, -1 do
		local part = particles[i]
		if not istable(part) or not isvector(part[1]) or not isvector(part[2]) or (part[3] or 0) < now then
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
end)
