hg.NanoSuit = hg.NanoSuit or {}

local NS = hg.NanoSuit

NS.WorkshopID = "3821562181"
NS.Model = "models/vuthakral/crysis/characters/nanosuit.mdl"
NS.ModelKorea = "models/vuthakral/crysis/characters/nanosuitd.mdl"
NS.CloakMaterial = "models/vuthakral/shaders/nanocloak"
NS.MatDir = "models/vuthakral/crysis/characters/nanosuit/"
NS.MaxEnergy = 100
NS.BaseSpeedMul = 1.35
NS.RegenRate = 16
NS.RegenDelay = 3
NS.ArmorAbsorb = 1
NS.ArmorEnergyMul = 0.35
NS.ArmorFallEnergyMul = 1
NS.ArmorFallMaxHitCost = 100
NS.StealthDrain = 1.4
NS.StealthWalkMul = 1.8
NS.StealthSprintMul = 6
NS.StealthMinEnergy = 5
NS.CloakAlpha = 3
NS.CloakRefractAlpha = 6
NS.ArmorHitboxSet = "nanosuit_armor"
NS.ArmorHitboxProtection = 22
NS.CloakTint = Color(255, 255, 255)
NS.CloakFadeIn = 0.8
NS.CloakFadeOut = 0.7
NS.ArmorGlowFadeIn = 0.6
NS.ArmorGlowFadeOut = 0.5
NS.SpeedGlowFadeIn = 0.6
NS.SpeedGlowFadeOut = 0.5
NS.ArmorMaxHitCost = 12
NS.RunShimmerSpeed = 300
NS.RegenOrganRate = 0.04
NS.GasFilterCost = 3
NS.RegenWoundRate = 10
NS.RegenPneumoRate = 0.5
NS.AnesthThreshold = 25
NS.AnesthInterval = 6
NS.AnesthCost = 4
NS.AnesthLevel = 1
NS.AnesthPainRate = 20
NS.ArmorRunMul = 0.65
NS.SpeedRunMul = 1.6
NS.SpeedWalkMul = 1.3
NS.SpeedDrain = 8
NS.SpeedMinEnergy = 5
NS.MeleeDamageMul = 5
NS.CloakShotCost = 45
NS.CloakGlitchTime = 3
NS.DefibInterval = 2.5
NS.DefibCost = 10
NS.DefibHeartDmg = 0.06
NS.DefibPain = 25
NS.DefibAdrenaline = 3
NS.StimInterval = 8
NS.StimCost = 8
NS.StimDamageDrop = 400
NS.StimAdrenaline = 2.5
NS.StimCoag = 3
NS.StimPain = 10
NS.MetabO2Rate = 3
NS.MetabO2Cap = 0.55
NS.MetabCost = 1.5
NS.MetabMinO2 = 12
NS.MetabNutrientRate = 1
NS.MetabNutrientCap = 12
NS.NVGEnergyDrain = 1
NS.NVGMinEnergy = 1

NS.Modes = {
	[0] = {Name = "STANDBY", NameRU = "ОЖИДАНИЕ", Color = Color(170, 190, 210)},
	[1] = {Name = "ARMOR", NameRU = "БРОНЯ", Color = Color(255, 160, 40)},
	[2] = {Name = "CLOAK", NameRU = "КЛОАК", Color = Color(90, 200, 255)},
	[3] = {Name = "SPEED", NameRU = "СКОРОСТЬ", Color = Color(255, 225, 60)},
}

function NS.GetMode(ply)
	return ply:GetNetVar("NS_Mode", 0)
end

function NS.IsStealth(ply)
	return ply:GetNetVar("NS_Stealth", false)
end

function NS.IsActive(ply)
	return NS.GetMode(ply) != 0
end

function NS.HasSuit(ply)
	return ply:GetNetVar("NS_Has", false) == true
end

function NS.ModeColor(mode)
	local mt = NS.Modes[mode]
	return mt and mt.Color or NS.Modes[0].Color
end

function NS.GetVariant(ply)
	if not IsValid(ply) then return 0 end
	return ply:GetNetVar("NS_Variant", 0)
end

function NS.GetModel(ply)
	if NS.GetVariant(ply) == 1 then return NS.ModelKorea end
	return NS.Model
end

function NS.IsSuitModel(mdl)
	return mdl == NS.Model or mdl == NS.ModelKorea
