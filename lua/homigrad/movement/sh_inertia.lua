local Angle, Vector, AngleRand, VectorRand, math, hook, util, game = Angle, Vector, AngleRand, VectorRand, math, hook, util, game
--\\ Inertia & stuff
	--\\ Antibhop accelerate (not used anyway)
		--[[hook.Add("OnPlayerHitGround", "Movement", function(ply, inWater, onFloater, speed)
			local vel = ply:GetVelocity()

			if (ply.MovementInertia and vel:LengthSqr() > 10000) then
				ply.MovementInertia = ply.MovementInertia + (vel / vel:Length() * math.abs(vel[3])) * 0.75
			end
		end)]]
	--//

	--\\ Side movement calculation
		local function calc_vector2d_angle(vector)
			return math.deg(math.atan2(vector.y, vector.x))
		end

		local function calc_forward_side_moves(inertia, ply_angles)
			local ply_angle = ply_angles.y
			local inertia_angle = calc_vector2d_angle(inertia)
			local angdiff = math.AngleDifference(inertia_angle, ply_angle)

			return math.cos(math.rad(angdiff)), -math.sin(math.rad(angdiff))
		end

		local function calc_forward_side_moves_to_vector2d(fm, sm, ply_angles)
			local ply_angle = ply_angles.y
			--ply_angle = ply_angle + (CLIENT and offsetView[2] or 0)

			local vec = Vector(fm * math.cos(math.rad(ply_angle)) - sm * math.cos(math.rad(ply_angle + 90)), fm * math.sin(math.rad(ply_angle)) - sm * math.sin(math.rad(ply_angle + 90)), 0)

			return vec:GetNormalized()
		end

		local function approach_vector(vector_from, vector_to, change)
			return Vector(math.Approach(vector_from.x, vector_to.x, change), math.Approach(vector_from.y, vector_to.y, change), math.Approach(vector_from.z, vector_to.z, change))
		end

		local function approach_vector_smooth(vector_from, vector_to, lerp)
			return Vector(Lerp(lerp, vector_from.x, vector_to.x), Lerp(lerp, vector_from.y, vector_to.y), Lerp(lerp, vector_from.z, vector_to.z))
		end

		hg.approach_vector = approach_vector
	--//

	--\\ Stamina
		-- The sprint cut-off and the speed penalty both used to be built on the absolute stamina
		-- value against a hardcoded 180/120. Two consequences:
		--   * anything with stamina.max above 180 (homicide traitors run at 300) never hit the
		--     penalty at all, because the clamped expression stayed at 1;
		--   * the cut-off sat exactly on the value the regeneration pulls towards, so at the wall
		--     sprint toggled on and off about six times per second -- a stutter, not fatigue.
		-- Both are now driven by hg.stamina.ratio() (see organism/sh_stamina.lua), and the gate
		-- uses a hysteresis band instead of a single threshold.
		local hg_stamina_debuff_start = CreateConVar("hg_stamina_debuff_start", "0.75", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Stamina ratio below which movement starts to slow down", 0, 1)
		local hg_stamina_debuff_floor = CreateConVar("hg_stamina_debuff_floor", "0.6", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Lowest speed multiplier reached at zero stamina", 0.1, 1)
		local hg_stamina_sprint_block = CreateConVar("hg_stamina_sprint_block", "0.10", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Stamina ratio below which sprint is blocked", 0, 1)
		local hg_stamina_sprint_unblock = CreateConVar("hg_stamina_sprint_unblock", "0.30", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Stamina ratio above which sprint is allowed again", 0, 1)
		local hg_adrenaline_speed = CreateConVar("hg_adrenaline_speed_bonus", "0.12", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Maximum speed bonus from full adrenaline (0.12 = +12%)", 0, 1)

		-- Adrenaline is a 0..5 value (sv_pain pushes it to 4, the injector clamps it at 5). The old
		-- expression was math.min(Round(a, 1) / 24, 0.3) + 1, whose cap of 0.3 was unreachable --
		-- adrenaline would have had to reach 7.2 to hit it -- so it silently gave +21% at the top of
		-- the range. Written out plainly instead: a small, deliberate bonus, tunable in one place.
		local function adrenaline_speed_mul(org)
			local a = math.Clamp((org and org.adrenaline or 0) / 5, 0, 1)

			if a <= 0 then return 1 end

			return 1 + hg_adrenaline_speed:GetFloat() * a
		end

		-- Ground surface: loose ground costs a little top speed. The trace is cached inside
		-- hg.stamina.groundSurfaceMuls (0.2s), so running this per usercmd is cheap, and tracing
		-- locally on both sides keeps client prediction in step with the server -- a networked
		-- value would only arrive about once a second.
		local function surface_speed_mul(ply)
			if not (hg.stamina and hg.stamina.groundSurfaceMuls) then return 1 end

			local _, speed = hg.stamina.groundSurfaceMuls(ply)

			return speed or 1
		end

		-- Smooth, normalised speed penalty. 1.0 above the start ratio, easing down to the floor at
		-- zero. The old curve dropped straight to 0.3, which turned a tired player into a snail
		-- instead of a tired player.
		local function stamina_speed_mul(ratio)
			local start = hg_stamina_debuff_start:GetFloat()

			if ratio >= start then return 1 end

			local t = math.Clamp(ratio / math.max(start, 0.01), 0, 1)

			t = t * t * (3 - 2 * t)

			return Lerp(t, hg_stamina_debuff_floor:GetFloat(), 1)
		end

		-- Sprint gate with hysteresis: block below the low threshold, allow again above the high
		-- one. The state lives on the player so both realms behave the same way for the same
		-- synced stamina value.
		local function stamina_sprint_blocked(ply, org)
			local natural = hg.stamina and hg.stamina.ratio(org) or 1
			local low = hg_stamina_sprint_block:GetFloat()
			-- keep the band positive even if the two convars are set the wrong way round
			local high = math.max(hg_stamina_sprint_unblock:GetFloat(), low + 0.05)

			if ply.StaminaSprintBlocked then
				if natural >= high then
					ply.StaminaSprintBlocked = false
				end
			elseif natural <= low then
				ply.StaminaSprintBlocked = true
			end

			return ply.StaminaSprintBlocked and true or false
		end
	--//

	local hg_inertiamul = CreateConVar("hg_inertiamul", "1", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Multiply inertia for player movement", 0.01, 5)
	-- "hg_inertiaenabled" used to sit here with a default of 0 and FCVAR_ARCHIVE, but it never did
	-- anything (only the mv write at the bottom was gated by it), so every install has a stale
	-- "hg_inertiaenabled 0" sitting in config.cfg. Honouring that name would silently turn inertia
	-- off for everyone, so the working switch gets a fresh name and defaults to on, matching how the
	-- movement actually behaved before.
	local hg_inertia_enabled = ConVarExists("hg_inertia_enabled") and GetConVar("hg_inertia_enabled") or CreateConVar("hg_inertia_enabled", "1", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Enable the inertia based movement model", 0, 1)
	local hg_divejump = CreateConVar("hg_divejump", "0", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Toggle dive jumps on crouch jump", 0, 1)
	local hg_movement_speed_gain_mul = CreateConVar("hg_movement_speed_gain_mul", "1", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Multiply speed gain", 0.01, 5)
	local hg_movement_speed_lose_mul = CreateConVar("hg_movement_speed_lose_mul", "1", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Multiply speed lose", 0.01, 5)
	local hg_movement_weightmul_mul = CreateConVar("hg_movement_weightmul_mul", "1", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Multiply speed lose", 0.01, 5)

	-- Player:SetCrouchedWalkSpeed takes a multiplier, so GetCrouchedWalkSpeed() returns a fraction
	-- (60 / 85 = ~0.7) and must not be used as an absolute speed here. Read the absolute convar
	-- itself, the same one sh_utility feeds into the engine multiplier.
	local hg_movement_crouchwalkspeed = ConVarExists("hg_movement_crouchwalkspeed") and GetConVar("hg_movement_crouchwalkspeed") or CreateConVar("hg_movement_crouchwalkspeed", "60", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Changes crouch walk speed, default 60", 0, 9999)

	--\\ DeltaTime
		-- SetupMove fires once per usercmd, but the server runs several commands inside one tick.
		-- Taking the wall clock difference between two calls therefore gave ~0 for every command
		-- but the first one, so the server side CurrentSpeed / MovementInertia lagged behind the
		-- client and the prediction had to keep correcting (rubber banding). Split the tick evenly
		-- between the commands of that tick instead, so both realms advance by the same amount for
		-- the same command.
		local tick_interval = engine.TickInterval()

		hook.Add("StartCommand", "HG(CommandCount)", function(ply)
			if not SERVER then return end

			ply.HgCmdCount = (ply.HgCmdCount or 0) + 1
		end)

		hook.Add("Tick", "HG(CommandCountReset)", function()
			if not SERVER then return end

			for _, ply in ipairs(player.GetAll()) do
				ply.HgCmdPerTick = math.max(ply.HgCmdCount or 1, 1)
				ply.HgCmdCount = 0
			end
		end)

		local function hg_delta_time(ply)
			if not SERVER then return FrameTime() end

			return tick_interval / math.max(ply.HgCmdPerTick or 1, 1)
		end
	--//

	local vomitVPAng, vecZero = Angle(1, 0, 0), Vector()
	hook.Add("SetupMove", "HG(StartCommand)", function(ply, mv, cmd)
		if(not IsValid(ply) or not ply:Alive())then
			return
		end

		local org = ply.organism

		if( ( not org ) or ( not org.brain ) )then
			return
		end

		local delta_time = hg_delta_time(ply)

		if !hg.RagdollCombatInUse(ply) and (IsValid(ply.FakeRagdoll) or IsValid(ply:GetNWEntity("FakeRagdollOld"))) then
			if IsValid(ply.FakeRagdoll) then
				cmd:SetForwardMove(0)
				cmd:SetSideMove(0)

				mv:SetForwardSpeed(0)
				mv:SetSideSpeed(0)
			end

			-- math.min() only caps the positive direction: -300 stays -300, so a ragdolled player
			-- crawled backwards at full speed while forwards was limited to 50. Clamp both ways.
			mv:SetForwardSpeed(math.Clamp(mv:GetForwardSpeed(), -50, 50))
			mv:SetSideSpeed(math.Clamp(mv:GetSideSpeed(), -50, 50))

			cmd:RemoveKey(IN_JUMP)
			mv:RemoveKey(IN_JUMP)

			cmd:AddKey(IN_DUCK)
			mv:AddKey(IN_DUCK)

			if ply.MovementInertia then
				ply.MovementInertia:Zero()
			end
		end

		if (ply:GetMoveType() == MOVETYPE_NOCLIP) then
			hook.Run("HG_MovementCalc", vecZero, 0, 1, ply, cmd, mv)
			hook.Run("HG_MovementCalc_2", {1}, ply, cmd, mv)

			return
		end

		if(ply:InVehicle())then
			return
		end

		-- Backpedalling always strips sprint. The stamina cut-off used to be a third clause here
		-- (stamina < 30 while already moving faster than 200) and is now the hysteresis gate, which
		-- does not depend on the current velocity and therefore cannot oscillate with it.
		if not IsValid(ply.FakeRagdoll) and ply:KeyDown(IN_SPEED) and not ply:Crouching() and (ply:KeyDown(IN_BACK) or stamina_sprint_blocked(ply, org)) then
			cmd:RemoveKey(IN_SPEED)
			mv:RemoveKey(IN_SPEED)
		end

		local wantCrouchRun = ply:Crouching() and cmd:KeyDown(IN_SPEED) and ply:KeyDown(IN_FORWARD)
		local runnin = cmd:KeyDown(IN_SPEED) and not ply:Crouching() and ply:KeyDown(IN_FORWARD)
		local crouchrunnin = wantCrouchRun and ply:OnGround() and not IsValid(ply.FakeRagdoll)

		--[[if runnin then
			mv:SetSideSpeed(0) --meh
			cmd:SetSideMove(0)
			cmd:RemoveKey(IN_BACK)
		end]]


		local wep = ply:GetActiveWeapon()
		local vel = ply:GetVelocity()
		local velLen = vel:Length()
		-- brain damage used to multiply the input by sin(CurTime()/2). The input is normalised to
		-- +-1 a few lines below, so that only ever flipped the direction: a concussed player walked
		-- backwards twice per cycle instead of wobbling. The wobble now scales speed (k) instead.
		local brain_wobble = 1

		if org.brain and org.brain > 0.1 then
			brain_wobble = 1 - math.min(org.brain, 1) * 0.5 * (0.5 + 0.5 * math.sin(CurTime() / 2))
		end

		local fm = cmd:GetForwardMove()
		local sm = cmd:GetSideMove()

		local slow_walking = ply:KeyDown(IN_WALK)
		local aiming = ply:KeyDown(IN_ATTACK2) and wep and IsValid(wep) and ishgweapon(wep)
		local walk_speed = ply:GetWalkSpeed()
		local slow_walk_speed = ply:GetSlowWalkSpeed()
		local crouch_walk_speed = hg_movement_crouchwalkspeed:GetFloat()
		local weightmul = hg.CalculateWeight(ply, 140)
		local rag = hg.GetCurrentCharacter(ply)
		ply.weightmul = weightmul
		weightmul = math.max(weightmul > 0.9 and 1 or weightmul / 0.9, 0.1)

		--\\ Experimental pz-like sprint code
			--[[ply:SetRunSpeed((IsValid(wep) and wep ~= NULL and wep:GetClass() == "weapon_hands_sh" and slow_walking) and 390 or 230)
			if IsValid(wep) and wep ~= NULL and wep:GetClass() == "weapon_hands_sh" and runnin and slow_walking then
				mv:SetSideSpeed(0)
				cmd:SetSideMove(0)
				cmd:RemoveKey(IN_BACK)
			end]]
		--//

		--ply:SetRunSpeed(350)

		if ply:GetNWBool("TauntHolsterWeapons", false) then
			if IsValid(ply:GetWeapon("weapon_hands_sh")) then
				cmd:SelectWeapon(ply:GetWeapon("weapon_hands_sh"))
				if SERVER then ply:SelectWeapon(ply:GetWeapon("weapon_hands_sh")) end
			end
		end

		if org.brain and org.brain > 0.05 then
			local brainadjust = org.brain > 0.05 and math.Clamp(((org.brain - 0.05) * math.sin(CurTime() + 10) * 20), -2, 2) or 0

			if brainadjust > 1 then
				local in_jump = cmd:KeyDown(IN_JUMP)

				if in_jump then
					cmd:RemoveKey(IN_JUMP)
					cmd:AddKey(IN_DUCK)
					mv:RemoveKey(IN_JUMP)
					mv:AddKey(IN_DUCK)
				end
			end

			if brainadjust < -1 then
				local in_duck = cmd:KeyDown(IN_DUCK)

				if in_duck then
					cmd:RemoveKey(IN_DUCK)
					cmd:AddKey(IN_JUMP)
					mv:RemoveKey(IN_DUCK)
					mv:AddKey(IN_JUMP)
				end
			end
		end

		if ply:GetNetVar("vomiting", 0) > CurTime() then
			cmd:AddKey(IN_DUCK)
			mv:AddKey(IN_DUCK)
			if ply == lply then ViewPunch(vomitVPAng) end
		end

		--\\ Running
		ply.CurrentSpeed = ply.CurrentSpeed or walk_speed

		ply.SpeedGainMul = 135 * weightmul * (ply.organism.superfighter and 5 or 1) * (ply:GetNWInt("SpeedGainClassMul", 1) or 1)
		ply.SpeedGainMul = ply.SpeedGainMul * hg_movement_speed_gain_mul:GetFloat()

		ply.SpeedLoseMul = 420
		ply.SpeedLoseMul = ply.SpeedLoseMul * hg_movement_speed_lose_mul:GetFloat()

		ply.SpeedSharpLoseMul = 0.009
		ply.InertiaBlend = 650 * weightmul * (ply.organism.superfighter and 100 or 1)

		hook.Run("HG_MovementCalc", vel, velLen, weightmul, ply, cmd, mv)

		-- the default multiplier is 1 (pure "multiply" semantics for HG_MovementCalc_2). It used to
		-- be seeded with ply.move / ply:GetRunSpeed(), which already contains 1.1 * k, and the result
		-- was then multiplied by ply.move again below -- the target speed came out squared.
		local mul = {1}

		hook.Run("HG_MovementCalc_2", mul, ply, cmd, mv)

		mul = mul[1] or 1

		if mul <= 0.01 then
			mul = 0.01
		end

		mul = mul * (ply:GetNWBool("TauntStopMoving", false) and 0.01 or 1)

		if (ply.CrouchSlowUntil or 0) > CurTime() then
			mul = mul * 0.3
		end

		if(runnin and velLen >= 10)then
			ply.CurrentSpeed = math.Approach(ply.CurrentSpeed, (ply.move or ply:GetRunSpeed()) * mul, delta_time * ply.SpeedGainMul)
		elseif(crouchrunnin and velLen >= 10)then
			ply.CurrentSpeed = math.Approach(ply.CurrentSpeed, math.min(crouch_walk_speed * 2.1, 135) * mul, delta_time * ply.SpeedGainMul)
		else
			if(ply:Crouching())then
				ply.CurrentSpeed = math.Approach(ply.CurrentSpeed, crouch_walk_speed * mul, delta_time * ply.SpeedLoseMul)
			elseif(slow_walking)then
				ply.CurrentSpeed = math.Approach(ply.CurrentSpeed, slow_walk_speed * mul, delta_time * ply.SpeedLoseMul)
			elseif(aiming)then
				ply.CurrentSpeed = math.Approach(ply.CurrentSpeed, slow_walk_speed * mul, delta_time * ply.SpeedLoseMul)
			else
				ply.CurrentSpeed = math.Approach(ply.CurrentSpeed, walk_speed * mul, delta_time * ply.SpeedLoseMul)
			end
		end
		--//

		--\\ Speed acceleration & deceleration
		ply.LastVelocity = ply.LastVelocity or vel
		ply.LastVelocityLen = velLen

		local change = math.abs(math.AngleDifference(calc_vector2d_angle(ply.LastVelocity), calc_vector2d_angle(vel))) // * (SERVER and 0 or 5)

		if ply.LastVelocity == vel and ply.LastChangeVelocity then // this is so bullshit but it works
			change = ply.LastChangeVelocity
		end

		local change_mul = math.abs(ply.CurrentSpeed - slow_walk_speed)

		ply.LastChangeVelocity = change
		ply.CurrentSpeed = math.Approach(ply.CurrentSpeed, slow_walk_speed * mul, delta_time * change * change_mul * ply.SpeedSharpLoseMul * 0.25 * 200)
		ply.LastVelocity = vel
		ply.LastVelocityLen = velLen
		--//

		local speed = ply.CurrentSpeed
		--\\ Inertia
		local ply_angles = cmd:GetViewAngles()

		ply.MovementInertia = ply.MovementInertia or vel

		-- hg_inertia_enabled is the master switch for the whole inertia model. It used to gate only
		-- mv:SetForwardSpeed/SetSideSpeed further down, while the integration below and the usercmd
		-- override on the client ran unconditionally -- so inertia was always on and the convar did
		-- nothing. Read it once per command so client and server always agree within a tick.
		local inertia_enabled = hg_inertia_enabled:GetBool()

		--\\ Side & back running debuffs
			-- cmd:GetForwardMove/GetSideMove are in units per second (a full strafe is about +-450),
			-- NOT in a 0..1 range. They have to be normalised before they are used as a *multiplier*
			-- here -- feeding the raw value into movement_penalty divided the speed by ~540 and made
			-- strafing (A/D) impossible, while W/S kept working because their side move is 0.
			fm = fm / math.abs(fm ~= 0 and fm or 1)
			sm = sm / math.abs(sm ~= 0 and sm or 1)
			local movement_penalty = math.abs(sm * 1.2)

			if(movement_penalty == 0)then
				movement_penalty = 1
			end

			if(fm < 0)then
				movement_penalty = math.max(movement_penalty, runnin and 1.9 or 1.5)
			elseif(sm ~= 0 and runnin)then
				movement_penalty = math.max(movement_penalty, 1.7)
			end

			speed = speed / movement_penalty
		--//

		local inertia_to = calc_forward_side_moves_to_vector2d(fm, sm, ply_angles) * speed
		--\\ Air & water walking debuffs
			local water_level = ply:WaterLevel()

			if((not ply:OnGround()) and (water_level < 1))then
				-- speed can be 0 (standing still with a stale CurrentSpeed), and the trace direction
				-- below divides by it -- that produced a NaN trace end point
				if(speed > 0.01 and (fm ~= 0 or sm ~=0))then
					local start_pos = ply:GetPos()
					local trace_data = {
						start = start_pos,
						endpos = start_pos + inertia_to / speed * 50,
						filter = ply
					}

					if(util.TraceLine(trace_data).Hit)then
						movement_penalty = 1
					else
						movement_penalty = 5
					end

					--if(CLIENT)then
						speed = speed / movement_penalty
					--end

					inertia_to = calc_forward_side_moves_to_vector2d(fm, sm, ply_angles) * speed
				end
			end
		--//

		--\\ Friction
			local consciousness = 1

			if ply.organism and ply.organism.consciousness then
				consciousness = consciousness * ply.organism.consciousness
				consciousness = consciousness * math.Clamp((ply.organism.blood or 0) / 4000, 0.5, 1)
			end

			local consmul = math.Clamp(((consciousness - 1) * 4 + 1), 0.1, 1)

			-- the per-surface friction ramp that used to live here is gone; consmul is applied to the
			-- speed multiplier (k) instead, and hg_inertiamul is the single inertia knob
			ply.CurrentFrictionMul = 0.5 / hg_inertiamul:GetFloat()
			ply.InertiaBlend = ply.InertiaBlend * ply.CurrentFrictionMul

		--\\ Inertia integration
		local inertia_len, forward_move, side_move

		if inertia_enabled then
			if !ply:OnGround() then
				ply.MovementInertia = ply.LastVelocity	
			end

			local new_inertia = approach_vector(ply.MovementInertia, inertia_to, delta_time * ply.InertiaBlend)

			ply.MovementInertia = new_inertia

			inertia_len = math.sqrt(ply.MovementInertia.x * ply.MovementInertia.x + ply.MovementInertia.y * ply.MovementInertia.y)

			forward_move, side_move = calc_forward_side_moves(ply.MovementInertia, ply_angles)

			if CLIENT then
				ply.MovementInertiaAddView = ply.MovementInertiaAddView or Angle(0, 0, 0)
				ply.MovementInertiaAddView.r = ply.MovementInertiaAddView.r + side_move * delta_time * inertia_len * 0.03
				ply.MovementInertiaAddView.p = ply.MovementInertiaAddView.p + math.abs(side_move) * delta_time * inertia_len * 0.01
			end
		else
			-- Inertia off: no direction override and no camera sway, the raw command direction is
			-- used and only the resulting max speed is capped below.
			-- assign a fresh vector instead of Zero(): MovementInertia can alias LastVelocity on the
			-- first tick, and zeroing it in place would wipe the previous velocity too
			ply.MovementInertia = Vector(0, 0, 0)
			if CLIENT and ply.MovementInertiaAddView then
				ply.MovementInertiaAddView.r = 0
				ply.MovementInertiaAddView.p = 0
			end

			inertia_len = speed
			forward_move, side_move = fm, sm
		end
		--//

		local move = ply:GetRunSpeed() * 1.1
		local k = 1 * math.min(weightmul / hg_movement_weightmul_mul:GetFloat(), 1)
		k = k * math.Clamp(consmul, 0.7, 1)
		k = k * math.Clamp((org.temperature and (1 - (org.temperature - 38) * 0.25) or 1), 0.5, 1)
		k = k * math.Clamp((org.temperature and ((org.temperature - 35) * 0.25 + 1) or 1), 0.5, 1)
		k = k * stamina_speed_mul(hg.stamina and hg.stamina.ratio(org) or 1)
		k = k * math.Clamp(5 / ((org.immobilization or 0) + 1), 0.45, 1)
		k = k * math.Clamp((org.blood or 0) / 5000, 0, 1)
		k = k * math.Clamp(10 / ((org.shock or 0) + 1), 0.45, 1)
		k = k * adrenaline_speed_mul(org)
		k = k * surface_speed_mul(ply)
		k = k * math.Clamp((org.lleg and org.lleg >= 0.5 and math.max(1 - org.lleg, 0.6) or 1) * (org.rleg and org.rleg >= 0.5 and math.max(1 - org.rleg, 0.6) or 1) * ((org.analgesia or 0) * 1 + 1), 0, 1)
		k = k * (org.llegdislocation and 0.75 or 1) * (org.rlegdislocation and 0.75 or 1)
		k = k * (org.pelvis == 1 and 0.4 or 1)
		k = k * ((IsValid(ply:GetNetVar("carryent")) or IsValid(ply:GetNetVar("carryent2"))) and math.Clamp(50 / math.max(ply:GetNetVar("carrymass", 0) + ply:GetNetVar("carrymass2", 0), 1), 0.5, 1) or 1)
		k = k * math.Clamp(20 / ((org.pain or 0) + 1), 0.01, 1)
		//k = k * (ishgweapon(wep) and not wep:IsPistolHoldType() and not wep:ReadyStance() and 0.75 or 1)

		-- slowDown is the hard landing penalty. Its only decay line was commented out, so the value
		-- only ever went up and the 0.75 floor stuck to the player permanently -- it even survived
		-- respawn, because the netvar lives on the entity and nothing reset it.
		local slwdwn = ply:GetNetVar("slowDown", 0)

		if slwdwn > 0 then
			if SERVER then
				ply:SetNetVar("slowDown", math.Approach(slwdwn, 0, delta_time * 250))
			end

			k = k * math.Clamp((250 - slwdwn) / 250, 0.75, 1)
		end

		k = math.max(k, 20 / 200)

		if brain_wobble ~= 1 then
			k = k * brain_wobble
		end

		if ply:GetNetVar("vomiting", 0) > (CurTime() - 3) then
			k = k * 0.25
		end

		local ent = IsValid(ply:GetNetVar("carryent")) and ply:GetNetVar("carryent") or IsValid(ply:GetNetVar("carryent2")) and ply:GetNetVar("carryent2")

		if SERVER and inertia_len > 5 and (runnin or crouchrunnin) then
			local mul = math.Clamp(inertia_len / 200, 0.5, 1) * 5 * (ply:Crouching() and 0.01 or 1)
			if ply == rag then
				if org.pelvis == 1 then
					org.painadd = org.painadd + FrameTime() * mul
				end
				if (org.lleg == 1) or org.llegdislocation then
					org.painadd = org.painadd + FrameTime() * mul
				end

				if (org.rleg == 1) or org.rlegdislocation then
					org.painadd = org.painadd + FrameTime() * mul
				end
			end
		end

		if IsValid(ent) then
			local bon = ply:GetNetVar("carrybone",0) ~= 0 and ply:GetNetVar("carrybone",0) or ply:GetNetVar("carrybone2",0)
			local bone = ent:TranslatePhysBoneToBone(bon)
			local mat = ent:GetBoneMatrix(bone)
			local pos = mat and mat:GetTranslation() or ent:GetPos()
			local lpos = IsValid(ent) and ply:GetNetVar("carrypos",nil) or ply:GetNetVar("carrypos2",nil)

			if lpos then
				if not ent:IsRagdoll()then
					pos = ent:LocalToWorld(lpos)
				else
					pos = LocalToWorld(lpos, angle_zero, mat:GetTranslation(), mat:GetAngles())
				end
			end

			local eyetr = hg.eyeTrace(ply)
			local dist = pos:DistToSqr(eyetr.StartPos)
			local reachdist = weapons.GetStored("weapon_hands_sh").ReachDistance + 30
			if dist > reachdist*reachdist then
				local moving_to = calc_forward_side_moves_to_vector2d(fm, sm, ply_angles)
				local dot = moving_to:Dot((pos - eyetr.StartPos):GetNormalized())
				k = k * dot
			end
		end

		move = move * k
		ply.move = move

		if SERVER and not IsValid(ply.FakeRagdoll) then
			ply.eyeAnglesOld = ply.eyeAnglesOld or ply:EyeAngles()
			local cosine = ply:EyeAngles():Forward():Dot(ply.eyeAnglesOld:Forward())
			ply.eyeAnglesOld = ply:EyeAngles()

			-- cosine <= 0.99 is any head turn wider than ~8 degrees, so this used to fire on every
			-- single tick while strafing on ice (and the random branch fires on its own). One slip
			-- per 1.5s is plenty.
			if (ply.HgNextSlip or 0) < CurTime() and velLen > 200 and (math.random(150) == 1 or cosine <= 0.99) then
				local tr = {}
				tr.start = ply:GetPos()
				tr.endpos = tr.start - vector_up * 1
				tr.filter = ply
				tr = util.TraceLine(tr)

				if tr.SurfaceProps and util.GetSurfaceData(tr.SurfaceProps) and util.GetSurfaceData(tr.SurfaceProps).friction < 0.2 then
					local b1 = ply:TranslateBoneToPhysBone(ply:LookupBone("ValveBiped.Bip01_L_Calf"))
					local phys1 = hg.IdealMassPlayer["ValveBiped.Bip01_L_Calf"]

					local b2 = ply:TranslateBoneToPhysBone(ply:LookupBone("ValveBiped.Bip01_R_Calf"))
					local phys2 = hg.IdealMassPlayer["ValveBiped.Bip01_R_Calf"]

					local torso = ply:TranslateBoneToPhysBone(ply:LookupBone("ValveBiped.Bip01_Spine2"))
					local phystorso = hg.IdealMassPlayer["ValveBiped.Bip01_Spine2"]
					local force = vel:GetNormalized() * 150

					ply.HgNextSlip = CurTime() + 1.5

					hg.AddForceRag(ply, torso, -force * 5 * phystorso, 0.5)
					hg.AddForceRag(ply, b1, (force * 5 - vector_up * 2) * phys1, 0.5)
					hg.AddForceRag(ply, b2, (force * 5 - vector_up * 2) * phys2, 0.5)

					timer.Simple(0,function()
						hg.StunPlayer(ply)
					end)
				end
			end
		end

		--// Dive jump
		if hg_divejump:GetBool() then
			ply.lastInDuck = ply:KeyPressed(IN_DUCK) and CurTime() or ply.lastInDuck or 0
			ply.lastInJump = ply:KeyPressed(IN_JUMP) and CurTime() or ply.lastInJump or 0
			if(SERVER && rag == ply && (ply.lastInJump + 0.1 > CurTime()) && (ply.lastInDuck + 0.1 > CurTime()))then
				local force = ply:GetAimVector() * 400
				force[3] = 0
				local torso = ply:TranslateBoneToPhysBone(ply:LookupBone("ValveBiped.Bip01_Spine2"))
				local phystorso = hg.IdealMassPlayer["ValveBiped.Bip01_Spine2"]
				hg.AddForceRag(ply, torso, force * phystorso, 0.5)
				hg.Fake(ply)
			end
		end

		--print(speed.." "..(CLIENT and "c" or "s"))
		--speed = SERVER and speed + 50 or speed

		local airborne = not ply:OnGround() and ply:WaterLevel() < 2 and not IsValid(ply.FakeRagdoll)

		if airborne then
			ply.HgAirSpeed = math.max(ply.HgAirSpeed or 0, vel:Length2D())

			if not ply.HgWasAirborne and zb and zb.CROUND == "hmcd" then
				local max_air = ply:GetRunSpeed() * 1.15
				local len2d = vel:Length2D()

				if len2d > max_air then
					local ratio = max_air / len2d
					mv:SetVelocity(Vector(vel.x * ratio, vel.y * ratio, vel.z))
				end
			end
		elseif ply.HgWasAirborne then
			if (ply.HgAirSpeed or 0) > 200 then
				local hard = math.Clamp((ply.HgAirSpeed - 200) / 400, 0, 1)
				ply.HgLandSlowDur = 0.6 + hard * 1.2 + (1 - weightmul) * 0.5
				ply.HgLandSlowUntil = CurTime() + ply.HgLandSlowDur
				ply.HgLandSlowHard = hard
				if SERVER and hard > 0.5 and rag == ply then
					ply:SetNetVar("slowDown", math.min((ply:GetNetVar("slowDown", 0) or 0) + 60 * hard, 250))
				end
				if CLIENT and ply == lply and hard > 0.3 then ViewPunch(Angle(2 + hard * 3, 0, 0)) end
			end

			ply.HgAirSpeed = 0
		end

		ply.HgWasAirborne = airborne

		if ply:GetMoveType() == MOVETYPE_LADDER or ply:GetMoveType() == MOVETYPE_NONE then
			inertia_len = 100
		end

		if org.noradrenaline and org.noradrenaline > 0 and inertia_len > 0 then
			inertia_len = inertia_len + 200 * math.Round(org.noradrenaline, 1)
		end
		
		if (ply.HgLandSlowUntil or 0) > CurTime() then
			local landMin = (org.adrenaline or 0) > 15 and 0.85 or 0.4
			local dur = math.max(ply.HgLandSlowDur or 1, 0.01)
			local t = math.Clamp((ply.HgLandSlowUntil - CurTime()) / dur, 0, 1)
			t = t * t * (3 - 2 * t)
			local landMul = 1 - (1 - landMin) * t
			inertia_len = inertia_len * landMul
			ply.CurrentSpeed = math.min(ply.CurrentSpeed or inertia_len, inertia_len)
		end

		if ply:Crouching() then inertia_len = math.min(inertia_len, 140 * k) end

		-- uncrouch kick: CurrentSpeed was pinned low by crouch clamp, pop it up so stand-up does not feel stuck
		local wasCrouch = ply.HgWasCrouching and true or false
		local isCrouch = ply:Crouching() and true or false

		if wasCrouch and not isCrouch and not IsValid(ply.FakeRagdoll) then
			local standTarget = (ply.move or walk_speed) * mul
			ply.CurrentSpeed = math.max(ply.CurrentSpeed or 0, math.min(standTarget, ply:GetRunSpeed() * 1.1))
		end

		ply.HgWasCrouching = isCrouch

		mv:SetMaxSpeed(inertia_len)
		mv:SetMaxClientSpeed(inertia_len)
		ply:SetMaxSpeed(math.max(100, inertia_len))
		ply:SetJumpPower(DEFAULT_JUMP_POWER * math.min(k, 1.1) * (not ply:GetNWBool("TauntStopMoving", false) and 1 or 0) * (ply.organism.superfighter and 1.5 or 1) * (ply.JumpPowerMul or 1))

		if inertia_enabled then
			if CLIENT then
				local fwangs = math.rad(GetViewPunchAngles2()[2] + GetViewPunchAngles3()[2])
				local c, s = math.cos(fwangs), math.sin(fwangs)

				-- rotate the inertia vector by the view punch. The old version fed the already
				-- overwritten forward_move into the side term and the matrix was not a rotation
				-- (determinant != 1), so a strong view punch skewed and shrank the movement vector.
				local fwd, side = forward_move, side_move

				forward_move = fwd * c + side * s
				side_move = side * c - fwd * s

				cmd:SetForwardMove(forward_move * inertia_len)
				cmd:SetSideMove(side_move * inertia_len)
			end

			-- the engine copies cmd into mv before SetupMove runs, so mv has to be written too for
			-- the local prediction to match what the server will do with our cmd
			mv:SetForwardSpeed(forward_move * inertia_len)
			mv:SetSideSpeed(side_move * inertia_len)
		end

		if not airborne then return end

		-- Air control is deliberately tiny. The clamp used to touch mv only, while the client had
		-- already written the full inertia_len into the usercmd above, so the server received the
		-- unclamped value and both realms disagreed about air movement. Clamp the cmd as well.
		local airfwd = mv:GetForwardSpeed()
		local airside = mv:GetSideSpeed()
		local airlen = math.sqrt(airfwd * airfwd + airside * airside)

		if airlen > 15 then
			local airscale = 15 / airlen
			mv:SetForwardSpeed(airfwd * airscale)
			mv:SetSideSpeed(airside * airscale)
		end

		if CLIENT then
			local cfwd, cside = cmd:GetForwardMove(), cmd:GetSideMove()
			local clen = math.sqrt(cfwd * cfwd + cside * cside)

			if clen > 15 then
				local cscale = 15 / clen
				cmd:SetForwardMove(cfwd * cscale)
				cmd:SetSideMove(cside * cscale)
			end
		end
	end)
--//

--\\ Remove sandbox jump boost
	local gamemod = engine.ActiveGamemode()
	hook.Add("PlayerSpawn", "RemoveSandboxJumpBoost", function(ply)
		if (gamemod != "sandbox") then return end

		local PLAYER = baseclass.Get("player_sandbox")

		PLAYER.FinishMove           = nil       -- Disable boost
		PLAYER.StartMove           	= nil       -- Disable boost
		PLAYER.SlowWalkSpeed		= 100		-- How fast to move when slow-walking (+WALK)
		PLAYER.WalkSpeed			= 190		-- How fast to move when not running
		PLAYER.RunSpeed				= 320		-- How fast to move when running
		PLAYER.CrouchedWalkSpeed	= 0.4		-- Multiply move speed by this when crouching
		PLAYER.DuckSpeed			= 0.3		-- How fast to go from not ducking, to ducking
		PLAYER.UnDuckSpeed			= 0.3		-- How fast to go from ducking, to not ducking
		PLAYER.JumpPower			= 200		-- How powerful our jump should be
	end)
--//

--\\ Anti-gmod PVP system (anti crouch spam)
	-- A single duck press must not hand out a free duck/unduck speed trick, but the timers here used
	-- to be set by this hook AND by a second, independent "AntiCrouchSpam" hook in sv_util.lua. The
	-- two never talked to each other, so one tap locked duck input for up to 0.85s. This is the only
	-- owner now, with a single pair of timers.
	local hg_crouch_min = CreateConVar("hg_crouch_min", "0.25", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "How long a crouch press is held before you may stand up", 0, 2)
	local hg_crouch_cd = CreateConVar("hg_crouch_cd", "0.15", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Cooldown before you may crouch again", 0, 2)

	hook.Add("StartCommand", "HG_AntiGmodPVP", function(ply, cmd)
		local now = cmd:KeyDown(IN_DUCK)
		ply.NowCrouched = now
		local was = ply.OldCrouched

		if was == nil then
			was = now
		end

		local ct = CurTime()

		-- still inside the forced minimum duck window: refuse to stand up
		if (ply.CrouchMinUntil or 0) > ct and not now then
			cmd:AddKey(IN_DUCK)
			now = true
		end

		local press = now and not was

		if press and ply:OnGround() then
			if (ply.CrouchCdUntil or 0) > ct then
				cmd:RemoveKey(IN_DUCK)
				now = false
			else
				local minduck = hg_crouch_min:GetFloat()

				ply.CrouchMinUntil = ct + minduck
				ply.CrouchSlowUntil = ct + minduck
				-- covers min duck + cooldown in one timestamp, so the two never stack
				ply.CrouchCdUntil = ct + minduck + hg_crouch_cd:GetFloat()

				if SERVER then
					ply:ViewPunch(Angle(1.5, math.random(1,2) == 1 and -0.6 or 0.6, math.random(1,2) == 1 and -0.6 or 0.6))

					local org = ply.organism
					if org and org.stamina then
						org.stamina[1] = math.max((org.stamina[1] or 0) - 15, 0)
					end
				end
			end
		end

		if not ply:OnGround() and ply:WaterLevel() < 2 and ply:GetMoveType() == MOVETYPE_WALK and was != now then
			cmd:AddKey(IN_DUCK)
			now = true
		end

		ply.OldCrouched = now
	end)
--//