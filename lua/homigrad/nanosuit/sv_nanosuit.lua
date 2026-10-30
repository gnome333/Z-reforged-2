util.AddNetworkString("NanoSuit_SetMode")
util.AddNetworkString("NanoSuit_ModeSnd")
util.AddNetworkString("NanoSuit_WakeSnd")

resource.AddWorkshop(hg.NanoSuit.WorkshopID)

local NS = hg.NanoSuit

local function syncEnergy(ply, suit, force)
	local val = math.Clamp(math.floor(suit.Energy + 0.5), 0, NS.MaxEnergy)
	if force or suit.SyncedEnergy != val then
		suit.SyncedEnergy = val
		ply:SetLocalVar("NS_Energy", val)
	end
end

local function setArmorHitbox(ply, on)
	if not IsValid(ply) then return end
	local t = ply:GetNetVar("zc_equipment_by_hitbox", {})
	if on then
		if t[NS.ArmorHitboxSet] == ply:EntIndex() then return end
		t[NS.ArmorHitboxSet] = ply:EntIndex()
	else
		if t[NS.ArmorHitboxSet] == nil then return end
		t[NS.ArmorHitboxSet] = nil
	end
	ply:SetNetVar("zc_equipment_by_hitbox", t)
end

local function setNetState(ply)
	local suit = ply.ns_suit
	ply:SetNetVar("NS_Has", suit != nil)
	ply:SetNetVar("NS_Mode", suit and suit.Mode or 0)
	ply:SetNetVar("NS_Stealth", suit != nil and suit.Mode == 2 and suit.Energy > 0)
	setArmorHitbox(ply, suit != nil and suit.Mode == 1)
end

