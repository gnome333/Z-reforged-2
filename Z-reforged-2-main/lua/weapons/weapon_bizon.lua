SWEP.Base = "homigrad_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "PP-19 Bizon"
SWEP.Author = "Victor Kalashnikov / Izhmash"
SWEP.Instructions = "Submachine gun chambered in 9x18 mm PM\n\nRate of fire 680 rounds per minute\n\n64-round helical magazine"
SWEP.Category = "Weapons - Machine-Pistols"
SWEP.Slot = 2
SWEP.SlotPos = 10
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/w_smg_mp5.mdl"
SWEP.WorldModelFake = "models/weapons/c_mw_bizon.mdl"

SWEP.FakePos = Vector(-12, 2.5, 6.8)
SWEP.FakeAng = Angle(0, 0, -2)
SWEP.AttachmentPos = Vector(0,0,0)
SWEP.AttachmentAng = Angle(0,0,0)
SWEP.FakeAttachment = "muzzle"
SWEP.FakeBodyGroups = "00000"

SWEP.FakeEjectBrassATT = "shell"

SWEP.CanEpicRun = true
SWEP.EpicRunPos = Vector(2,10,2)


SWEP.FakeViewBobBone = "CAM_Homefield"
SWEP.FakeReloadSounds = {
	[0.22] = "weapons/universal/uni_crawl_l_03.wav",
	[0.34] = "bizon/foley/wpn_iw8_bizon_mag_out_1.wav",
	[0.38] = "bizon/foley/wpn_iw8_bizon_first_raise_start_1.wav",
	[0.51] = "weapons/universal/uni_crawl_l_02.wav",
	[0.62] = "bizon/foley/wpn_iw8_bizon_mag_in1_1.wav",
	[0.80] = "bizon/foley/wpn_iw8_bizon_mag_in2_1.wav",
	[0.85] = "weapons/universal/uni_crawl_l_05.wav",

}

SWEP.FakeEmptyReloadSounds = {
	[0.3] = "bizon/foley/wpn_iw8_bizon_empty_mag_out_1.wav",
	[0.51] = "weapons/universal/uni_crawl_l_02.wav",
	[0.62] = "bizon/foley/wpn_iw8_bizon_empty_mag_in1_1.wav",
	[0.72] = "bizon/foley/wpn_iw8_bizon_empty_mag_in2_1.wav",
	[0.85] = "bizon/foley/wpn_iw8_bizon_charge_1.wav"
}

SWEP.MagModel = "models/pp-19 bizon magazine.mdl" 

SWEP.DropMagBone = 111
SWEP.lmagpos = Vector(-10,0,0)
SWEP.lmagang = Angle(0,0,0)
SWEP.lmagpos2 = Vector(0,0,0)
SWEP.lmagang2 = Angle(0,0,0)
SWEP.FakeMagDropBone = 111

SWEP.FakeViewBobBone = "ValveBiped.Bip01_R_Hand"
SWEP.FakeViewBobBaseBone = "ValveBiped.Bip01_L_UpperArm"
SWEP.ViewPunchDiv = 70

SWEP.AnimList = {
	["idle"] = "idle",
	["reload"] = "reload",
	["reload_empty"] = "reload_empty",
}
 if CLIENT then
	local vector_full = Vector(1,1,1)
	SWEP.FakeReloadEvents = {
		[0.15] = function( self, timeMul )
		end,
		[0.16] = function( self, timeMul )
			--self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 0.58 * timeMul)
		end,
		[0.25] = function( self, timeMul )
			self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 0.5 * timeMul,nil,nil,function() 
			end)
		end,
		[0.65] = function(self,timeMul)
			if self:Clip1() > 0 then
				self:GetOwner():PullLHTowards("ValveBiped.Bip01_Spine2", 1 * timeMul,nil,nil,function() 
					self:GetWM():ManipulateBoneScale(44, vector_origin)
					self:GetWM():ManipulateBoneScale(45, vector_origin)
					self:GetWM():ManipulateBoneScale(46, vector_origin)
				end)
				--self:GetWM():ManipulateBoneScale(44, vector_origin)
				--self:GetWM():ManipulateBoneScale(45, vector_origin)
				--self:GetWM():ManipulateBoneScale(46, vector_origin)
			end
		end,
		[0.50] = function(self,timeMul)
			if self:Clip1() < 1 then
				hg.CreateMag( self, Vector(25,55,0),nil, true )
			end
		end
	}
