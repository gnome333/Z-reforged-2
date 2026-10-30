--\\
--; https://ru.wikipedia.org/wiki/%D0%A6%D0%B8%D0%B0%D0%BD%D0%B8%D0%B4_%D0%BA%D0%B0%D0%BB%D0%B8%D1%8F
--; При больших дозах или поступлении яда натощак потеря сознания и смерть пострадавшего наступает практически мгновенно 
--; (отравленные мгновенно падают замертво) или через несколько секунд после мучительного удушья, судорог, которые часто сопровождаются пронзительными 
--; криками (иногда до хрипоты) и чрезвычайно сильным расширением зрачков.
--; Нейтрализуется от глюкозы и сам по себе т.к. нестабилен
--//

if SERVER then AddCSLuaFile() end
SWEP.Base = "weapon_base"
SWEP.PrintName = "Cyanide Capsule"
SWEP.InstructionsBasic = "Potassium cyanide powder in a swallowable capsule\nLMB on nothing - swallow it yourself, LMB on food or drink - poison it\nIn the bloodstream it stops cells from using oxygen: metallic taste, gasping, convulsions, cardiac arrest\nSugary drinks taken in the first seconds will neutralize the dose in the stomach\n140mg per dose - a single capsule is already lethal"	--; TODO Mansion tea cup
SWEP.Instructions = SWEP.InstructionsBasic
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/weapons/tfa_ins2/upgrades/phy_optic_eotech.mdl"
SWEP.Model = "models/Items/Flare.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/wep_jack_hmcd_poisonpowder")
	SWEP.IconOverride = "vgui/wep_jack_hmcd_poisonpowder"
	SWEP.BounceWeaponIcon = false
end

SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Slot = 3
SWEP.SlotPos = 4
SWEP.WorkWithFake = false
SWEP.offsetVec = Vector(5, -1.5, -0.6)
SWEP.offsetAng = Angle(0, 60, 90)
SWEP.ModelScale = 0.3

if SERVER then
	function SWEP:OnRemove() end
end

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "UsesLeft")
	self:NetworkVar("Float", 0, "Swallowing")
end

function SWEP:Initialize()
	self:SetHold(self.HoldType)
	
	if(SERVER)then
		self:SetUsesLeft(5)
	end
	
	self:MarkupUpdate()
end

function SWEP:MarkupUpdate()
	if(self:GetUsesLeft() == 0)then
		self.Instructions = self.InstructionsBasic .. "\n\nIt's empty."
		self.InfoMarkup = nil
	else
		self.Instructions = self.InstructionsBasic .. "\n\n" .. self:GetUsesLeft() * 140 .. " mg left"
		self.InfoMarkup = nil
	end
end

local mat, clr = "debug/env_cubemap_model", Color(185, 180, 180)
function SWEP:DrawWorldModel()
	self.model = IsValid(self.model) and self.model or ClientsideModel(self.Model)
	local WorldModel = self.model
	local owner = self:GetOwner()
	WorldModel:SetNoDraw(true)
	WorldModel:SetModelScale(self.ModelScale or 1)
	if IsValid(owner) then
		local offsetVec = self.offsetVec
		local offsetAng = self.offsetAng
		local boneid = owner:LookupBone(((owner.organism and owner.organism.rarmamputated) or (owner.zmanipstart ~= nil and owner.zmanipseq == "interact" and not owner.organism.larmamputated)) and "ValveBiped.Bip01_L_Hand" or "ValveBiped.Bip01_R_Hand")
		if not boneid then return end
		local matrix = owner:GetBoneMatrix(boneid)
		if not matrix then return end
		local newPos, newAng = LocalToWorld(offsetVec, offsetAng, matrix:GetTranslation(), matrix:GetAngles())
		WorldModel:SetPos(newPos)
		WorldModel:SetAngles(newAng)
		WorldModel:SetupBones()
	else
		WorldModel:SetPos(self:GetPos())
		WorldModel:SetAngles(self:GetAngles())
	end
	WorldModel:SetMaterial(mat)
	WorldModel:SetColor(clr)

	WorldModel:DrawModel()
end

function SWEP:SetHold(value)
	self:SetWeaponHoldType(value)
	self:SetHoldType(value)
	self.holdtype = value
end

SWEP.SwallowTime = 3

function SWEP:Think()
	self:SetHold(self.HoldType)
	
	if(CLIENT)then
		self:MarkupUpdate()
	else
		local owner = self:GetOwner()
		
		if(self.SwallowStart)then
			if not IsValid(owner) or not owner:Alive() or not owner:KeyDown(IN_ATTACK) then
				self.SwallowStart = nil
				self:SetSwallowing(0)
			else
				local progress = CurTime() - self.SwallowStart
				
				self:SetSwallowing(math.min(progress / self.SwallowTime, 1) * 100)
				
				if(progress >= self.SwallowTime)then
					self.SwallowStart = nil
					self:SetSwallowing(0)
					
					self:Swallow()
				end
			end
		end
	end
end

function SWEP:Holster(wep)
	self.SwallowStart = nil
	self:SetSwallowing(0)
	
	return true
