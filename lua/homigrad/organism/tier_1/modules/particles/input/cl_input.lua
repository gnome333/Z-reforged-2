-- sprite pools use the SAME textures as world decals (see autorun/shitdecals.lua)
-- plain Material() calls never produce error-materials, unlike CreateMaterial+SetTexture at load time
local bloodmats_normal, bloodmats_artery, bloodmats_old, bloodmats_old_art = {}, {}, {}, {}
local function init_bloodmats()
	for n = 1, 11 do
		if n ~= 5 then
			local m = Material("effects/droplets/drop" .. n .. "_1")
			if not m:IsError() then bloodmats_normal[#bloodmats_normal + 1] = m end
		end
	end
	local ma = Material("effects/droplets/drop12_1")
	if not ma:IsError() then bloodmats_artery[1] = ma end
	for n = 1, 10 do
		local m1 = Material("decals/z_blood" .. n)
		if not m1:IsError() then bloodmats_old[#bloodmats_old + 1] = m1 end
		local m2 = Material("decals/arterial_blood" .. n)
		if not m2:IsError() then bloodmats_old_art[#bloodmats_old_art + 1] = m2 end
	end
end
init_bloodmats()
hook.Add("InitPostEntity", "hg_bloodmats_init", init_bloodmats)
local hg_old_blood_cv = ConVarExists("hg_old_blood") and GetConVar("hg_old_blood") or CreateClientConVar("hg_old_blood", 0, true, false, "new decals, or old", 0, 1)
local function pick_bloodmat(artery)
	local old = hg_old_blood_cv:GetBool()
	local pool = artery and (old and bloodmats_old_art or bloodmats_artery) or (old and bloodmats_old or bloodmats_normal)
	if #pool == 0 then return nil end
	return pool[math.random(1, #pool)]
end

--local mat_huy = Material("sprites/mat_jack_irregularcircle")
local texture = Material("decals/z_blood1"):GetTexture("$basetexture")
local mat_huy = Material("effects/blood_core")
mat_huy:SetTexture("$basetexture",texture)

local cloudmat = Material("effects/smoke_b")

--оставь это лучше выглядит
--[[for i = 4, 6 do
	mats[i-3] = Material("homigrad/decals/bld" .. i)
end]]
hg.bloodparticles1 = hg.bloodparticles1 or {}
hg.bloodparticles2 = hg.bloodparticles2 or {}
local vecZero = Vector(0, 0, 0)
local lastplaced = SysTime()
local hg_blood_fps = ConVarExists("hg_blood_fps") and GetConVar("hg_blood_fps") or CreateClientConVar("hg_blood_fps", 24, true, nil, "fps to draw blood", 12, 165)
local function addBloodPart(pos, vel, mat, w, h, artery, kishki, owner)
	--local fps = 1 / hg_blood_fps:GetInt() * 1
	--if lastplaced + fps > SysTime() then return end
	--lastplaced = SysTime()
	if LocalPlayer():GetNetVar("disappearance", nil) or (IsValid(owner) and owner:GetNetVar("disappearance", nil)) then return end

	local pos2 = Vector(pos)

	if #hg.bloodparticles1 > 200 then table.remove(hg.bloodparticles1, 1) end
	
	local basecol
	if not kishki then
		local vary = math.random(-15, 15)
		basecol = artery and {180 + vary, 15, 10} or {135 + vary, 8, 8}
		mat = mat or pick_bloodmat(artery) or mat_huy
		if not w or w < 2 then w = math.Rand(3.5, 5.5) end
		if not h or h < 2 then h = w end
	end
	hg.bloodparticles1[#hg.bloodparticles1 + 1] = {pos, pos2, vel, mat or mat_huy, w or 2, h or 2, CurTime(), artery = artery, kishki = kishki, owner = owner, start_velocity = IsValid(owner) and owner:GetVelocity() or vector_origin, lightcache = render.GetLightColor(pos), basecol = basecol}
end

local function addBloodPart2(pos, vel, mat, w, h, time, water, owner)
	if LocalPlayer():GetNetVar("disappearance", nil) or (IsValid(owner) and owner:GetNetVar("disappearance", nil)) then return end

	time = time or 30

	pos = pos + vecZero
	vel = vel + vecZero

	local pos2 = Vector()
	pos2:Set(pos)
	
	if #hg.bloodparticles2 > 200 then table.remove(hg.bloodparticles2, 1) end
	--if water and math.random(2) == 1 then return end
	--if water and math.random(3) > 1 then return end

	hg.bloodparticles2[#hg.bloodparticles2 + 1] = {pos, pos2, vel, mat or cloudmat, w or 60, h or 60, CurTime() + time, time, water = water, owner = owner}
end

hg.addBloodPart = addBloodPart
hg.addBloodPart2 = addBloodPart2

local Rand = math.Rand

local hg_bloodimpacts_cl = ConVarExists("hg_blood_impacts") and GetConVar("hg_blood_impacts") or CreateClientConVar("hg_blood_impacts", 0, true, false, "client-side blood impact clouds", 0, 1)

local function impact(pos,vel,mul)
	local max = math.min(mul,8)
	local iters = math.ceil(math.random(1, max) * 2.5)
	local velnorm = -vel:GetNormalized() * 5
	
	if hg_bloodimpacts_cl:GetBool() then
		addBloodPart2(pos + velnorm, -vel + Vector(Rand(-10, 10), Rand(-10, 10), Rand(-10, 10)) * 5, nil, 25, 25, 0.3)
		addBloodPart2(pos + velnorm, -vel / 2 + Vector(Rand(-10, 10), Rand(-10, 10), Rand(-10, 10)) * 5, nil, 25, 25, 0.3)
		addBloodPart2(pos + velnorm, -vel / 3 + Vector(Rand(-10, 10), Rand(-10, 10), Rand(-10, 10)) * 5, nil, 25, 25, 0.3)
	end

	for i = 1, iters do
		local size = 1--math.random(2, 4) * 1
		addBloodPart(pos, -vel * i / iters + Vector(Rand(-20, 20), Rand(-20, 20), 0), mat_huy, size, size, false, false)
	end
end

net.Receive("hg_bloodimpact", function()
	local pos = net.ReadVector()
	local vel = net.ReadVector() * 500
	local mul = net.ReadFloat()
	local amt = net.ReadInt(8)
	amt = math.Clamp(amt,0,32)
	//debugoverlay.Line(pos, vel, 5, color_white)
	for i = 1, amt do impact(pos,vel,mul) end
end)

local function explode(pos, size, force)
	size = size or 1
	local xx, yy = 12, 12
	local w, h = 360 / xx, 360 / yy
	for x = 1, xx * size do
		for y = 1, yy * size do
			addBloodPart2(pos + VectorRand(-10,10), VectorRand(-100,100) * size, cloudmat, 25, 25, 1)
			
			local dir = Vector(0, 0, -1)
			dir:Rotate(Angle(h * y * Rand(0.9, 1.1), w * x * Rand(0.9, 1.1), 0))
			dir[3] = dir[3] + Rand(0.5, 1.5)
			dir:Mul(250 * size)
			addBloodPart(pos, force * 0.2 + dir, mat_huy, math.Rand(5,10), math.Rand(5,10), false, true)
		end
	end
end

local limbs = {
	["lleg"] = "ValveBiped.Bip01_L_Calf",
	["rleg"] = "ValveBiped.Bip01_R_Calf",
	["larm"] = "ValveBiped.Bip01_L_Forearm",
	["rarm"] = "ValveBiped.Bip01_R_Forearm",
}

hook.Add("HG_OrganismChanged", "explodelegs", function(oldorg, org)
	local ply = org.owner
	local ent = hg.GetCurrentCharacter(ply)
	
	for ind, nam in pairs(limbs) do
		if !oldorg[ind.."amputated"] and org[ind.."amputated"] then
			local bone = ent:LookupBone(nam)

			timer.Simple(0, function()
				if IsValid(ent.bandagesModel) and ent.bandagesModel.BodygroupsApplied then
					ent.bandagesModel.BodygroupsApplied = false
				end
			end)

			if bone then
				local mat = ent:GetBoneMatrix(bone)

				if mat then
					explode(mat:GetTranslation() + mat:GetAngles():Forward() * 8, 0.5, Vector())
				end
			end
		end
	end
end)

hg.explode = explode

net.Receive("addfountain",function()
	local ent = net.ReadEntity()
	local force = net.ReadVector()
	
	--local bone = net.ReadInt(8)
	--local lpos = net.ReadVector()
	--local lang = net.ReadAngle()

	if not IsValid(ent) then return end

	local bone = ent:LookupBone("ValveBiped.Bip01_Neck1")
	if bone then
		local mat = ent:GetBoneMatrix(bone)
		if mat then
			explode(mat:GetTranslation() + mat:GetAngles():Forward() * 8, 0.5, force)
		end
	end
end)

net.Receive("bloodsquirt", function()
	local ent = net.ReadEntity()
	
	if not IsValid(ent) then return end

	local bone = net.ReadString()
	local bone = ent:LookupBone(bone)
	local mat = net.ReadMatrix()
	local pos = net.ReadVector()
	local dir = net.ReadVector()
	local len = dir:Length()

	local ent = hg.RagdollOwner(ent) or ent

	//local mat = ent:GetBoneMatrix(bone)
	local localPos, localDir = WorldToLocal(pos, dir:Angle(), mat:GetTranslation(), mat:GetAngles())

	local name = "squirtblood" .. ent:EntIndex() .. "_" .. tostring(bone) .. "_" .. math.Round(pos[1]) .. "_" .. math.Round(CurTime() * 100)
	local i = 250
	local maxI = i
	local vechuy = Vector(0,0,0)
	timer.Create(name, 0.01 * game.GetTimeScale(), i + 10, function()
		if not IsValid(ent) then timer.Remove(name) return end
		local ent = IsValid(ent.FakeRagdoll) and ent.FakeRagdoll or ent
		local amt = i / maxI
		local mat = ent:GetBoneMatrix(bone)
		if not mat then timer.Remove(name) return end
		local pos, dir = LocalToWorld(localPos, localDir, mat:GetTranslation(), mat:GetAngles())
		dir = dir:Forward() * len
		vechuy = vechuy + VectorRand(-amt * 5,amt * 5)
		addBloodPart(pos, dir * amt * 90 + vechuy * amt, mat_huy, math.Rand(3,3), math.Rand(3,3), true, false)
		i = i - 1
	end)
	timer.Adjust(name, 0)
end)

--net.Receive("blood particle explode", function() explode(net.ReadVector()) end)

--[[concommand.Add("testpart", function()
	if not LocalPlayer():IsAdmin() then return end
	local pos = Vector(0, 0, 0)
	addBloodPart(pos, Vector(25, 0, 0), mat_huy, math.random(10, 15), math.random(10, 15))
end)]]

net.Receive("bloodsquirt2", function()
	local ent = net.ReadEntity()
	
	if not IsValid(ent) then return end

	local bone = net.ReadString()
	local bone = ent:LookupBone(bone)
	local mat = net.ReadMatrix()
	local pos = net.ReadVector()
	local dir = net.ReadVector()
	local len = dir:Length()

	local ent = hg.RagdollOwner(ent) or ent
	local ply = ent

	//local mat = ent:GetBoneMatrix(bone)
	local localPos, localDir = WorldToLocal(pos, dir:Angle(), mat:GetTranslation(), mat:GetAngles())

	if ply == lply then
		localPos:Add(-Vector(2,-2,0))
	end

	local name = "squirtblood2" .. ent:EntIndex() .. "_" .. tostring(bone) .. "_" .. math.Round(CurTime() * 100)
	local i = 50
	local maxI = i
	local vechuy = Vector(0,0,0)
	timer.Create(name, 0.01 * game.GetTimeScale(), i + 10, function()
		if not IsValid(ent) then timer.Remove(name) return end
		local ent = IsValid(ent.FakeRagdoll) and ent.FakeRagdoll or ent
		local amt = math.max(i / maxI, 0.2)
		if math.random(5) == 1 then return end
		local mat = ent:GetBoneMatrix(bone)
		if not mat then timer.Remove(name) return end

		if ply == lply and (i == 50 or i == 25) then
			ViewPunch(Angle(15,0,0))
		end

		--ent:SetFlexWeight(ent:GetFlexIDByName("jaw_drop"), 1)

		local pos, dir = LocalToWorld(localPos, localDir, mat:GetTranslation(), mat:GetAngles())
		
		if lply == ply then
			dir = lply:EyeAngles()
		end

		dir = dir:Forward() * len
		addBloodPart(pos + VectorRand(-0.2, 0.2), dir * amt * 90 + VectorRand(-amt * 25,amt * 25), mat_huy, math.Rand(3,3), math.Rand(3,3), false, false)
		i = i - 1
	end)
	timer.Adjust(name, 0)
end)