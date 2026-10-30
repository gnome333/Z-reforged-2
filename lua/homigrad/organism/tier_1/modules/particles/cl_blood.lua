hg.bloodparticles1 = hg.bloodparticles1 or {}
bloodparticles_hook = bloodparticles_hook or {}

local tr = {
	//filter = function(ent) return not ent:IsPlayer() and not ent:IsRagdoll() end
}

local col_red_darker = Color(122,0,0)
local col_red = Color(200,0,0)
local vecDown = Vector(0, 0, -40)
local vecZero = Vector(0, 0, 0)
local LerpVector = LerpVector
local math_random = math.random
local table_remove = table.remove
local util_Decal = util.Decal
local util_TraceLine = util.TraceLine
local render_SetMaterial = render.SetMaterial
local render_DrawSprite = render.DrawSprite
local render_DrawBeam = render.DrawBeam
local render_GetLightColor = render.GetLightColor

local hg_blood_draw_distance = ConVarExists("hg_blood_draw_distance") and GetConVar("hg_blood_draw_distance") or CreateClientConVar("hg_blood_draw_distance", 1024, true, nil, "distance to draw blood", 0, 4096)
local hg_blood_sprites = ConVarExists("hg_blood_sprites") and GetConVar("hg_blood_sprites") or CreateClientConVar("hg_blood_sprites", 1, true, nil, "blood is sprites or trails", 0, 1)

hook.Add("PostCleanupMap","removeblooddroplets",function()
	hg.bloodparticles1 = {}
	hg.bloodpositions = {}
	hg.bloodpos_order = {}
	bloodpos_order = hg.bloodpos_order
	hg.bloodcount = 0
end)

local mat_huy = Material("effects/blood_core")
local lightcolor = Color(0, 0, 0, 255)
local hg_blood_lighting = ConVarExists("hg_blood_lighting") and GetConVar("hg_blood_lighting") or CreateClientConVar("hg_blood_lighting", 1, true, nil, "cache blood lighting", 0, 1)
local hg_blood_light_min = ConVarExists("hg_blood_light_min") and GetConVar("hg_blood_light_min") or CreateClientConVar("hg_blood_light_min", 0.35, true, nil, "min blood brightness in shadow", 0, 1)
local mat_trail = Material("effects/blood_core")
local hg_blood_trail = ConVarExists("hg_blood_trail") and GetConVar("hg_blood_trail") or CreateClientConVar("hg_blood_trail", 1, true, nil, "draw velocity blood trails", 0, 1)
bloodparticles_hook[1] = function(anim_pos, mul)
	local int = hg_blood_draw_distance:GetInt()
	local lp = LocalPlayer()
	local lplypos = lp:EyePos()
	local lplyang = lp:EyeAngles():Forward()
	local dstsqr = int * int
	local sprites = hg_blood_sprites:GetBool()
	local cacheLight = hg_blood_lighting:GetBool()
	local lightmin = hg_blood_light_min:GetFloat()
	local trails = hg_blood_trail:GetBool()
	render_SetMaterial(mat_huy)
	for i = 1, #hg.bloodparticles1 do
		local part = hg.bloodparticles1[i]
		if not part then continue end
		local p2 = part[2]
		if (p2 - lplypos):Dot(lplyang) < 0 then continue end
		if (p2 - lplypos):LengthSqr() > dstsqr then continue end
		local pos = LerpVector(anim_pos, p2, part[1])
		local lv = part.lightcache
		if not cacheLight or not lv then
			lv = render_GetLightColor(pos)
			if cacheLight then part.lightcache = lv end
		end
		local bright = lightmin + (1 - lightmin) * math.min(lv[1] + lv[2] + lv[3] * 0.5, 1.5) / 1.5
		local base = part.basecol
		if base then
			lightcolor.r = math.min(base[1] * bright, 255)
			lightcolor.g = math.min(base[2] * bright + 4, 255)
			lightcolor.b = math.min(base[3] * bright + 4, 255)
		else
			lightcolor.r = math.min((part.artery and 45 or 20) * lv[1], 255)
			lightcolor.g = 0
			lightcolor.b = 0
		end
		lightcolor.a = 255
		if part.kishki then
			render_SetMaterial(part[4])
			render_DrawSprite(pos, part[5], part[6], lightcolor)
			render_SetMaterial(mat_huy)
		else
			render_SetMaterial(part[4] or mat_huy)
			if sprites then
				render_DrawSprite(pos, part[5], part[6], lightcolor)
			end
			local vel = part[3]
			local spd = vel and vel:Length() or 0
			local prev = part.prev
			if trails and prev and spd > 150 and not part.hashitsomething then
				local tailLenSqr = (pos - prev):LengthSqr()
				if tailLenSqr > 0.25 and tailLenSqr < 1600 then
					local tailLen = math.sqrt(tailLenSqr)
					local want = math.min(tailLen * 1.5, 24)
					local dir = (pos - prev) / tailLen
					local tailEnd = pos - dir * want
					local mid = pos - dir * (want * 0.5)
					local w1 = math.min(math.max(part[5] * 0.5, 1), 4)
					render_SetMaterial(mat_trail)
					lightcolor.a = 160
					render_DrawBeam(pos, mid, w1, 0, 0.5, lightcolor)
					lightcolor.a = 80
					render_DrawBeam(mid, tailEnd, w1 * 0.5, 0.5, 1, lightcolor)
					lightcolor.a = 255
					render_SetMaterial(part[4] or mat_huy)
				end
			elseif not sprites then
				local delta = part[2] - part[1]
				render_DrawBeam(pos - delta * 1 / mul / 24 * 0.5, pos + delta * 1 / mul / 24 * 0.5, 1, 0, 1, lightcolor)
			end
		end
	end