end

function SWEP:Swallow()
	local owner = self:GetOwner()
	
	if not IsValid(owner) or not owner:Alive() then return end
	if(self:GetUsesLeft() <= 0)then return end
	
	self:SetUsesLeft(math.max(self:GetUsesLeft() - 1, 0))
	
	owner:EmitSound("player/eat_chocolate.wav", 60, math.random(95, 105))
	owner:Notify("You bite down... a bitter, metallic burst floods your mouth.", true, "kcn", 4)
	
	local org = owner.organism
	
	if org then
		org.Poison_KCN = org.Poison_KCN or {}
		org.Poison_KCN.StartTime = org.Poison_KCN.StartTime or CurTime()
		org.Poison_KCN.Potency = (org.Poison_KCN.Potency or 0) + 1
	end
end

SWEP.traceLen = 5

function SWEP:GetEyeTrace()
	return hg.eyeTrace(self:GetOwner())
end

local poisonable_entities = {
	["weapon_bigconsumable"] = true,
	["weapon_smallconsumable"] = true,
	["weapon_bandage_sh"] = true,
	["weapon_painkillers"] = true,
	["weapon_betablock"] = true,
}

if CLIENT then
	local colred = Color(150,0,0)
	function SWEP:DrawHUD()
		if GetViewEntity() ~= LocalPlayer() then return end
		if LocalPlayer():InVehicle() then return end
		local tr = self:GetEyeTrace()
		local toScreen = tr.HitPos:ToScreen()

		if(IsValid(tr.Entity) and self:CanPoison(tr.Entity))then
			draw.SimpleText("Poison "..(tr.Entity.PrintName or "Consumable"), "HomigradFont", toScreen.x + 3, toScreen.y + 27, color_black, TEXT_ALIGN_CENTER)
			draw.SimpleText("Poison "..(tr.Entity.PrintName or "Consumable"), "HomigradFont", toScreen.x, toScreen.y + 25, colred, TEXT_ALIGN_CENTER)
			surface.SetDrawColor(195,0,0,155)
			surface.DrawRect(toScreen.x-2.5, toScreen.y-2.5, 5, 5)
		else
			surface.SetDrawColor(255,255,255,155)
			surface.DrawRect(toScreen.x-2.5, toScreen.y-2.5, 5, 5)
		end
		
		local swallow = self:GetSwallowing()
		
		if swallow > 0 then
			local w, h = 150, 8
			local x, y = ScrW() * 0.5 - w * 0.5, ScrH() * 0.5 + 70
			
			surface.SetDrawColor(0, 0, 0, 190)
			surface.DrawRect(x - 2, y - 2, w + 4, h + 4)
			
			surface.SetDrawColor(190, 160, 60, 230)
			surface.DrawRect(x, y, w * math.min(swallow / 100, 1), h)
			
			draw.SimpleText("Swallowing...", "HomigradFont", ScrW() * 0.5, y + h + 6, color_white, TEXT_ALIGN_CENTER)
		end
	end
end

function SWEP:CanPoison(ent)
	if(poisonable_entities[ent:GetClass()])then
		return true
	end
	
	return false
end

function SWEP:DoPoison(ent)
	local owner = self:GetOwner()

	ent.ConsumePoisoned_KCN = (ent.ConsumePoisoned_KCN or 0) + 1

	owner:ChatPrint((ent.PrintName or "Item").." was poisoned!")

	self.SwallowStart = nil
	self:SetSwallowing(0)

	self:SetUsesLeft(math.max(self:GetUsesLeft(0) - 1, 0))
end

--\\Chemical resistance
function DegradeChemicalsOfPlayer(ply)
	ply.PassiveAbility_ChemicalAccumulation = ply.PassiveAbility_ChemicalAccumulation or {}
	
	for chemical_name, amt in pairs(ply.PassiveAbility_ChemicalAccumulation) do
		ply.PassiveAbility_ChemicalAccumulation[chemical_name] = math.max(amt - FrameTime() * (chemical_degrade_speeds[chemical_name] or 1), 0)
	end
end

function CleanChemicalsOfPlayer(ply)
	ply.PassiveAbility_ChemicalAccumulation = {}
end

function GetChemicalOfPlayer(ply, chemical_name)
	ply.PassiveAbility_ChemicalAccumulation = ply.PassiveAbility_ChemicalAccumulation or {}
	ply.PassiveAbility_ChemicalAccumulation[chemical_name] = (ply.PassiveAbility_ChemicalAccumulation[chemical_name] or 0)
	
	return ply.PassiveAbility_ChemicalAccumulation[chemical_name]
end

function SetChemicalToPlayer(ply, chemical_name, amt)
	amt = amt or 1
	ply.PassiveAbility_ChemicalAccumulation = ply.PassiveAbility_ChemicalAccumulation or {}
	ply.PassiveAbility_ChemicalAccumulation[chemical_name] = amt
end

