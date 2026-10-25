SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "Carpati Md. 95"
SWEP.Author = "ROMARM Cugir"
SWEP.Instructions = "Romanian semi-automatic pistol chambered in .380 ACP (9x17mm). A commercial export variant of the Md. 1974, featuring a steel frame and a 7-round magazine."
SWEP.Category = "Weapons - Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_pist_elite_single.mdl"
SWEP.WorldModelFake = "models/weapons/arccw/c_uc_carpati.mdl"

SWEP.WepSelectIcon2 = Material("entities/arccw_uc_carpati.png")
SWEP.IconOverride = "entities/arccw_uc_carpati.png"
SWEP.WepSelectIcon2box = true

SWEP.FakeAttachment = "muzzle"
SWEP.FakePos = Vector(-15, 2.5, 9)
SWEP.FakeAng = Angle(-1, 0, 0)
SWEP.AttachmentPos = Vector(1,2,0.5)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.MagIndex = nil

SWEP.FakeEjectBrassATT = "shell"

SWEP.AnimList = {
	["idle"] = "base_idle",
	["reload"] = "base_reload",
	["reload_empty"] = "base_reloadempty",
}

SWEP.CustomShell = "9x17mm"
SWEP.EjectAng = Angle(0,0,0)
SWEP.Stupidgun = true

SWEP.weight = 1
SWEP.punchmul = 1.5
SWEP.punchspeed = 3
SWEP.ScrappersSlot = "Secondary"

SWEP.LocalMuzzlePos = Vector(0,0.4,8)
SWEP.LocalMuzzleAng = Angle(-0.8,0,-5)
SWEP.WeaponEyeAngles = Angle(0,0,0)

SWEP.weaponInvCategory = 2
SWEP.ShellEject = "EjectBrass_9mm"
SWEP.Primary.ClipSize = 7
SWEP.Primary.DefaultClip = 7
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "9x17 mm"
SWEP.Primary.Cone = 0.02
SWEP.Primary.Damage = 24
SWEP.Primary.Sound = {"weapons/arccw_uc/carpati/fire-01.ogg", 75, 90, 100}
SWEP.SupressedSound = {"weapons/arccw_uc/carpati/fire_supp.ogg", 65, 90, 100}
SWEP.Primary.SoundEmpty = {"zcitysnd/sound/weapons/m1911/handling/m1911_empty.wav", 75, 100, 105, CHAN_WEAPON, 2}
SWEP.Primary.Force = 20
SWEP.Primary.Wait = PISTOLS_WAIT
SWEP.ReloadTime = 2.8
SWEP.FakeReloadSounds = {
	[0.3] = "zcitysnd/sound/weapons/m9/handling/m9_magout.wav",
	[0.70] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
	[0.9] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
}

SWEP.FakeEmptyReloadSounds = {
	[0.3] = "weapons/tfa_ins2/usp_tactical/magout.wav",
	[0.5] = "weapons/universal/uni_pistol_draw_01.wav",
	[0.65] = "zcitysnd/sound/weapons/m9/handling/m9_magin.wav",
	[0.75] = "zcitysnd/sound/weapons/m9/handling/m9_maghit.wav",
	[0.9] = "weapons/m45/m45_boltrelease.wav",
}

SWEP.FakeReloadEvents = {
	[0.3] = function( self, timeMul ) 
		if CLIENT and self:Clip1() < 1 then
			hg.CreateMag( self, Vector(0,55,-55) )
			self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 1.2 * timeMul,nil,nil,function() 
			end)
		end 
		if CLIENT and self:Clip1() > 0 then
			self:GetOwner():PullLHTowards("ValveBiped.Bip01_L_Thigh", 1 * timeMul,nil,nil,function() 
			end)
		end 
	end,
	[0.85] = function(self,timeMul)
	end,
}

SWEP.DeploySnd = {"homigrad/weapons/draw_pistol.mp3", 55, 100, 110}
SWEP.HolsterSnd = {"homigrad/weapons/holster_pistol.mp3", 55, 100, 110}
SWEP.UseCustomWorldModel = true
SWEP.WorldPos = Vector(2, -0.8, 2.6)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.HoldType = "revolver"
SWEP.ZoomPos = Vector(0, -0.348, 8.4948)
SWEP.RHandPos = Vector(-13.5, 0, 3)
SWEP.LHandPos = false
SWEP.attPos = Vector(0, -2, -0.5)
SWEP.attAng = Angle(0, 0, 0)
SWEP.SprayRand = {Angle(-0.03, -0.03, 0), Angle(-0.05, 0.03, 0)}
SWEP.Ergonomics = 2
SWEP.Penetration = 4
SWEP.lengthSub = 25
SWEP.DistSound = "weapons/arccw_uc/carpati/profiles/9x18/dist-01.wav"
SWEP.holsteredBone = "ValveBiped.Bip01_R_Thigh"
SWEP.holsteredPos = Vector(0, 1, -7)
SWEP.holsteredAng = Angle(0, 20, 30)
SWEP.shouldntDrawHolstered = true

SWEP.availableAttachments = {
	barrel = {
		[1] = {"supressor4", Vector(0,0,0), {}},
        ["mount"] = Vector(-1.2,0.43,0),
    }
}

SWEP.RHPos = Vector(12,-4.5,3)
SWEP.RHAng = Angle(0,-5,90)
SWEP.LHPos = Vector(-1.2,-1.4,-2.8)
SWEP.LHAng = Angle(5,9,-100)

SWEP.ShootAnimMul = 3
SWEP.SightSlideOffset = 0.8

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_R_Forearm"
SWEP.ViewPunchDiv = 50
SWEP.FakeMagDropBone = "Magazine"
SWEP.MagModel = "models/weapons/upgrades/w_magazine_makarov_8.mdl"

SWEP.lmagpos = Vector(0,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(-12.7,0,-2.4)
SWEP.lmagang2 = Angle(90,0,-110)

local magvec = Vector(0, 2, 0)
function SWEP:DrawPost()
	local wep = self:GetWeaponEntity()
	if CLIENT and IsValid(wep) then
		self.shooanim = LerpFT(0.4, self.shooanim or 0, (self:Clip1() > 0 or self.reload) and 0 or 1)
		wep:ManipulateBonePosition(65, Vector(0, 2 * self.shooanim, 0), false)
	end
		if self:Clip1() < 0 then
		wep:ManipulateBonePosition(65, magvec, false)
		end
end

SWEP.InspectAnimWepAng = {
	Angle(0,0,0),
	Angle(6,0,5),
	Angle(15,0,14),
	Angle(16,0,16),
	Angle(4,0,12),
	Angle(-6,0,-2),
	Angle(-15,7,-15),
	Angle(-16,18,-35),
	Angle(-17,17,-42),
	Angle(-18,16,-44),
	Angle(-14,10,-46),
	Angle(-2,2,-4),
	Angle(0,0,0)
}

SWEP.FakeBodyGroups = "00010"

-- ============================================================
-- РЕДКИЙ СКИН (SetSkin 3) — шанс 10%
-- ============================================================
SWEP.RareSkinChance = 0.10 -- 10% шанс выпадения редкого скина

function SWEP:ModelCreated(model)
	model:SetBodyGroups(self.FakeBodyGroups)
	
	-- Определяем, будет ли у этого экземпляра редкий скин
	if not self._skinRolled then
		self._skinRolled = true
		self._isRareSkin = (math.random() < self.RareSkinChance)
	end
	
	if self._isRareSkin then
		model:SetSkin(3) -- редкий скин
	else
		model:SetSkin(2) -- обычный скин
	end
end