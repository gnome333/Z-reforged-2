
local min, max, Round = math.min, math.max, math.Round
local hg_organism_stamina_sprint_mul = CreateConVar("hg_organism_stamina_sprint_mul","1",{FCVAR_ARCHIVE,FCVAR_NOTIFY,FCVAR_NEVER_AS_STRING},"Multiply stamina drain when sprinting",0,10)

--local Organism = hg.organism
hg.organism.module.stamina = {}
local module = hg.organism.module.stamina
module[1] = function(org)
	org.adrenaline = 0
	org.adrenalineAdd = 0
	org.adrenalineStorage = 5

	org.stamina = {
		range = 60 * 3,
		regen = 1,
		sub = 0,
		subadd = 0,
		weight = 0,
		max = 60 * 3,
	}

	org.energy = 0

	org.hemotransfusionshock = 0

	org.stamina[1] = org.stamina.range
	local owner = org.owner
	org.moveMaxSpeed = IsValid(owner) and owner:IsPlayer() and owner:GetMaxSpeed() or 250
end

local hg_infstamina = CreateConVar("hg_infstamina", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Toggle infinite stamina (excausts only from other organism effects, not from running/attacking)", 0, 1)
module[2] = function(owner, org, timeValue)
	local stamina = org.stamina
	
	local painfrommoving = (stamina.sub * (org.chest))//(stamina.sub * ((org.jaw == 1 and 1 or 0) + org.chest + (org.jawdislocation and 1 or 0)))
	//org.painadd = org.painadd + painfrommoving * timeValue * 5

	if painfrommoving > 0 then
		//org.owner:Notify("I should stop moving so much...", 30, "painfrommoving", 0, nil, Color(255, 0, 0))
	
		if (org.jaw == 1) or org.jawdislocation then
			//org.owner:Notify("My jaw is really hurting every move I make.", 60, "painfromjaw", 0, nil, Color(255, 210, 210))
		end

		if (org.chest > 0.25) then
			//org.owner:Notify("Breathing is painful. Something is wrong with my ribs.", 60, "painfromribs", 0, nil, Color(255, 210, 210))
		end
	end

	stamina.sub = 0
	local velLen = 0
	if owner:IsPlayer() then
		local wep = owner:GetActiveWeapon()
		local walk = owner:KeyDown(IN_FORWARD) or owner:KeyDown(IN_BACK) or owner:KeyDown(IN_MOVELEFT) or owner:KeyDown(IN_MOVERIGHT)
		velLen = max(min(owner:GetVelocity():Length(), org.moveMaxSpeed), 0) / (owner:GetRunSpeed() / hg_organism_stamina_sprint_mul:GetFloat())-- / ((IsValid(wep) and wep ~= NULL and wep:GetClass() == "weapon_hands_sh" and owner:KeyDown(IN_WALK)) and 1.3 or 0.58))
		--print(velLen)

		-- What we are standing on. Loose ground makes sprinting cost more; the same helper feeds the
		-- speed multiplier in sh_inertia.lua, and both realms trace locally so prediction matches.
		local drainMul = 1

		if hg.stamina and hg.stamina.groundSurfaceMuls then
			drainMul = hg.stamina.groundSurfaceMuls(owner)
		end
		-- The old condition also required stamina[1] > 20. Because regeneration keeps running in
		-- the same tick, dropping below 20 stopped the drain while the recovery continued, so the
		-- last 20 points were free: you could sprint on an empty bar forever. Sprinting always
		-- costs effort now; the sprint gate itself lives in the movement code.
		if (owner:OnGround() or owner:WaterLevel() >= 2) and walk and not owner:InVehicle() and owner:IsSprinting() then
			local water = owner:WaterLevel() >= 2
			-- Wading already doubles the cost, so the ground underneath is not counted a second
			-- time -- otherwise a river bed of sand would stack to nearly 3x.
			stamina.sub = (water and 2 or 1) * (velLen ^ 0.5) * (water and 1 or drainMul)
		end
	end

	if org.superfighter then
		org.stamina.subadd = org.stamina.subadd / 4
	end

	if org.chest > 0.3 then
		org.lungsL[2] = math.min(org.lungsL[2] + stamina.sub / 200 * org.chest, 1)
		org.lungsR[2] = math.min(org.lungsR[2] + stamina.sub / 200 * org.chest, 1)
	end

	stamina.sub = stamina.sub + stamina.subadd + (org.painkiller > 1.6 and (stamina[1] > 10 and 0.8 or 0) or 0) + (org.analgesia > 1.7 and (stamina[1] > 10 and 2 or 0) or 0)
	stamina.sub = stamina.sub * (owner.StaminaExhaustMul or 1)
	stamina.sub = stamina.sub / (1 + org.berserk)
	
	if org.o2[1] < 10 then
		stamina.sub = 0
	end

	stamina.subadd = 0
	stamina.weight = owner:IsPlayer() and math.Clamp((1 / hg.CalculateWeight(owner,250)) - 1,0,1) or 0
	local muffed = owner.armors and owner.armors["face"] == "mask2"
	stamina.sub = stamina.sub + stamina.sub * stamina.weight * (muffed and 2 or 1)
	org.hungry = org.hungry or 0
	-- Adrenaline used to add + org.adrenaline * 20 to the pool, i.e. up to +100 stamina on top of
	-- the base 180. That is the wrong shape for a hormone: a frightened player simply had a bigger
	-- bar, permanently, and every threshold written against the absolute value (block at > 90,
	-- sprint cut-off at 30) silently moved because the denominator had changed. Adrenaline now
	-- affects how fast the bar comes back, not how big it is.
	stamina.max = (org.superfighter and 2 or 1) * ((stamina.range * (1 - (org.pneumothorax) / 2)) * math.max(1 - org.hemotransfusionshock,0.2)) * math.max(1 - (org.hungry/100),0.65)
	local satietyMul = 1 - min(max((org.satiety or 0) / 100, 0), 1) * 0.1
	stamina[1] = max(stamina[1] - stamina.sub * timeValue * 16 * (2 - (org.o2[1] / org.o2.range)) * satietyMul, 0)
	//org.o2[1] = org.o2[1] - min(stamina.sub * timeValue, org.o2.regen * timeValue)
	
	//local old = stamina[1]
	-- stamina.max moves with pneumothorax and hunger, so the ratio has to be clamped: the recovery
	-- curve used to read an unbounded stamina/max and got faster than intended whenever the pool
	-- shrank under the current value.
	local regenRatio = math.Clamp(stamina[1] / max(stamina.max, 1), 0, 1)

	--\\ Adrenaline: recovery, not capacity
		-- Capped at 5 (the value AddNaturalAdrenaline and the injector both clamp to). The multiplier
		-- is deliberately applied to regeneration only.
		local adrenaline = math.Clamp(org.adrenaline or 0, 0, 5)
		local adrenRegenMul = 1 + adrenaline * 0.1

		local regenRate = stamina.regen * timeValue * 8 * 1.5 * math.max(regenRatio, 0.2) ^ 0.5 * (org.noradrenaline / 2 + 1) * (org.o2[1] / org.o2.range) * adrenRegenMul * (org.satiety / 2000 + 1) * ((owner:IsPlayer() and owner:Crouching() and velLen < 0.1) and 1.1 or 1) * (org.holdingbreath and 0 or 1) * (org.lungsfunction and 1 or 0)

		-- Regeneration runs every tick, including the ones spent sprinting, so a large enough bonus
		-- would simply outrun the drain and make sprinting self-sustaining -- the bar would sit still
		-- and the player could run forever. Cap it just below the cost of the effort actually being
		-- made, so adrenaline shortens recovery instead of paying for the work.
		if stamina.sub > 0.05 then
			local drainRate = stamina.sub * timeValue * 16 * (2 - (org.o2[1] / org.o2.range)) * satietyMul

			regenRate = math.min(regenRate, drainRate * 0.8)
		end
	--//

	stamina[1] = min(stamina[1] + regenRate, stamina.max)

	-- local painfrommoving = (stamina[1] < 150 and 1 or 0) * (stamina[1] - old) * (org.chest)
	-- org.painadd = org.painadd + painfrommoving * timeValue * 5

	if org.nextAdrenalineRegen and org.nextAdrenalineRegen < CurTime() then
		org.adrenalineStorage = math.Approach(org.adrenalineStorage, 5, timeValue / 60 * (org.satiety * 0.01 + 1))
	end

	-- if painfrommoving > 0 then
	-- 	if (org.chest > 0.25) then
	-- 		org.owner:Notify("Breathing is painful. Something is wrong with my ribs.", 60, "painfromribs", 0, nil, Color(255, 210, 210))
	-- 	end
	-- end

	if hg_infstamina:GetBool() then
		stamina.sub = 0
		stamina[1] = stamina.max
	end
end

function hg.organism.AddNaturalAdrenaline(org, fAmount)
	if org.adrenalineStorage == 0 then return end
	if fAmount < 0 then return end
	
	local amt = math.min(org.adrenalineStorage, fAmount)
	org.adrenaline = math.min(org.adrenaline + amt, 5)
	org.adrenalineStorage = org.adrenalineStorage - amt
	org.nextAdrenalineRegen = CurTime() + 30
end

local entMeta = FindMetaTable("Entity")

function entMeta:AddNaturalAdrenaline(fAmount)
	local org = self.organism

	if !org then return end

	hg.organism.AddNaturalAdrenaline(org, fAmount)
end

local vecZero = Vector(0, 0, 0)
hook.Add("FinishMove", "!homigrad-organism", function(ply, move)
	local vel = move:GetFinalJumpVelocity()

	if !ply.organism then return end

	if vel ~= vecZero then ply.organism.stamina[1] = max(ply.organism.stamina[1] - ply:GetJumpPower() / 10,0) end
	ply.organism.moveMaxSpeed = move:GetMaxSpeed()
end)