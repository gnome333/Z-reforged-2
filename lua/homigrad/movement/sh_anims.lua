local Angle, Vector, AngleRand, VectorRand, math, hook, util, game = Angle, Vector, AngleRand, VectorRand, math, hook, util, game
--\\ Custom running anim rate
	hook.Add("UpdateAnimation", "NormAnimki", function(ply, vel, maxSeqGroundSpeed)
	if not IsValid(ply) or not ply:Alive() or not ply:OnGround() then return end
	local ground = vel:Length2D()
	if ground < 30 or (maxSeqGroundSpeed or 0) < 1 then ply.AnimRateSmooth = nil; return end
	local target = math.Clamp(ground / maxSeqGroundSpeed, 0.7, 1.6)
	ply.AnimRateSmooth = ply.AnimRateSmooth or target
	local spd = target > ply.AnimRateSmooth and 8 or 3
	local rate = math.Approach(ply.AnimRateSmooth, target, FrameTime() * spd)
	ply.AnimRateSmooth = rate
	ply:SetPlaybackRate(rate)
	return ply, vel, maxSeqGroundSpeed
end)
--//

--\\ Custom running anim activity
	local runHoldTypes = {
		["normal"] = true,
		["slam"] = true,
		["grenade"] = true
	}

	hook.Add( "CalcMainActivity", "CrouchRunAnim", function(ply, vel)
	if (not ply:InVehicle()) and ply:IsOnGround() and ply:Crouching() and vel:Length2D() > 90 then
		local hold = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetHoldType() or "normal"
		if hold == "rpg" or hold == "shotgun" or hold == "smg" or hold == "ar2" then return ACT_HL2MP_RUN_CROUCH_AIM, -1 end
		return ACT_HL2MP_RUN_CROUCH, -1
	end
end)

hook.Add( "CalcMainActivity", "RunningAnim", function(ply, vel)
		local wep = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon()
		local isAmputated = ply:IsBerserk() and ply.organism and (ply.organism.llegamputated or ply.organism.rlegamputated)
		if (not ply:InVehicle()) and ply:IsOnGround() and vel:Length() > 250 and wep and runHoldTypes[wep:GetHoldType()] and not isAmputated then
			local anim = ACT_HL2MP_RUN_FAST
			if ply:IsOnFire() then
				anim = ACT_HL2MP_RUN_PANICKED
			end

			return anim, -1
		end

		if (not ply:InVehicle()) and ply:IsOnGround() and isAmputated then
			local anim = ACT_HL2MP_WALK_ZOMBIE_06
			if vel:Length() > 250 then
				anim = ACT_HL2MP_RUN_ZOMBIE_FAST
			end
			return anim, -1
		end
	end)
