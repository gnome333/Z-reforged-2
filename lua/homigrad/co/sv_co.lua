hg.co = hg.co or {}
local co = hg.co

local math_min = math.min
local math_max = math.max
local math_Rand = math.Rand
local math_floor = math.floor
local math_cos = math.cos
local math_sin = math.sin
local CurTime = CurTime
local TraceLine = util.TraceLine
local PointContents = util.PointContents
local Lerp = Lerp
local band = bit.band
local isvector = isvector
local istable = istable

local MASK = MASK_SOLID
local BLOCK = CONTENTS_SOLID
local SIM_RATE = 0.2
local MAX_GEN = 1
local TAIL_LIFE = 50
local PUFF_LIFE = 170
local SKY_DIST = 12000
local SKY_HALF_LIFE = 0.6
local CHILD_DELAY = 34
local CHILD_PEAK = 0.7
local CHILD_SPREAD = 14
local AIM_SPEED_MIN = 34
local AIM_SPEED_MAX = 58
local AIM_TURN = 0.45
local AIM_TURN_BIG = 1.1
local AIM_TURN_BIG_CHANCE = 0.12
local STEER_RATE = 0.75
local TURB_AMP = 30
local TURB_FREQ = 0.22
local TURB_FREQ2 = 0.17
local JITTER = 0.8
local RISE_COLD = -5
local RISE_HOT = 6
local RISE_HEAT = 150
local MAX_SEND = 1200
local SEND_MIN_INT = 0.02

local wind = Vector(0, 0, 0)
local nextWind = 0

local function updateWind(now)
	if nextWind < now then
		nextWind = now + math_Rand(12, 28)

		local ang = math_Rand(0, math.pi * 2)
		local spd = math_Rand(14, 38)
		wind.x = math_cos(ang) * spd
		wind.y = math_sin(ang) * spd
		wind.z = 0
	end

	co.wind = wind
end

util.AddNetworkString("co_gas_vis")

local SKY_TRACE_BUDGET = 320
local GAP_TRACE_BUDGET = 1000
local skyTracesLeft = SKY_TRACE_BUDGET
local gapTracesLeft = GAP_TRACE_BUDGET

local trSky = { start = nil, endpos = Vector(), mask = MASK }
local trMove = { start = nil, endpos = nil, mask = MASK }
local trChild = { start = nil, endpos = nil, mask = MASK }
local trGap = { start = nil, endpos = nil, mask = MASK }
local trSlide = { start = nil, endpos = nil, mask = MASK }

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

local function pocketAdd(pos, peak, vel, norepl, gen, heat)
	if not isvector(pos) then return nil end

	local fixed = gasFreePos(pos)
	if not fixed then return nil end

	local now = CurTime()

	local particles = hg.particles
	local maxParts = co.maxparts:GetInt()
	if #particles >= maxParts then
		table.remove(particles, 1)
	end

	local ppos = Vector(fixed.x, fixed.y, fixed.z)
	local vvel = vel and Vector(vel.x, vel.y, vel.z) or VectorRand(-15, 15)
	local pocket = { ppos, vvel, now + PUFF_LIFE, math_max(peak or 0.5, 0.1), now, 0 }
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
	return pocketAdd(pos, peak, vel, norepl, gen, heat)
end

local function skyExposed(part, now)
	if (part[8] or 0) < now then
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
	local spd = math_Rand(AIM_SPEED_MIN, AIM_SPEED_MAX)
	return Vector(math_cos(ang) * spd, math_sin(ang) * spd, 0), math_Rand(6, 11)
end

local function turnAim(aim)
	local a = math_Rand(-AIM_TURN, AIM_TURN)
	if math_Rand(0, 1) < AIM_TURN_BIG_CHANCE then
		a = a + (math_Rand(0, 1) < 0.5 and -AIM_TURN_BIG or AIM_TURN_BIG)
	end
	local c, s = math_cos(a), math_sin(a)
	local dir = Vector(aim.x * c - aim.y * s, aim.x * s + aim.y * c, 0)
	if dir:LengthSqr() < 1 then
		dir = Vector(1, 0, 0)
	end
	dir:Normalize()
	return dir * math_Rand(AIM_SPEED_MIN, AIM_SPEED_MAX)
end