end

function SWEP:ModelCreated(model)
	if CLIENT and self:GetWM() and not isbool(self:GetWM()) and isstring(self.FakeBodyGroups) then
		self:GetWM():ManipulateBoneScale(123, vector_origin)
		self:GetWM():SetBodyGroups(self.FakeBodyGroups)
	end
end 



SWEP.GunCamPos = Vector(4,-15,-6)
SWEP.GunCamAng = Angle(190,-5,-100)

SWEP.ReloadHold = nil
SWEP.FakeVPShouldUseHand = false
SWEP.holsteredBone = "ValveBiped.Bip01_Spine2"
SWEP.holsteredPos = Vector(8, -5, -6)
SWEP.holsteredAng = Angle(210, 0, 180)


SWEP.WepSelectIcon2 = Material("entities/tfa_mw_bizon.png")
SWEP.IconOverride = "entities/tfa_mw_bizon.png"

SWEP.CustomShell = "9x18"
--SWEP.EjectPos = Vector(0,-20,5)
--SWEP.EjectAng = Angle(0,90,0)

SWEP.LocalMuzzlePos = Vector(14.706,-0.488,3.525)
SWEP.LocalMuzzleAng = Angle(-0.5,0.2,0)
SWEP.WeaponEyeAngles = Angle(0,5,0)

SWEP.weight = 2.7
SWEP.ScrappersSlot = "Primary"
SWEP.weaponInvCategory = 1
SWEP.Primary.ClipSize = 64
SWEP.Primary.DefaultClip = 64
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "9x18 mm"
SWEP.Primary.Cone = 0
SWEP.Primary.Damage = 20
SWEP.Primary.Spread = 0
SWEP.Primary.Force = 25
SWEP.animposmul = 2
SWEP.Primary.Sound = {"bizon/fire/fire.wav", 75, 120, 130}
SWEP.SupressedSound = {"bizon/fire/fire_supp.wav", 65, 90, 100}
SWEP.Primary.Wait = 0.088
SWEP.ReloadTime = 4.5
SWEP.ReloadSoundes = {
	"none",
	"none",
	"weapons/kryceks_swep/mp5/boltback.wav",
	"none",
	"none",
	"weapons/kryceks_swep/mp5/magout.wav",
	"none",
	"bizon/foley/wpn_iw8_bizon_mag_in1_1.wav",
	"none",
	"bizon/foley/wpn_iw8_bizon_mag_in2_1.wav",
	"none",
	"none",
	"none",
	"none"
}

SWEP.PPSMuzzleEffect = "muzzleflash_mp5" -- shared in sh_effects.lua

SWEP.ShellEject = "EjectBrass_9mm"
SWEP.HoldType = "rpg"
SWEP.ZoomPos = Vector(0, -1.1531, 6.182)

SWEP.RHandPos = Vector(0, -1, 0)
SWEP.LHandPos = Vector(7, -2, -2)
SWEP.availableAttachments = {
	barrel = {
		--[3] = {"supressor4", Vector(-1,0,0), {}},
		[1] = {"supressor6", Vector(3,0,0), {}},
		[2] = {"supressor1", Vector(0.2,0,0.3), {}},
		["mount"] = Vector(-2,0.45,0),
	},
		sight = {
		["mountType"] = {"picatinny"},
		["mount"] = {["picatinny"] = Vector(-17, 0, 2.3)},
		["mountAngle"] = {["picatinny"] = Angle(0, 0, -270)},
	}
}