function AddChemicalToPlayer(ply, chemical_name, amt)
	amt = amt or 1
	ply.PassiveAbility_ChemicalAccumulation = ply.PassiveAbility_ChemicalAccumulation or {}
	ply.PassiveAbility_ChemicalAccumulation[chemical_name] = (ply.PassiveAbility_ChemicalAccumulation[chemical_name] or 0) + amt
	
	return ply.PassiveAbility_ChemicalAccumulation[chemical_name]
end
--//

if(SERVER)then
    hook.Add("Org Clear", "RemovePoison_KCN", function(org)
        org.Poison_KCN = nil
    end)

	hook.Add("Org Think", "Poison_KCN",function(owner, org, timeValue)
		if not owner:IsPlayer() or not owner:Alive() then return end
		if owner.SubRole == "traitor_chemist" then return end
		if((not org.Poison_KCN) or (not org.alive))then return end
		
		local poison = org.Poison_KCN
		local t = CurTime() - (poison.StartTime or CurTime())
		local p = math.max(poison.Potency or 1, 0.25)
		local stage = poison.Stage or 0
		
		if stage < 1 and t > 4 / p then
			poison.Stage = 1
			org.owner:Notify("A bitter, metallic taste coats your tongue... your throat begins to burn.", true, "kcn", 4)
			if not org.otrub then org.owner:EmitSound((ThatPlyIsFemale(org.owner) and "vo/npc/female01/moan0"..math.random(5)..".wav" ) or "vo/npc/male01/moan0"..math.random(5)..".wav") end
		end
		
		if stage >= 1 and (poison.NextAlmond or 0) < CurTime() then
			poison.NextAlmond = CurTime() + 15
			
			local pos = owner:GetPos()
			
			for _, ply in ipairs(player.GetAll()) do
				if ply ~= owner and ply:Alive() and ply:GetPos():DistToSqr(pos) < 220 * 220 then
					ply:Notify("You catch a whiff of bitter almonds in the air...", true, "kcnsmell", 3)
				end
			end
		end
		
		if stage < 2 and t > 12 / p then
			poison.Stage = 2
			org.owner:Notify("Your chest tightens... deep, ragged gasps tear out of you.", true, "kcn", 4)
			org.owner:EmitSound(ThatPlyIsFemale(org.owner) and "breathing/inhale/female/inhale_0"..math.random(5)..".wav" or "breathing/inhale/male/inhale_0"..math.random(4)..".wav",65)
		end
		
		if stage >= 2 then
			org.pulse = math.max(org.pulse, 140)
			org.stamina[1] = math.max(org.stamina[1] - timeValue * 6, 0)
		end
		
		if stage < 3 and t > 28 / p then
			poison.Stage = 3
			org.owner:Notify("The room spins... a wild pounding behind your temples.", true, "kcn", 4)
		end
		
		if stage >= 3 then
			poison.Dizziness = math.min((poison.Dizziness or 0) + timeValue * (stage >= 4 and 1.5 or 0.7), 10)
			org.disorientation = math.max(org.disorientation or 0, poison.Dizziness)
			org.pulse = math.max(org.pulse, 165)
		end
		
		if stage < 4 and t > 42 / p then
			poison.Stage = 4
			org.owner:Notify("Your muscles clench... violent convulsions take over.", true, "kcn", 4)
			if not org.otrub then org.owner:EmitSound((ThatPlyIsFemale(org.owner) and "vo/npc/female01/moan0"..math.random(5)..".wav" ) or "vo/npc/male01/moan0"..math.random(5)..".wav") end
		end
		
		if stage >= 4 then
			org.pulse = math.max(org.pulse, 180)
			org.painadd = org.painadd + timeValue * 5
			
			if (poison.NextSpasm or 0) < CurTime() then
				poison.NextSpasm = CurTime() + math.Rand(2.5, 4)
				
				if not org.otrub then org.owner:EmitSound((ThatPlyIsFemale(org.owner) and "vo/npc/female01/moan0"..math.random(5)..".wav" ) or "vo/npc/male01/moan0"..math.random(5)..".wav") end
			end
		end
		
		if stage < 5 and t > 65 / p then
			poison.Stage = 5
			org.owner:Notify("Everything fades... your heart hammers... then stumbles.", true, "kcn", 5)
		end
		
		if stage >= 5 then
			org.pulse = math.max(org.pulse, 190)
			org.needotrub = true
			org.heartstop = true
			org.o2.regen = 0
		end
	end)
end

function SWEP:SecondaryAttack()
end

function SWEP:PrimaryAttack()
	if self:GetNextPrimaryFire() > CurTime() then return end
	if SERVER then
		if(self:GetUsesLeft() == 0)then
			self:GetOwner():ChatPrint("The capsule is empty.")
			self:SetNextPrimaryFire(CurTime() + 0.8)

			return
		end

		local tr = self:GetEyeTrace()

		if(IsValid(tr.Entity) and self:CanPoison(tr.Entity))then
			self:DoPoison(tr.Entity)
			self:SetNextPrimaryFire(CurTime() + 0.2)
		elseif not self.SwallowStart then
			self.SwallowStart = CurTime()
			self:SetNextPrimaryFire(CurTime() + 0.5)
		end
	end
end

function SWEP:Reload()
end