local function simPocket(part, dt, now)
	part[4] = part[4] or 0.5
	part[5] = part[5] or now

	local pos = part[1]
	local vel = part[2]

	local aim = part[10]
	if not isvector(aim) or (part[9] or 0) < now then
		local steer, ttl
		if isvector(aim) then
			steer = turnAim(aim)
			ttl = math_Rand(6, 11)
		else
			steer, ttl = newAim()
		end
		part[9] = now + ttl
		part[10] = steer
		aim = steer
	end

	if part[11] ~= false and (now - part[5]) >= CHILD_DELAY and (part[12] or 0) < MAX_GEN then
		part[11] = false

		local cpos = Vector(pos.x + math_Rand(-CHILD_SPREAD, CHILD_SPREAD), pos.y + math_Rand(-CHILD_SPREAD, CHILD_SPREAD), pos.z + math_Rand(-8, 8))
		trChild.start = pos
		trChild.endpos = cpos
		local ctr = TraceLine(trChild)
		if not ctr.Hit and not ctr.StartSolid then
			pocketAdd(cpos, (part[4] or 0.5) * CHILD_PEAK, vel, false, (part[12] or 0) + 1, part[13])
		end
	end

	local shift = vel * (dt * co.speed:GetFloat())
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

							local ja = math_Rand(-0.9, 0.9)
							local cj, sj = math_cos(ja), math_sin(ja)
							steer = Vector(dir.x * cj - dir.y * sj, dir.x * sj + dir.y * cj, 0) * math_Rand(40, 70)
							gapFound = true
							break
						end
					end
				end

				if not gapFound then
					steer = tan * math_Rand(40, 70)

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
			part[9] = now + (gapFound and math_Rand(1.5, 3) or math_Rand(2.5, 5))
			vel.x = steer.x
			vel.y = steer.y
		else
			pos:Set(tr.HitPos)
		end
	end

	local ph = part[14] or 0
	local turb = TURB_AMP * co.turbulence:GetFloat()
	local turbX = math_sin(now * TURB_FREQ + ph) * turb
	local turbY = math_cos(now * TURB_FREQ2 + ph * 1.3) * turb
	local wk = part[7] and 1 or 0.25
	local k = math_min(dt * STEER_RATE, 1)

	vel.x = Lerp(k, vel.x, aim.x + wind.x * wk + turbX) + math_Rand(-JITTER, JITTER)
	vel.y = Lerp(k, vel.y, aim.y + wind.y * wk + turbY) + math_Rand(-JITTER, JITTER)

	local heat = part[13] or 0
	if heat > 0 then
		part[13] = math_max(heat - dt * 0.12, 0)
	end

	local riseTarget = heat > 0.05 and (RISE_HOT + heat * RISE_HEAT) or RISE_COLD
	vel.z = Lerp(math_min(dt * 1.2, 1), vel.z, riseTarget) + math_Rand(-1, 1)
	vel.z = math_max(-8, math_min(vel.z, 220))

	local peak = part[4]
	local age = now - part[5]
	local remain = part[3] - now

	if skyExposed(part, now) then
		part[4] = peak * 0.5 ^ (dt / SKY_HALF_LIFE)
		if part[4] < 0.05 then
			part[3] = now
			part[4] = 0
			part[6] = 0
			return true
		end
	end

	part[6] = math_max(math_min(age / 4, 1) * math_min(remain / TAIL_LIFE, 1) * part[4], 0)
	return false
end

local sendPos = {}
local sendInt = {}

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

local function sendPockets(viewers)
	local count = 0

	for i = 1, #hg.particles do
		if count >= MAX_SEND then break end

		local part = hg.particles[i]
		local inten = part[6]
		if inten and inten > SEND_MIN_INT then
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

concommand.Add("hg_cogas", function(ply)
	if not (IsValid(ply) and ply:IsAdmin()) then return end
	local pos = ply:GetPos() + ply:GetAimVector() * 60
	pos.z = pos.z + 20

	for i = 1, 10 do
		hg.COGasAdd(pos + VectorRand(-30, 30), 0.6)
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

concommand.Add("hg_co_clear", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end
	hg.particles = {}
end)

concommand.Add("hg_co_count", function(ply)
	local msg = string.format("[CO gas] pockets=%d  speed=%.2f  turbulence=%.2f",
		#hg.particles, co.speed:GetFloat(), co.turbulence:GetFloat())
	if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

local lastSim = 0
local lastNet = 0

hook.Add("PostCleanupMap", "co_gas_cleanup", function()
	hg.particles = {}
	lastSim = 0
	lastNet = 0
end)

hook.Add("Think", "co_gas_sim", function()
	local now = CurTime()

	updateWind(now)

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

		local maxParts = co.maxparts:GetInt()
		while #particles > maxParts do
			table.remove(particles, 1)
		end
	end

	if lastNet < now then
		lastNet = now + 0.5

		local viewers = getViewers()
		if viewers then
			sendPockets(viewers)
		end
	end
end)
