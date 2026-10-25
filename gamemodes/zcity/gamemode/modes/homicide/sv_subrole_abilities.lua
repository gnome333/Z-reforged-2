local MODE = MODE

util.AddNetworkString("HMCD_BeingVictimOfNeckBreak")	--; А тут я значит рещил без скобок да крутой кодинг стиль вопросы?
util.AddNetworkString("HMCD_BreakingOtherNeck")
util.AddNetworkString("HMCD_BeingVictimOfDisarmament")
util.AddNetworkString("HMCD_DisarmingOther")
util.AddNetworkString("HMCD_UpdateChemicalResistance")

--\\Chemical resistance
	function MODE.NetworkChemicalResistanceOfPlayer(ply)
		ply.PassiveAbility_ChemicalAccumulation = ply.PassiveAbility_ChemicalAccumulation or {}
		
		net.Start("HMCD_UpdateChemicalResistance")
		
		for chemical_name, amt in pairs(ply.PassiveAbility_ChemicalAccumulation) do
			net.WriteString(chemical_name)
			net.WriteUInt(math.Round(amt), MODE.NetSize_ChemicalResistanceBits)
		end
		
		net.WriteString("")
		net.Send(ply)
	end
--//

hook.Add("PlayerPostThink", "HMCD_SubRoles_Abilities", function(ply)
	if(MODE.RoleChooseRoundTypes[MODE.Type])then
		if ply.GrabbedBy then
			local char = hg.GetCurrentCharacter(ply)
			local distEnt = IsValid(char) and char or ply

			if not IsValid(ply.GrabbedBy) or not ply.GrabbedBy:Alive() or not ply:Alive() or distEnt:GetPos():DistToSqr(ply.GrabbedBy:GetPos()) > 22500 then
				hg.ReleaseGrab(ply)
			end
		end

		if(ply:Alive() and ply.organism and not ply.organism.otrub)then
			if(ply.SubRole == "traitor_infiltrator" or ply.SubRole == "traitor_infiltrator_soe")then
				if(ply:KeyDown(IN_WALK))then
					if(ply:KeyPressed(IN_RELOAD))then
						local aim_ent, other_ply = hg.eyeTrace(ply,85).Entity
						other_ply = hg.RagdollOwner(aim_ent) or aim_ent
						
						if(IsValid(aim_ent) and aim_ent:IsRagdoll())then	--; REDO
							local other_appearance = aim_ent.CurAppearance
							local your_appearance = ply.CurAppearance

							local aMdl1,aMdl2 = your_appearance.AModel,other_appearance.AModel
							
							other_appearance.AModel = aMdl1
							your_appearance.AModel = aMdl2

							local aFace1,aFace2 = your_appearance.AFacemaps,other_appearance.AFacemaps

							other_appearance.AFacemaps = aFace1
							your_appearance.AFacemaps = aFace2

							hg.Appearance.ForceApplyAppearance(ply, other_appearance, true)
							local char = hg.GetCurrentCharacter(ply)
							if char:IsRagdoll() then
								hg.Appearance.ForceApplyAppearance(char, other_appearance, true)
							end
							ply:EmitSound("snd_jack_hmcd_disguise.wav",35,math.random(90,110),0.5)

							--local duplicator_data = duplicator.CopyEntTable(ply)
							--duplicator.DoGeneric(aim_ent, duplicator_data)
							aim_ent.CurAppearance = your_appearance

							hg.Appearance.ForceApplyAppearance(aim_ent, your_appearance, true)
							
							if other_ply:IsPlayer() and other_ply:Alive() then
								hg.Appearance.ForceApplyAppearance(other_ply, your_appearance, true)
							end
						end
					end
					
				end
				
				if(ply.NeckBreakBind and ply.Ability_NeckBreak)then
					MODE.ContinueBreakingOtherNeck(ply)
				elseif(not ply.NeckBreakBind)then
					MODE.StopBreakingOtherNeck(ply)
				end
			end
			
			if(ply.SubRole == "traitor_assasin" or ply.SubRole == "traitor_assasin_soe")then
				if(ply.DisarmBind)then
					if(ply.Ability_Disarm)then
						MODE.ContinueDisarmingOther(ply)
					end
				else
					MODE.StopDisarmingOther(ply)
				end
			end
			
			if(ply.SubRole == "traitor_zombie")then
				if(ply:KeyDown(IN_WALK))then
					
				end
			end

			if(ply.SubRole == "traitor_chemist")then
				DegradeChemicalsOfPlayer(ply)
				
				if(!ply.PassiveAbility_ChemicalAccumulation_NextNetworkTime or ply.PassiveAbility_ChemicalAccumulation_NextNetworkTime <= CurTime())then
					MODE.NetworkChemicalResistanceOfPlayer(ply)

					ply.PassiveAbility_ChemicalAccumulation_NextNetworkTime = CurTime() + 1
				end
			end
		end
	end
end)