end

function NS.GetTeamVariant(ply)
	if IsValid(ply) and ply:Team() == 0 then return 1 end
	return 0
end

NS.Themes = {
	[0] = {
		Accent = Color(175, 255, 218, 255),
		BG = Color(8, 20, 18, 225),
		Seg = Color(16, 42, 38, 255),
		SegOn = Color(170, 255, 215, 255),
		Label = Color(10, 30, 22, 255),
		Helm = Color(150, 255, 210, 255),
		HelmDim = Color(150, 255, 210, 90),
		Shop = Color(90, 255, 190, 128),
		Price = Color(120, 235, 190, 255),
	},
	[1] = {
		Accent = Color(235, 195, 55, 255),
		BG = Color(26, 21, 5, 225),
		Seg = Color(64, 52, 12, 255),
		SegOn = Color(250, 210, 85, 255),
		Label = Color(34, 26, 5, 255),
		Helm = Color(250, 210, 80, 255),
		HelmDim = Color(250, 210, 80, 90),
		Shop = Color(255, 200, 40, 128),
		Price = Color(245, 205, 90, 255),
	},
}

function NS.GetTheme(ply)
	return NS.Themes[NS.GetVariant(ply)] or NS.Themes[0]
end

local armorHitboxes = {
	{"nshead", "ValveBiped.Bip01_Head1", Vector(3, -1.5, 0), Angle(0, 0, 0), Vector(6, 6, 4)},
	{"nschest", "ValveBiped.Bip01_Spine2", Vector(3, 2, 0), Angle(0, 0, 90), Vector(11, 7, 6)},
	{"nsbelly", "ValveBiped.Bip01_Spine1", Vector(-4, 2, 0), Angle(0, 0, 0), Vector(5, 7, 7)},
	{"nslarmup", "ValveBiped.Bip01_L_UpperArm", Vector(3, -1, 0), Angle(0, 0, 90), Vector(5, 4, 4)},
	{"nsrarmup", "ValveBiped.Bip01_R_UpperArm", Vector(3, -1, 0), Angle(0, 0, 90), Vector(5, 4, 4)},
	{"nslarmdown", "ValveBiped.Bip01_L_Forearm", Vector(3, -1, 0), Angle(0, 0, 90), Vector(5, 4, 4)},
	{"nsrarmdown", "ValveBiped.Bip01_R_Forearm", Vector(3, -1, 0), Angle(0, 0, 90), Vector(5, 4, 4)},
	{"nsllegup", "ValveBiped.Bip01_L_Thigh", Vector(4, 0, 0), Angle(0, 0, 90), Vector(8, 6, 5)},
	{"nsrlegup", "ValveBiped.Bip01_R_Thigh", Vector(4, 0, 0), Angle(0, 0, 90), Vector(8, 6, 5)},
	{"nsllegdown", "ValveBiped.Bip01_L_Calf", Vector(4, -1, 0), Angle(0, 0, 90), Vector(6, 5, 4)},
	{"nsrlegdown", "ValveBiped.Bip01_R_Calf", Vector(4, -1, 0), Angle(0, 0, 90), Vector(6, 5, 4)}
}

local function loadArmorHitboxes()
	if not hg.organism or not hg.organism.CreateHitBox then return end
	hg.organism.input_list = hg.organism.input_list or {}
	for _, b in ipairs(armorHitboxes) do
		hg.organism:CreateHitBox(b[1], hg.organism:HitBox(b[2], NS.ArmorHitboxSet, 1, b[3], b[4], b[5], NS.Modes[1].Color, true, NS.ArmorHitboxProtection))
	end
	hg.organism.input_list[NS.ArmorHitboxSet] = function(org, bone, dmg, dmgInfo, ...)
		local owner = org.owner
		if IsValid(owner) and not owner:IsPlayer() and not owner.ns_suit and hg.RagdollOwner then
			local resolved = hg.RagdollOwner(owner)
			if IsValid(resolved) then owner = resolved end
		end
		local suit = IsValid(owner) and owner.ns_suit
		if suit and suit.Mode == 1 and suit.Energy > 0 then return 1 end
		return 0
	end
end

if HG_BaseHitBoxSetLoaded then
	loadArmorHitboxes()
else
	hook.Add("HG_BaseHitBoxSetLoaded", "NanoSuitArmorHitboxes", loadArmorHitboxes)
end