end

local hg_old_blood = ConVarExists("hg_old_blood") and GetConVar("hg_old_blood") or CreateClientConVar("hg_old_blood", 0, true, false, "new decals, or old", 0, 1)

hg.bloodpositions = hg.bloodpositions or {}
hg.bloodcount = hg.bloodcount or 0
hg.bloodpos_order = hg.bloodpos_order or {}
local bloodpos_order = hg.bloodpos_order
local MAX_BLOODPOS = 2048
local nextDecalSound = 0
local function decalSound(pos, tr)
	if nextDecalSound > CurTime() then return end
	if (pos - LocalPlayer():EyePos()):LengthSqr() > 1500 * 1500 then return end
	nextDecalSound = CurTime() + 0.2
	sound.Play("homigrad/blooddrip" .. math_random(1, 4) .. ".wav", pos, math.random(10, 60), tr.MatType == MAT_METAL and math.random(100, 120) or math.random(80, 120))
	if tr.MatType == MAT_METAL then
		sound.Play("zbattle/blood_drop_metal.mp3", pos, math.random(10, 40), math.random(100, 120))
	end
end
local function decalBlood(pos, normal, tr, artery, owner)
	-- quantized key with separator (fix collision "1|23|4" == "12|3|4")
	local vec = math.Round(pos[1] / 8) .. "," .. math.Round(pos[2] / 8) .. "," .. math.Round(pos[3] / 8)

	local n = (hg.bloodpositions[vec] or 0) + 1
	hg.bloodpositions[vec] = n
	if n == 1 then
		bloodpos_order[#bloodpos_order + 1] = vec
		if #bloodpos_order > MAX_BLOODPOS then
			local old = table.remove(bloodpos_order, 1)
			hg.bloodpositions[old] = nil
		end
	end

	decalSound(pos, tr)
	if n > 6 then return end

	if artery then
		if !hg_old_blood:GetBool() then
			util_Decal("Arterial.Blood2" .. math.Clamp(n, 1, 5), pos + normal, pos - normal, owner)
		else
			util_Decal("Arterial.Blood1", pos + normal, pos - normal, owner)
		end
	else
		if !hg_old_blood:GetBool() then
			util_Decal("Normal.Blood2" .. math.Clamp(n + math.random(0, 2), 1, 5), pos + normal, pos - normal, owner)
-- was unreachable (n>6 returns above): util.Decal Blood removed
		else
			util_Decal("Normal.Blood1", pos + normal, pos - normal, owner)
		end
	end
end
--дурак, просто смотри сколько ентити стоит в одном месте
local tr2 = { collisiongroup = COLLISION_GROUP_WORLD, output = {} }

function hg.IsInWorld( pos )
	tr2.start = pos
	tr2.endpos = pos

	return not util_TraceLine( tr2 ).HitWorld
end

local gravity = GetConVar("sv_gravity")

local radius = 20000
local radiusSqr = radius * radius

hook.Add("InitPostEntity", "sizeget", function()
	radius = hg.GetWorldSize()
    radiusSqr = radius * radius
end)

bloodparticles_hook[2] = function(mul)
	local grav = gravity:GetInt() / 10
    local time = CurTime()
	local gravvec = vecDown * mul * (math.max(0.0, grav))
	for i = #hg.bloodparticles1, 1, -1 do
		local part = hg.bloodparticles1[i]
		if not part then table_remove(hg.bloodparticles1, i) continue end
		
		local pos = part[1]
		local posSet = part[2]

		if not part.prev then part.prev = Vector(posSet) part.prev2 = Vector(posSet) end
		part.prev2:Set(part.prev)
		part.prev:Set(posSet)

		tr.start = posSet
		tr.endpos = tr.start + part[3] * mul
		tr.collisiongroup = part.kishki and COLLISION_GROUP_WORLD or COLLISION_GROUP_NONE

		local result = util_TraceLine(tr)
		if result.Hit then part.lightcache = nil end
		local hitPos = result.HitPos
		
		if radiusSqr < hitPos:LengthSqr() then table_remove(hg.bloodparticles1, i) continue end
		
        if bit.band(util.PointContents(hitPos), CONTENTS_WATER) == CONTENTS_WATER then
			hg.addBloodPart2(hitPos, part[3] / 20 + VectorRand(-1, 1), nil, nil, nil, nil, true)

			table_remove(hg.bloodparticles1, i)
			continue
		end
		
		if time - part[7] >= 30 then
			table_remove(hg.bloodparticles1, i)

			continue
		end

		if result.Hit and result.Entity:IsWorld() then
			table_remove(hg.bloodparticles1, i)
			local dir = result.HitNormal
			decalBlood(result.HitPos, dir, result, part.artery, part.owner)
			
			
			--sound.Play("zbattle/blood_drop.mp3", hitPos, math.random(10, 60), math.random(120, 120))
			--sound.Play("homigrad/blooddrip" .. math_random(1, 4) .. ".wav", hitPos, math.random(10, 60), math.random(80, 120))
			
			continue
		else
			local ph = 0
			local shouldhit = true
			if IsValid(result.Entity) then
				ph = result.Entity:TranslatePhysBoneToBone(result.PhysicsBone)
				ph = ph != -1 and ph or 0
				local nam = result.Entity:GetBoneName(ph)
				
				shouldhit = !(result.Entity.organism and hg.amputatedlimbs2[nam] and result.Entity.organism[hg.amputatedlimbs2[nam].."amputated"])
			end
			
			result.Hit = result.Hit and shouldhit

			if result.Hit then
				--local down = vecDown * mul * (math.max(0, grav))
				local down = result.HitNormal
				local nextpos = (result.Normal + down):GetNormalized() * 5

				local insolid = result.StartSolid and IsValid(result.Entity)
				if not insolid and (part.nextput or 0) < CurTime() then
					part.nextput = CurTime() + 1

					decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner)
				end

				if insolid then
					if result.Entity:IsVehicle() then
						table_remove(hg.bloodparticles1, i)
					
						continue
					end

					local center = result.Entity:GetBoneMatrix(ph)
					local len = result.Entity:BoneLength(ph + 1)

					if center then
						center = center:GetTranslation() + (len and center:GetAngles():Forward() * len or vector_origin) * 0.5
						nextpos = -(center - hitPos - vecDown * 1):GetNormalized() * 5
					end
				end

				local pulldown = (-vector_up * (grav / 600)):Cross(-result.HitNormal:Angle():Right())
				nextpos:Add(pulldown)
				part.lerpedmove = LerpVector(1, part.lerpedmove or part[3] * mul, nextpos * mul * 2)
				
				if part.lerpedmove:LengthSqr() < 0.1 * mul then
					decalBlood(result.HitPos, result.HitNormal, result, part.artery, part.owner)
					
					table_remove(hg.bloodparticles1, i)
					
					continue
				end

				pos:Set(posSet + part.start_velocity * mul)
				posSet:Set(hitPos + part.lerpedmove + part.start_velocity * mul)
				part.hashitsomething = true
			else
				if part.hashitsomething then
					part.hashitsomething = nil
					--part[3][3] = 0
					part[3] = (posSet - pos) / mul * 1--part.lerpedmove / mul
					--part.lerpedmove = nil
					pos:Set(posSet)
					posSet:Set(posSet)
				else
					pos:Set(posSet + part.start_velocity * mul)
					posSet:Set(tr.start + part[3] * mul + part.start_velocity * mul)
				end
			end

			part.lasthit = result.Hit
		end

		part[3] = LerpVector(0.25 * mul, part[3], vecZero)
		if !(result.Hit) then
			part[3]:Add(gravvec)
		--else
			--part[3]:Set(vecDown * mul * (math.max(0.1, grav)))
		end
	end
end