local function collectEnts(ply)
	local t = {ply}
	local char = hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply)
	if IsValid(char) and char != ply then t[#t + 1] = char end
	if IsValid(ply.FakeRagdoll) and ply.FakeRagdoll != ply then t[#t + 1] = ply.FakeRagdoll end
	return t
end

local function isNanoName(s)
	return string.find(string.lower(s or ""), "_nano", 1, true) != nil
end

function NS.ResetBodygroups(ent)
	if not IsValid(ent) then return end
	for _, g in ipairs(ent:GetBodyGroups()) do
		ent:SetBodygroup(g.id, 0)
	end
end

function NS.ApplyGlow(ply, glow)
	for _, ent in ipairs(collectEnts(ply)) do
		if not NS.IsSuitModel(ent:GetModel()) then continue end
		for _, g in ipairs(ent:GetBodyGroups()) do
			local opts = g.options
			if not opts or #opts == 0 then continue end
			if isNanoName(g.name) then
				local nanoId, plainId
				for _, o in ipairs(opts) do
					if isNanoName(o.name) then
						nanoId = o.id
					elseif (o.name or "") == g.name then
						plainId = o.id
					end
				end
				ent:SetBodygroup(g.id, glow and (nanoId or opts[1].id) or (plainId or opts[1].id))
			elseif glow then
				local nanoId
				for _, o in ipairs(opts) do
					if isNanoName(o.name) then nanoId = o.id break end
				end
				if nanoId != nil then ent:SetBodygroup(g.id, nanoId) end
			else
				ent:SetBodygroup(g.id, 0)
			end
		end
	end
end

function NS.SetMode(ply, mode)
	local suit = ply.ns_suit
	if not suit then return end
	mode = math.Clamp(tonumber(mode) or 0, 0, 3)
	local old = suit.Mode
	if old == mode then return end
	if mode == 2 then
		if suit.Energy < NS.StealthMinEnergy then return end
		if suit.CloakGlitchUntil and CurTime() < suit.CloakGlitchUntil then return end
	end
	if mode == 3 and suit.Energy < NS.SpeedMinEnergy then
		return
	end
	suit.Mode = mode
	if mode == 1 then
		ply:EmitSound("sounds/suit_armor_108.mp3")
		net.Start("NanoSuit_ModeSnd")
		net.WriteUInt(mode, 3)
		net.Send(ply)
	elseif mode == 2 then
		ply:EmitSound("sounds/suit_cloak_chameleon_101_r.mp3")
		net.Start("NanoSuit_ModeSnd")
		net.WriteUInt(mode, 3)
		net.Send(ply)
	end
	NS.ApplyGlow(ply, mode != 0)
	setNetState(ply)
	ply:SetLocalVar("NS_Mode", mode)
	syncEnergy(ply, suit, true)
end

function NS.Give(ply)
	if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
	if ply.ns_suit then return false end
	ply.ns_suit = {Mode = 0, Energy = NS.MaxEnergy, LastDrain = -100, SyncedEnergy = -1, ModeCD = 0}
	ply.ns_basejump = ply:GetJumpPower()
	ply:SetModel(NS.GetModel(ply))
	ply:SetSubMaterial()
	ply:SetMaterial("")
	ply:SetColor(Color(255, 255, 255, 255))
	ply:SetRenderMode(RENDERMODE_NORMAL)
	NS.ResetBodygroups(ply)
	NS.ApplyGlow(ply, false)
	setNetState(ply)
	ply:SetLocalVar("NS_Mode", 0)
	syncEnergy(ply, ply.ns_suit, true)
	return true
end

function NS.Take(ply, keepAppearance)
	local suit = ply.ns_suit
	if not suit then return false end
	if IsValid(ply) then
		ply:SetJumpPower(ply.ns_basejump or DEFAULT_JUMP_POWER)
	end
	ply.ns_suit = nil
	if IsValid(ply) then
		ply:SetNetVar("NS_Has", false)
		ply:SetNetVar("NS_Mode", 0)
		ply:SetNetVar("NS_Stealth", false)
		setArmorHitbox(ply, false)
		ply:SetLocalVar("NS_Mode", 0)
		ply:SetLocalVar("NS_Energy", 0)
		if ply:Alive() and not keepAppearance and ApplyAppearance then
			ApplyAppearance(ply, nil, nil, nil, true)
		end
	end
	return true
end

hook.Add("Think", "NanoSuit", function()
	local ct = CurTime()
	local dt = FrameTime()
	for _, ply in ipairs(player.GetAll()) do
		local suit = ply.ns_suit
		if not suit then continue end
		if not ply:Alive() then
			if suit.Mode != 0 then
				suit.Mode = 0
				setNetState(ply)
				ply:SetLocalVar("NS_Mode", 0)
			end
			continue
		end
		local drained = false
		local mode = suit.Mode
		local org = ply.organism
		if org and org.stamina then
			org.stamina.subadd = 0
			org.stamina.sub = 0
			org.stamina[1] = org.stamina.max
		end
		if mode == 2 then
			local drain = NS.StealthDrain * dt
			local spd = ply:GetVelocity():Length2D()
			if ply:KeyDown(IN_SPEED) and spd > 100 then
				drain = drain * NS.StealthSprintMul
			elseif spd > 10 then
				drain = drain * NS.StealthWalkMul
			end
			suit.Energy = suit.Energy - drain
			drained = true
		end
		if mode == 3 then
			if ply:KeyDown(IN_SPEED) and not ply:Crouching() and ply:KeyDown(IN_FORWARD) then
				suit.Energy = suit.Energy - NS.SpeedDrain * dt
				drained = true
			end
		end
		if ply:GetNWBool("NVG_Enabled", false) then
			if suit.Energy > NS.NVGMinEnergy then
				suit.Energy = suit.Energy - NS.NVGEnergyDrain * dt
				drained = true
			else
				ply:SetNWBool("NVG_Enabled", false)
			end
		end
		if drained then suit.LastDrain = ct end
		if ct - suit.LastDrain >= NS.RegenDelay and suit.Energy < NS.MaxEnergy then
			suit.Energy = math.min(NS.MaxEnergy, suit.Energy + NS.RegenRate * dt)
		end
		if suit.Energy <= 0 then
			suit.Energy = 0
			if ply:GetNWBool("NVG_Enabled", false) then
				ply:SetNWBool("NVG_Enabled", false)
			end
			if mode != 0 and mode != 3 then
				NS.SetMode(ply, 0)
			end
		end
		syncEnergy(ply, suit)
		if ct > (suit.NextAssert or 0) then
			suit.NextAssert = ct + 0.5
			if ply:GetModel() != NS.GetModel(ply) then
				ply:SetModel(NS.GetModel(ply))
				ply:SetSubMaterial()
				NS.ResetBodygroups(ply)
				NS.ApplyGlow(ply, mode != 0)
			end
		end
	end
end)

hook.Add("PreHomigradDamage", "NanoSuit", function(target, dmgInfo, hitgroup, ent, harm)
	local suitOwner = target
	if IsValid(suitOwner) and not suitOwner:IsPlayer() then
		if hg.RagdollOwner then
			local resolved = hg.RagdollOwner(suitOwner)
			if IsValid(resolved) and resolved:IsPlayer() then suitOwner = resolved end
		end
		if not (IsValid(suitOwner) and suitOwner:IsPlayer()) and istable(suitOwner.organism) and IsValid(suitOwner.organism.owner) and suitOwner.organism.owner:IsPlayer() then
			suitOwner = suitOwner.organism.owner
		end
	end
	if IsValid(suitOwner) and suitOwner:IsPlayer() and suitOwner.ns_suit then
		local dtype = dmgInfo:GetDamageType()
		if bit.band(dtype, DMG_POISON + DMG_NERVEGAS + 131072 + DMG_ACID) != 0 then
			dmgInfo:SetDamage(0)
			dmgInfo:SetDamageType(0)
			return
		end
	end

	local attacker = dmgInfo:GetAttacker()
	if IsValid(attacker) and attacker != target and attacker.ns_suit then
		local dtype = dmgInfo:GetDamageType()
		if bit.band(dtype, DMG_SLASH + DMG_CLUB) != 0 then
			dmgInfo:ScaleDamage(NS.MeleeDamageMul)
		end
	end
	local owner = target
	if not owner.ns_suit and IsValid(target) and not target:IsPlayer() and hg.RagdollOwner then
		owner = hg.RagdollOwner(target)
	end
	if IsValid(owner) and owner.ns_suit then
		local suit = owner.ns_suit
		if suit.Mode == 1 and suit.Energy > 0 then
			local dmg = dmgInfo:GetDamage()
			local mul, maxCost = NS.ArmorEnergyMul, NS.ArmorMaxHitCost
			if dmgInfo:IsDamageType(DMG_FALL) then
				mul, maxCost = NS.ArmorFallEnergyMul, NS.ArmorFallMaxHitCost
			end
			local cost = math.min(dmg * mul, maxCost, suit.Energy)
			dmgInfo:ScaleDamage(1 - math.Clamp(NS.ArmorAbsorb, 0, 1))
			if dmgInfo:GetDamage() <= 0 then
				dmgInfo:SetDamageType(0)
			end
			suit.Energy = suit.Energy - cost
			suit.LastDrain = CurTime()
			syncEnergy(owner, suit)
			if dmg > 0 then
				local pos = dmgInfo:GetDamagePosition()
				if not pos or pos == vector_origin then
					pos = owner:GetPos() + owner:OBBCenter()
				end
				sound.Play("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav", pos)
			end
		end
	end
end)

local function cloakRagdoll(ragdoll)
	if not IsValid(ragdoll) then return end
	ragdoll:SetRenderMode(RENDERMODE_TRANSALPHA)
	ragdoll:SetColor(Color(255, 255, 255, NS.CloakAlpha))
end

hook.Add("Ragdoll_Create", "NanoSuitCloakRagdoll", function(ply, ragdoll)
	if not IsValid(ply) or not ply.ns_suit then return end
	if ply.ns_suit.Mode != 2 or ply.ns_suit.Energy <= 0 then return end
	cloakRagdoll(ragdoll)
	timer.Simple(0, function()
		if IsValid(ragdoll) then cloakRagdoll(ragdoll) end
	end)
end)

local regenFields = {
	"lleg", "rleg", "rarm", "larm", "chest", "pelvis",
	"spine1", "spine2", "spine3", "skull",
	"liver", "intestines", "heart", "stomach", "brain"
}

hook.Add("Org Think", "NanoSuitRegen", function(owner, org, timeValue)
	if not IsValid(owner) then return end
	local ply = owner
	if not ply:IsPlayer() then
		if not hg.RagdollOwner then return end
		local resolved = hg.RagdollOwner(owner)
		if not IsValid(resolved) or not resolved:IsPlayer() then return end
		ply = resolved
	end
	if not ply:Alive() then return end
	local suit = ply.ns_suit
	if not suit then return end
	if org then
		org.poison3 = nil
		org.poison3notificate = nil
		org.poison4 = nil
		org.poison4notificate = nil
		org.Poison_KCN = nil
		org.CO = 0
		org.COregen = 0
		org.COConcentration = 0
		org.is_sprayed_at = nil
		ply.PassiveAbility_ChemicalAccumulation = nil
	end
	if org and org.o2 and org.o2.range and IsValid(org.owner) and org.owner:WaterLevel() >= 3 then
		org.o2[1] = org.o2.range
		org.CO = 0
	end
	if suit.Energy <= 0 then return end
	if not org then return end

	local pain = math.max(org.pain or 0, org.painadd or 0, org.avgpain or 0)
	if pain > NS.AnesthThreshold then
		local ct = CurTime()
		if ct >= (suit.NextAnesth or 0) then
			suit.NextAnesth = ct + NS.AnesthInterval
			suit.Energy = math.max(0, suit.Energy - NS.AnesthCost)
			suit.LastDrain = CurTime()
			org.analgesia = math.max(org.analgesia or 0, NS.AnesthLevel)
			org.painkiller = math.max(org.painkiller or 0, 1)
		end
		org.pain = math.Approach(org.pain or 0, 0, timeValue * NS.AnesthPainRate)
		org.painadd = math.Approach(org.painadd or 0, 0, timeValue * NS.AnesthPainRate)
		org.avgpain = math.Approach(org.avgpain or 0, 0, timeValue * NS.AnesthPainRate)
	end

	local ct = CurTime()

	if org.heartstop == true and ct >= (suit.NextDefib or 0) then
		suit.NextDefib = ct + NS.DefibInterval
		suit.Energy = math.max(0, suit.Energy - NS.DefibCost)
		suit.LastDrain = ct
		org.adrenaline = math.max(org.adrenaline or 0, NS.DefibAdrenaline)
		org.painadd = (org.painadd or 0) + NS.DefibPain
		if (org.blood or 0) > 600 and (org.heart or 0) < 0.9 then
			org.heartstop = false
			org.pulse = math.max(org.pulse or 0, 45)
			org.heartbeat = math.max(org.heartbeat or 0, 60)
			org.heartstoptime = nil
			if IsValid(owner) then
				owner:EmitSound("ambient/energy/zap1.wav", 75, 90)
			end
		end
		org.heart = math.min((org.heart or 0) + NS.DefibHeartDmg, 1)
	end

	local blood = org.blood or 5000
	local prevBlood = suit.PrevBlood
	suit.PrevBlood = blood
	local bigHit = prevBlood != nil and (prevBlood - blood) >= NS.StimDamageDrop
	if bigHit and ct >= (suit.NextStim or 0) then
		suit.NextStim = ct + NS.StimInterval
		suit.Energy = math.max(0, suit.Energy - NS.StimCost)
		suit.LastDrain = ct
		org.adrenaline = math.max(org.adrenaline or 0, NS.StimAdrenaline)
		org.internalBleedHeal = (org.internalBleedHeal or 0) + NS.StimCoag
		org.painadd = math.max((org.painadd or 0) - NS.StimPain, 0)
	end

	local o2 = org.o2
	if o2 and o2.range and isnumber(o2[1]) then
		local lungsDamaged = (org.lungsL and org.lungsL[1] or 0) + (org.lungsR and org.lungsR[1] or 0)
		local lungsFail = lungsDamaged > 0.5 or (org.pneumothorax or 0) > 0.1
		local heartFail = (org.heart or 0) > 0.5 or org.heartstop == true
		if lungsFail or heartFail or o2[1] < NS.MetabMinO2 then
			local target = o2.range * NS.MetabO2Cap
			if o2[1] < target then
				o2[1] = math.min(target, o2[1] + NS.MetabO2Rate * timeValue)
				suit.Energy = math.max(0, suit.Energy - NS.MetabCost * timeValue)
				suit.LastDrain = ct
			end
			if isnumber(org.satiety) and org.satiety < NS.MetabNutrientCap then
				org.satiety = math.min(org.satiety + NS.MetabNutrientRate * timeValue, NS.MetabNutrientCap)
			end
			if isnumber(org.brain) and org.brain > 0 then
				org.brain = math.max(org.brain - timeValue * 0.005, 0)
			end
		end
	end

	local closeRate = timeValue * NS.RegenWoundRate

	if org.wounds then
		for _, wound in pairs(org.wounds) do
			if istable(wound) and isnumber(wound[1]) then
				wound[1] = math.max(wound[1] - closeRate, 0)
			end
		end
	end

	if org.arterialwounds then
		for _, wound in pairs(org.arterialwounds) do
			if istable(wound) and isnumber(wound[1]) then
				wound[1] = math.max(wound[1] - closeRate, 0)
			end
		end
	end

	if isnumber(org.internalBleed) then
		org.internalBleed = math.max(org.internalBleed - closeRate, 0)
	end

	local regen = timeValue * NS.RegenOrganRate

	for _, key in ipairs(regenFields) do
		if isnumber(org[key]) then
			org[key] = math.max(org[key] - regen, 0)
		end
	end

	if istable(org.lungsL) then
		if isnumber(org.lungsL[1]) then org.lungsL[1] = math.max(org.lungsL[1] - regen, 0) end
		if isnumber(org.lungsL[2]) then org.lungsL[2] = math.max(org.lungsL[2] - regen, 0) end
	end
	if istable(org.lungsR) then
		if isnumber(org.lungsR[1]) then org.lungsR[1] = math.max(org.lungsR[1] - regen, 0) end
		if isnumber(org.lungsR[2]) then org.lungsR[2] = math.max(org.lungsR[2] - regen, 0) end
	end

	if isnumber(org.pneumothorax) then
		org.pneumothorax = math.max(org.pneumothorax - timeValue * NS.RegenPneumoRate, 0)
	end
	if isnumber(org.needle) then
		org.needle = math.max(org.needle - timeValue * NS.RegenPneumoRate, 0)
	end
end)

hook.Add("HG_MovementCalc_2", "NanoSuitSpeed", function(mul, ply)
	if not ply.ns_suit then return end
	mul[1] = mul[1] * NS.BaseSpeedMul
	local suit = ply.ns_suit
	if suit.Mode != 1 and suit.Mode != 3 then return end
	local runnin = ply:KeyDown(IN_SPEED) and not ply:Crouching() and ply:KeyDown(IN_FORWARD)
	if suit.Mode == 1 then
		if runnin and suit.Energy > 0 then
			mul[1] = mul[1] * NS.ArmorRunMul
		end
	elseif suit.Mode == 3 then
		if runnin then
			mul[1] = mul[1] * NS.SpeedRunMul
			ply.SpeedGainMul = 100000
		else
			mul[1] = mul[1] * NS.SpeedWalkMul
		end
	end
end)

local cloakExemptWeapons = {
	["weapon_hg_bow"] = true,
	["weapon_hg_crossbow"] = true,
}

local function cloakShotDrain(wep)
	if not IsValid(wep) then return end
	if wep:IsPlayer() or wep:IsNPC() then return end
	local ply = wep.GetOwner and wep:GetOwner()
	if not IsValid(ply) or not ply:IsPlayer() or not ply.ns_suit or ply.ns_suit.Mode != 2 then return end
	if cloakExemptWeapons[wep:GetClass()] then return end
	local suit = ply.ns_suit
	suit.Energy = math.max(0, suit.Energy - NS.CloakShotCost)
	suit.LastDrain = CurTime()
	suit.CloakGlitchUntil = CurTime() + NS.CloakGlitchTime
	ply:EmitSound("buttons/button19.wav", 75, 90, 1)
	NS.SetMode(ply, 0)
end

local function cloakShotDrainBullet(bullet)
	if not istable(bullet) then return end
	local wep = bullet.Inflictor
	if IsValid(wep) and not wep:IsPlayer() and not wep:IsNPC() then
		cloakShotDrain(wep)
		return
	end
	local ply = bullet.Attacker
	if not IsValid(ply) or not ply:IsPlayer() then return end
	cloakShotDrain(ply:GetActiveWeapon())
end

hook.Add("EntityFireBullets", "NanoSuitStealth", function(ent)
	local wep = ent
	if IsValid(wep) and wep:IsPlayer() then wep = wep:GetActiveWeapon() end
	cloakShotDrain(wep)
end)

timer.Simple(0, function()
	if ENTITY and ENTITY.FireLuaBullets and not ENTITY.FireLuaBulletsNSWrap then
		local oldFireLuaBullets = ENTITY.FireLuaBullets
		ENTITY.FireLuaBulletsNSWrap = true
		ENTITY.FireLuaBullets = function(self, tInfo)
			cloakShotDrain(self)
			return oldFireLuaBullets(self, tInfo)
		end
	end
	local pb = hg.PhysBullet
	if pb and pb.CreateBullet and not pb.CreateBulletNSWrap then
		local oldCreateBullet = pb.CreateBullet
		pb.CreateBulletNSWrap = true
		pb.CreateBullet = function(bullet)
			cloakShotDrainBullet(bullet)
			return oldCreateBullet(bullet)
		end
	end
end)

hook.Add("PlayerFootstep", "NanoSuitStealth", function(ply)
	if IsValid(ply) and ply.ns_suit and ply.ns_suit.Mode == 2 then return true end
end)

hook.Add("HG_PlayerFootstep", "NanoSuitStealth", function(ply)
	if IsValid(ply) and ply.ns_suit and ply.ns_suit.Mode == 2 then return true end
end)

hook.Add("HG_PlayerFootstep", "NanoSuitArmorFootstep", function(ply)
	if not IsValid(ply) or not ply.ns_suit or ply.ns_suit.Mode != 1 then return end
	if ply.ns_suit.Energy <= 0 then return end
	if IsValid(ply.FakeRagdoll) and ply:GetNetVar("lastFake") == 0 then return end
	local chr = hg.GetCurrentCharacter(ply)
	if not IsValid(chr) then return end
	ply.NSLerpedStep = LerpFT(0.5, ply.NSLerpedStep or 60, (not ply:IsSprinting() and (ply:KeyDown(IN_DUCK) or ply:KeyDown(IN_WALK))) and 20 or 60)
	chr:EmitSound("npc/combine_soldier/gear" .. math.random(1, 6) .. ".wav", ply.NSLerpedStep, math.random(92, 108), 0.7)
end)

local function classWantsSuit(ply)
	local class = ply.PlayerClassName and player.classList and player.classList[ply.PlayerClassName]
	return class != nil and class.NanoSuit == true
end

hook.Add("PlayerSpawn", "NanoSuit", function(ply)
	if not ply.ns_suit and classWantsSuit(ply) then
		NS.Give(ply)
		ply:EmitSound("sounds/reloadsuit.wav")
	end
	local suit = ply.ns_suit
	if not suit then
		if IsValid(ply) and NS.IsSuitModel(ply:GetModel()) and ApplyAppearance then
			timer.Simple(0.2, function()
				if IsValid(ply) and ply:Alive() and not ply.ns_suit and NS.IsSuitModel(ply:GetModel()) and ApplyAppearance then
					ApplyAppearance(ply, nil, nil, nil, true)
				end
			end)
		end
		return
	end
	if OverrideSpawn then return end
	suit.Mode = 0
	suit.Energy = NS.MaxEnergy
	timer.Simple(0.1, function()
		if not IsValid(ply) or not ply:Alive() or not ply.ns_suit then return end
		ply:SetModel(NS.GetModel(ply))
		ply:SetSubMaterial()
		NS.ResetBodygroups(ply)
		ply:SetJumpPower(ply.ns_basejump or DEFAULT_JUMP_POWER)
		NS.ApplyGlow(ply, false)
		setNetState(ply)
		ply:SetLocalVar("NS_Mode", 0)
		syncEnergy(ply, ply.ns_suit, true)
	end)
end)

hook.Add("PlayerDeath", "NanoSuit", function(ply)
	local suit = ply.ns_suit
	if not suit then return end
	ply:SetJumpPower(ply.ns_basejump or DEFAULT_JUMP_POWER)
	ply.ns_suit = nil
	ply:SetNetVar("NS_Has", false)
	ply:SetNetVar("NS_Mode", 0)
	ply:SetNetVar("NS_Stealth", false)
	ply:SetLocalVar("NS_Mode", 0)
	ply:SetLocalVar("NS_Energy", 0)
	setArmorHitbox(ply, false)
end)

hook.Add("HG_OnWakeOtrub", "NanoSuitWakeSnd", function(ply)
	if not IsValid(ply) or not ply.ns_suit then return end
	timer.Simple(2, function()
		if not IsValid(ply) or not ply.ns_suit then return end
		net.Start("NanoSuit_WakeSnd")
		net.Send(ply)
	end)
end)

hook.Add("ItemsTransfered", "NanoSuitArmorHitbox", function(ply, ragdoll)
	if IsValid(ply) then setArmorHitbox(ply, false) end
	if IsValid(ragdoll) then
		local t = ragdoll:GetNetVar("zc_equipment_by_hitbox", {})
		if t[NS.ArmorHitboxSet] != nil then
			t[NS.ArmorHitboxSet] = nil
			ragdoll:SetNetVar("zc_equipment_by_hitbox", t)
		end
	end
end)

net.Receive("NanoSuit_SetMode", function(len, ply)
	if len > 32 then return end
	local suit = ply.ns_suit
	if not suit then return end
	local ct = CurTime()
	if ct < (suit.ModeCD or 0) then return end
	suit.ModeCD = ct + 0.3
	local key = net.ReadUInt(3)
	if key < 1 or key > 3 then return end
	if suit.Mode == key then
		NS.SetMode(ply, 0)
		return
	end
	NS.SetMode(ply, key)
end)

COMMANDS.nanosuit = {
	function(ply, args)
		local arg = istable(args) and args[1] or args
		local list = player.GetListByName(arg or "*")
		for _, target in ipairs(list) do
			NS.Give(target)
		end
	end,
	1,
	"!nanosuit <ник|*> — выдать нанокостюм"
}

COMMANDS.nanosuit_off = {
	function(ply, args)
		local arg = istable(args) and args[1] or args
		local list = player.GetListByName(arg or "*")
		for _, target in ipairs(list) do
			NS.Take(target)
		end
	end,
	1,
	"!nanosuit_off <ник|*> — снять нанокостюм"
}
