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

local MASK = MASK_SOLID
local BLOCK = CONTENTS_SOLID
local SIM_RATE = 0.25
local MAX_POCKETS = 1200
local MOVE_MULT = 1
local MAX_GEN = 2
local TAIL_LIFE = 50
local PUFF_LIFE = 420
local SKY_DIST = 12000

local wind = Vector(0, 0, 0)
local nextWind = 0

util.AddNetworkString("co_gas_vis")

local probes = {
	Vector(0, 0, 8),
	Vector(6, 0, 0),
	Vector(-6, 0, 0),
	Vector(0, 6, 0),
	Vector(0, -6, 0),
	Vector(0, 0, -8),
}

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

function hg.COGasAdd(pos, peak, vel, norepl, gen, heat)
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
	local pocket = {ppos, vvel, now + PUFF_LIFE, math.max(peak or 0.5, 0.1), now, 0}
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

local function skyExposed(part, now)
	if (part[8] or 0) < now then
		part[8] = now + 1

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
			local ctr = TraceLine({
				start = pos,
				endpos = cpos,
				mask = MASK
			})
			if not ctr.Hit and not ctr.StartSolid then
				hg.COGasAdd(cpos, (part[4] or 0.5) * 0.85, vel, false, (part[12] or 0) + 1, part[13])
			end
		end
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

				if (part[15] or 0) < now then
					part[15] = now + 0.5

					local side = Vector(-nrm.y, nrm.x, 0)
					if side:LengthSqr() < 1 then
						side = Vector(1, 0, 0)
					end
					side:Normalize()

					local offs = {
						side * 16,
						-side * 16,
						side * 34,
						-side * 34,
						Vector(0, 0, -20),
						Vector(0, 0, -42),
						Vector(0, 0, 18),
					}

					for i = 1, #offs do
						local off = offs[i]
						local from = pos + off
						local gap = TraceLine({
							start = from,
							endpos = from - nrm * 32,
							mask = MASK
						})

						if not gap.Hit and not gap.StartSolid then
							local dir = off - nrm * 14
							dir:Normalize()

							local enter = from - nrm * 6
							if util.IsInWorld(enter) then
								pos:Set(enter)
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
						local slide = TraceLine({
							start = pos,
							endpos = pos + tan * rem,
							mask = MASK
						})
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

hook.Add("PostCleanupMap", "co_gas_cleanup", function()
	hg.particles = {}
end)

concommand.Add("hg_cogas", function(ply)
	if not (IsValid(ply) and ply:IsAdmin()) then return end
	local pos = ply:GetPos() + ply:GetAimVector() * 60
	pos.z = pos.z + 20

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

local lastSim = 0
local lastNet = 0

hook.Add("Think", "co_gas_sim", function()
	local now = CurTime()

	if nextWind < now then
		nextWind = now + math_Rand(10, 25)

		local ang = math_Rand(0, math.pi * 2)
		local spd = math_Rand(20, 55)
		wind.x = math.cos(ang) * spd
		wind.y = math.sin(ang) * spd
		wind.z = 0
	end

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
		end
	end

	if lastSim + SIM_RATE > now then return end

	local dt = math_min(now - lastSim, 0.5)
	lastSim = now

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
end)