function hg.ReleaseGrab(victim)
	if not IsValid(victim) then return end

	local attacker = victim.GrabbedBy
	victim.GrabbedBy = nil
	victim.GrabEscapeTime = nil

	if IsValid(attacker) then
		local carry = attacker:GetNetVar("carryent2")

		if IsValid(carry) and (carry == victim or carry == victim.FakeRagdoll) then
			hg.SetCarryEnt2(attacker)
		end
	end
end

hook.Add("CanControlFake", "HMCD_GrabbedVictim", function(ply)
	if IsValid(ply.GrabbedBy) then return false end
end)

hook.Add("HomigradDamage", "HMCD_GrabStab", function(ent, dmgInfo, hitgroup, killer)
	if not IsValid(ent) then return end

	local victim = ent:IsPlayer() and ent or hg.RagdollOwner(ent)

	if not IsValid(victim) or not IsValid(victim.GrabbedBy) then return end
	if dmgInfo:GetAttacker() != victim.GrabbedBy then return end
	if not dmgInfo:IsDamageType(DMG_SLASH + DMG_CLUB) then return end

	victim.GrabEscapeTime = (victim.GrabEscapeTime or CurTime()) + 5
end)

hook.Add("PlayerSpawn", "HMCD_GrabCleanup", function(ply)
	ply.GrabbedBy = nil
	ply.GrabEscapeTime = nil
	ply.NeckBreakBind = nil
	ply.DisarmBind = nil
end)

concommand.Add("+neckbreak", function(ply)
	if not MODE.RoleChooseRoundTypes[MODE.Type] then return end
	if not ply:Alive() or not ply.organism or ply.organism.otrub then return end
	if ply.SubRole != "traitor_infiltrator" and ply.SubRole != "traitor_infiltrator_soe" then return end

	ply.NeckBreakBind = true

	if ply.Ability_NeckBreak then return end

	local aim_ent, other_ply = MODE.GetPlayerTraceToOther(ply)
	if IsValid(aim_ent) and other_ply and MODE.CanPlayerBreakOtherNeck(ply, aim_ent) then
		MODE.StartBreakingOtherNeck(ply, other_ply)
	end
end)

concommand.Add("-neckbreak", function(ply)
	ply.NeckBreakBind = false
	MODE.StopBreakingOtherNeck(ply)
end)

concommand.Add("+hg_disarm", function(ply)
	if not IsValid(ply) then return end
	if not MODE.RoleChooseRoundTypes[MODE.Type] then return end
	if not ply:Alive() or not ply.organism or ply.organism.otrub then return end
	if ply.SubRole != "traitor_assasin" and ply.SubRole != "traitor_assasin_soe" then return end

	ply.DisarmBind = true

	if ply.Ability_Disarm then return end

	local aim_ent, other_ply = MODE.GetPlayerTraceToOther(ply, nil, MODE.DisarmReach)
	if IsValid(aim_ent) and other_ply and MODE.CanPlayerDisarmOther(ply, aim_ent, MODE.DisarmReach) and MODE.CanPlayerDisarmOtherPly(ply, other_ply, MODE.DisarmReach) then
		MODE.StartDisarmingOther(ply, other_ply)
	end
end)

concommand.Add("-hg_disarm", function(ply)
	if not IsValid(ply) then return end

	ply.DisarmBind = false
	MODE.StopDisarmingOther(ply)
end)