SWEP.attPos = Vector(1,0,0)
SWEP.attAng = Angle(-0.02,0,0)

SWEP.Spray = {}
for i = 1, 64 do
	SWEP.Spray[i] = Angle(-0.0, 0, 0) * 1
end

SWEP.Ergonomics = 1
SWEP.Penetration = 7
SWEP.WorldPos = Vector(5, -1, -1)
SWEP.WorldAng = Angle(0, 0, 0)
SWEP.UseCustomWorldModel = true
SWEP.lengthSub = 30
SWEP.handsAng = Angle(7, 2, 0)
SWEP.DistSound = "bizon/fire/fire.wav"

--local to head
SWEP.RHPos = Vector(3,-7,3.5)
SWEP.RHAng = Angle(0,-8,90)
--local to rh
SWEP.LHPos = Vector(11,1.6,-3)
SWEP.LHAng = Angle(-110,-180,5)

local finger1 = Angle(-15,-22, 20)
local finger2 = Angle(0, 10, 0)
local finger3 = Angle(0, -5, -15)
local finger4 = Angle(-10, -35, 0)
local finger5 = Angle(0, 40, 0)

SWEP.ShootAnimMul = 2

function SWEP:AnimHoldPost(model)
	if CLIENT and IsValid(model) then
		self.shooanim = LerpFT(0.4,self.shooanim or 0,self:Clip1() > 0 and 0 or 0)
		model:ManipulateBonePosition(110,Vector(3 *self.shooanim,0 ,0),false)
		--PrintTable(model:GetChildBones())
	end
end


-- RELOAD ANIM AKM
SWEP.ReloadAnimLH = {
	Vector(0,0,0),
	Vector(1,-5,0),
	Vector(1,-5,-5),
	Vector(1,-5,0),
	Vector(-5,2,0),
	Vector(-1,2,-6),
	Vector(-1,2,-6),
	Vector(-1,10,-6),
	Vector(-1,12,-15),
	Vector(-1,5,-6),
	Vector(-1,2,-6),
	Vector(-1,2,-6),
	Vector(-1,2,-6),
	Vector(-1,2,-6),
	Vector(1,-5,-5),
	Vector(1,-5,-3),
	Vector(1,-8,-5),
	Vector(1,-2,-5),
	Vector(0,0,-2),
	"reloadend",
	Vector(0,0,0)
}


SWEP.ReloadSlideAnim = {
	0,
	0,
	4,
	4,
	4,
	4,
	4,
	4,
	4,
	4,
	4,
	4,
	4,
	0,
	0,
	0
}

SWEP.ReloadAnimRH = {
	Vector(0,0,0)
}

SWEP.ReloadAnimLHAng = {
	Angle(0,0,0),
	Angle(-80,0,110),
	Angle(-80,0,110),
	Angle(-80,0,110),
	Angle(-80,0,110),
	Angle(-80,0,110),
	Angle(-80,0,110),
	Angle(-80,0,120),
	Angle(-80,0,120),
	Angle(-80,0,120),
	Angle(-80,0,120),	
	Angle(0,0,0),
	Angle(0,0,0)
}

SWEP.ReloadAnimRHAng = {
	Angle(0,0,0),
}

SWEP.ReloadAnimWepAng = {
	Angle(0,0,0),
	Angle(-5,0,25),
	Angle(-8,0,20),
	Angle(-5,0,0),
	Angle(5,5,25),
	Angle(-2,5,25),
	Angle(0,5,15),
	Angle(-5,5,5),
	Angle(5,-5,-2),
	Angle(0,0,0),
}

-- Inspect Assault

SWEP.InspectAnimWepAng = {
	Angle(0,0,0),
	Angle(4,4,15),
	Angle(10,15,25),
	Angle(10,15,25),
	Angle(10,15,25),
	Angle(-6,-15,-15),
	Angle(1,15,-45),
	Angle(15,25,-55),
	Angle(15,25,-55),
	Angle(15,25,-55),
	Angle(0,0,0),
	Angle(0,0,0)
}