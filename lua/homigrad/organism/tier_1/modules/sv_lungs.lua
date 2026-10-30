local max, min, Round, Lerp, halfValue2 = math.max, math.min, math.Round, Lerp, util.halfValue2
--local Organism = hg.organism
hg.organism.module.lungs = {}
local module = hg.organism.module.lungs
module[1] = function(org)
	org.lungsL = {
		0, --состояние,пневмотаракс
		0
	}

	org.lungsR = {0, 0}
	org.trachea = 0
	org.pneumothorax = 0
	org.needle = 0
	org.nextCough = nil
	org.o2 = {
		range = 30,
		regen = 4,
		k = 0.5,
	}

	org.lungsfunction = true

	org.o2.curregen = org.o2.regen
	
	org.o2[1] = org.o2.range
	org.CO = 0
	org.COregen = 0
	org.lastCOBreathe = nil

	org.mannitol = 0
end

function hg.organism.OxygenateBlood(org)
	return (math.max(((1 - org.lungsL[1]) + (1 - org.lungsR[1])) / 2, 0.5) * (1 - org.trachea)) * org.o2.regen / 4 * (org.owner:WaterLevel() < 3 and 1 or 0)// * (1 - org.pneumothorax)
end

function hg.organism.CanBreath(org)
	return org.o2 and org.o2.curregen >= org.losing_oxy
end

--[[-------------------------------------------------------------------------
	CO poisoning tunables
	---------------------------------------------------------------------------
	Real carbon monoxide binds haemoglobin roughly 250x more strongly than
	oxygen does, and it is eliminated with a half-life measured in hours. The
	values below compress that into game time but keep the shape of the real
	curve:

	  * elimination is exponential (a half-life), not a linear drain, so the
	    last of the gas lingers a little after leaving the cloud;
	  * the blood does not soak up gas without limit: it settles at a level
	    set by the air around it (CO_HALF_CONC), so a dense plume saturates
	    the blood in seconds while a thin haze stops at a low level and stays
	    there;
	  * lethality follows the dose with a steep curve: a little gas in the
	    blood eats the victim away over tens of minutes (and is survivable if
	    he gets out and the blood clears), a lot of gas kills in a few minutes
	    - slowly enough that getting out is always an option.

	The gas itself only reaches a short distance: a pocket of CO is dangerous
	within CO_POCKET_RADIUS of its centre (and the closer, the worse), so
	walking around the edge of a plume is survivable. CO_POCKET_RADIUS used to
	be 640 - every single pocket poisoned a 13 metre sphere, which made the
	whole room lethal; it is 200 now, so the danger stays inside the visible
	cloud.
---------------------------------------------------------------------------]]
local CO_CONC_MAX = 4.5				-- cap on the internal scale
local CO_ABSORB = 0.85				-- org.CO gained per second per scale unit
local CO_MAX = 30					-- blood saturation ceiling
local CO_CLEAR_HALFLIFE = 30		-- seconds for org.CO to halve in clean air
local CO_BREATHE_CONC = 0.22		-- below this the victim breathes clean air
local CO_BRAIN_RATE = 0.7 / 80		-- brain damage per second at full saturation
local CO_BRAIN_EXP = 2.9			-- how steeply lethality follows the dose
local CO_SLEEP = 10					-- org.CO above which the victim blacks out
local CO_HALF_CONC = 1.6			-- concentration that holds the blood at half saturation
local CO_UPTAKE = 0.055				-- how fast the blood follows the inhaled concentration

local CO_FIRE_RADIUS = 400
local CO_POCKET_RADIUS = 200

--[[-------------------------------------------------------------------------
CO source weighting for the lungs module.
The distance weight is now computed before the visibility trace: when a source
can't beat the current best value anyway, the trace is skipped completely.
Before, every nearby fire / gas pocket was traced for every player twice a second.
---------------------------------------------------------------------------]]
local coTraceLine = util.TraceLine

local function coConsiderSource(epos, blocker, k, pos, owner, rag, best)
	local dsqr = pos:DistToSqr(epos)
	if dsqr > CO_FIRE_RADIUS * CO_FIRE_RADIUS then return best end

	local s = (0.35 + 0.75 * (1 - math.sqrt(dsqr) / CO_FIRE_RADIUS)) * (k or 1)
	if s <= best then return best end

	if dsqr > 64 * 64 then
		local filter = {owner}
		if rag then filter[#filter + 1] = rag end
		if blocker then filter[#filter + 1] = blocker end

		local tr = coTraceLine({
			start = epos,
			endpos = pos,
			mask = MASK_SHOT,
			filter = filter
		})
		if tr.Hit then return best end
	end

	return s
end

local function insta_send_holdingbreath(org)
	net.Start("organism_send") // отправляем только дизориентацию (чтобы не нагружать нет), и сразу
	
	local tbl = {}
	tbl.holdingbreath = org.holdingbreath
	tbl.owner = org.owner

	net.WriteTable(tbl)
	net.WriteBool(true)
	net.WriteBool(false)
	net.WriteBool(false)
	net.WriteBool(true) // вот эта шняга отвечает за то чтобы оно просто мерджнуло и всё
	net.Send(org.owner)
end

local function togglebreath(ply, toggle)
	local org = ply.organism
	
	if isbool(toggle) then
		if toggle then
			if not ply.organism.holdingbreath then
				ply.organism.holdingbreath = true
				ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/inhale/female/inhale_0"..math.random(5)..".wav" or "breathing/inhale/male/inhale_0"..math.random(4)..".wav",65)	
				insta_send_holdingbreath(ply.organism)
			end
		else
			if ply.organism.holdingbreath then
				ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/exhale/female/exhale_0"..math.random(5)..".wav" or "breathing/exhale/male/exhale_0"..math.random(5)..".wav",65)
				ply.organism.holdingbreath = false
				ply.releasebreathe = nil
				insta_send_holdingbreath(ply.organism)
			end
		end
	else
		if ply.organism.holdingbreath then
			ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/exhale/female/exhale_0"..math.random(5)..".wav" or "breathing/exhale/male/exhale_0"..math.random(5)..".wav",65)
			ply.organism.holdingbreath = false
			ply.releasebreathe = nil
			insta_send_holdingbreath(ply.organism)
		else
			ply.organism.holdingbreath = true
			ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/inhale/female/inhale_0"..math.random(5)..".wav" or "breathing/inhale/male/inhale_0"..math.random(4)..".wav",65)	
			insta_send_holdingbreath(ply.organism)
		end
	end

	local ent = hg.GetCurrentCharacter(ply)
	ent:StopSound(ply.lastPhr or "")
	ply.phrCld = 0
end

--[[-------------------------------------------------------------------------
	Breath holding is a toggle, not a hold
	---------------------------------------------------------------------------
	Pressing the key once holds the breath, pressing it again releases it.
	The old behaviour required keeping the key pressed, which is unusable
	while running from a gas cloud.

	Both the plain command and the "+"/"-" pair are supported so existing
	keybinds keep working: the "+" half toggles, and the "-" half does nothing
	on release (otherwise letting go of the key would immediately undo the
	toggle).

	Releasing is always allowed - only *starting* to hold the breath needs
	stamina and working lungs. Being unable to exhale would be worse than the
	thing the check was protecting against.
---------------------------------------------------------------------------]]
local function canStartHoldingBreath(ply)
	if not ply.organism then return false end
	if not ply:Alive() then return false end
	if ply.organism.stamina[1] < 90 then return false end
	if ply.organism.o2.curregen == 0 then return false end
	return true
end

local function doToggleBreath(ply)
	if not ply.organism then return end

	if (ply.cooldownbreathe or 0) > CurTime() then return end

	if ply.organism.holdingbreath then
		-- Releasing is always permitted
		ply.cooldownbreathe = CurTime() + 0.5
		togglebreath(ply, false)
		return
	end

	if not canStartHoldingBreath(ply) then return end

	ply.cooldownbreathe = CurTime() + 0.5
	togglebreath(ply, true)
end

concommand.Add("hmcd_holdbreath", function(ply)
	doToggleBreath(ply)
end)

concommand.Add("+hmcd_holdbreath", function(ply)
	-- One press holds the breath, the next press releases it
	doToggleBreath(ply)
end)

concommand.Add("-hmcd_holdbreath", function(ply)
	-- Releasing the key must NOT release the breath anymore - the state is
	-- owned by the toggle above. Kept as a no-op so old binds stay valid.
end)

local lowoxy = {
	"I'm gonna faint right now... There's not enough oxygen.",
	"There's not enough oxygen... I can't hold much longer...",
	"I really need some fresh air...",
	"I'm gasping for air...",
	"Need to breathe air... or I'm gonna faint right here..."
}

local not_enough_intake = {
	//"I have to breathe...",
	//"I gotta take a break...",
	//"Need a break from this... to breathe...",
	//"Resting sounds like a nice idea.",
	"I need to breathe...",
	"I'm struggling to breathe...",
}

local drop_mask = {
	"I can't breathe in this mask... I need to take it off.",
	"Drop the mask, it's not worth it...",
	"It's fucking disgusting... and I surely can't breathe in this...",
	"Fucking stinks... Gotta take this mask off...",
}

local drugged = {
	"Ohhh hohoohoooo Ie-like it.....",
	"Fukkenh awesomee..... ffffeeelin gooooood..",
	"That's theh sStuffff DUDeeee",
	"I reallly like whatEvER I'm feeling right now....",
	"Oh yeahhhh this feels gooood!",
	"I want to feel likhe this for theRRRREST of my life",
	"Why am I here even?.. wWhatever whuhhh heh",
	"Whoa re you? Gett outtaheree...",
	"Don't want anything else... this is pERRRfect!..",
}

local bit_band,util_PointContents = bit.band,util.PointContents

local color_white, color_red, color_red2, color_red3 = Color(255, 255, 255), Color(255, 0, 0), Color(200, 55, 55), Color(255, 100, 100)
module[2] = function(owner, org, timeValue)
	local o2 = org.o2
	local losing_oxy = timeValue * 1 * math.Clamp(org.o2[1] / 30, 0.25, 1)
	org.losing_oxy = losing_oxy
	o2[1] = max(o2[1] - losing_oxy, 0)
	local ent = hg.GetCurrentCharacter(owner)
	local bone = ent:LookupBone("ValveBiped.Bip01_Head1")

	if (not bone) or (bone < 0) then bone = 6 end

	local head = ent:GetBonePosition(bone)
	
	if not head then
		head = ent:GetBonePosition(0)
	end

	if org.o2.curregen == 0 and org.holdingbreath then
		togglebreath(owner, false)
	end

	if org.holdingbreath then
		//org.stamina[1] = max(org.stamina[1] - timeValue * 15,0)
		if org.stamina[1] < 90 or org.o2[1] <= 10 then
			togglebreath(owner, false)
		end
		
		if owner.releasebreathe and owner.releasebreathe < CurTime() then
			togglebreath(owner, false)
			owner.releasebreathe = nil
		end
	end

	if not head then head = owner:GetPos() end
	
	local inwater = bit_band(util_PointContents(head),CONTENTS_WATER) == CONTENTS_WATER
	-- test
	local success = owner:IsBerserk() or (not org.heartstop and org.alive and not (org.brain >= 0.4 and math.random(10 - (org.brain * 10)) < 4) and org.lungsfunction)
	if success and owner:IsPlayer() and inwater then success = false end
	if success and org.choking then org.needfake = true success = false end
	if success and org.vomitInThroat then success = false end
	org.choking = false
	local pneumothorax = (org.lungsR[2] == 1 or org.lungsL[2] == 1) and org.needle == 0
	
	org.needle = math.Approach(org.needle, 0, timeValue / 1200)

	org.pneumothorax = pneumothorax and min(org.pneumothorax + timeValue / 180 * (org.lungsL[2] + org.lungsR[2]), (org.lungsL[2] + org.lungsR[2]) / 2) or max(org.pneumothorax - timeValue / 10, 0)
	
	if (owner.CheckCO or 0) < CurTime() then
		owner.CheckCO = CurTime() + 0.5

		local pos = owner:GetPos()
		local rag = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or nil
		local best = 0

		if owner:IsOnFire() or (rag and rag:IsOnFire()) then best = 2 end

		for _, e in ipairs(ents.FindInSphere(pos, CO_FIRE_RADIUS)) do
			local cls = e:GetClass()
			if cls == "env_fire" and !e:GetNoDraw() then
				if not e.NextCOSky or e.NextCOSky < CurTime() then
					e.NextCOSky = CurTime() + 5

					local ftr = util.TraceLine({
						start = e:GetPos(),
						endpos = e:GetPos() + Vector(0, 0, 2400),
						mask = MASK_SOLID_BRUSHONLY
					})
					e.COOpenSky = ftr.HitSky or not ftr.Hit
				end

				if not e.COOpenSky then
					best = coConsiderSource(e:GetPos(), e, nil, pos, owner, rag, best)
				end
			elseif cls == "vfire" and e.GetFireState then
				local st = e:GetFireState() or 0
				if st > 2 then
					if not e.NextCOSky or e.NextCOSky < CurTime() then
						e.NextCOSky = CurTime() + 5

						local ftr = util.TraceLine({
							start = e:GetPos(),
							endpos = e:GetPos() + Vector(0, 0, 2400),
							mask = MASK_SOLID_BRUSHONLY
						})
						e.COOpenSky = ftr.HitSky or not ftr.Hit
					end

					if not e.COOpenSky then
						best = coConsiderSource(e:GetPos(), e, (st - 2) / 5, pos, owner, rag, best)
					end
				end
			end
		end

		local parts = hg.particles
		if parts and #parts > 0 then
			local pfilter = {owner}
			if rag then pfilter[#pfilter + 1] = rag end
			if ent != owner then pfilter[#pfilter + 1] = ent end

			local headSqr = CO_POCKET_RADIUS * CO_POCKET_RADIUS
			local partCount = #parts

			for i = 1, partCount do
				if best >= CO_CONC_MAX then break end

				local part = parts[i]
				local inten = part[6]
				if inten and inten > 0.05 then
					local dsqr = head:DistToSqr(part[1])
					if dsqr < headSqr then
						local tr = util.TraceLine({
							start = part[1],
							endpos = head,
							mask = MASK_SHOT,
							filter = pfilter
						})
						if not tr.Hit then
							local s = (0.5 + 0.5 * (1 - math.sqrt(dsqr) / CO_POCKET_RADIUS)) * inten
							best = math.min(best + s, CO_CONC_MAX)
						end
					end
				end
			end
		end

		org.COConcentration = best

		if not org.holdingbreath then
			org.breathCOConc = best
		end

		if best > 0.3 and not org.holdingbreath then
			org.lastCOBreathe = CurTime()
		end
	end

	if org.lastCOBreathe and org.lastCOBreathe + 1 > CurTime() then
		org.COregen = math.Approach(org.COregen, 30, timeValue * 1)
	else
		org.COregen = math.Approach(org.COregen, 0, timeValue * 0.5)
	end

	if (org.COConcentration or 0) < CO_BREATHE_CONC then
		-- Exponential elimination. The half-life is short enough that a victim
		-- who leaves the cloud recovers within a minute or so instead of being
		-- crippled for several minutes, but it is still an exponential curve:
		-- the blood is cleaned fast at first and the last of the gas lingers.
		org.CO = max(org.CO * (0.5 ^ (timeValue / CO_CLEAR_HALFLIFE)), 0)
	end
	if success then
		local oxygenate = hg.organism.OxygenateBlood(org) * 0.5
		local lerp = min(max(org.pulse - 20, 0) / 20, 1)
		local regen = Lerp(lerp, 0, o2.regen * oxygenate * math.Rand(0.95, 1.05))

		if not org.holdingbreath and org.COregen > 0 then
			local conc = org.COConcentration or 0

			if conc > 0 then
				--[[The blood only holds as much gas as the air around it can
				sustain. A dense plume drives it to (almost) full saturation
				in a few seconds, a thin haze settles at a low level and stops
				there no matter how long the victim keeps breathing it - which
				is exactly what makes "a little gas" and "a lot of gas" two
				different fates instead of both ending in saturation.----------]]
				local eq = CO_MAX * conc / (conc + CO_HALF_CONC)
				local k = min(CO_UPTAKE * conc * timeValue, 1)

				org.CO = min(org.CO + (eq - org.CO) * k, CO_MAX)
			end
		end

		if org.holdingbreath then
			local conc = min(org.breathCOConc or 0, org.COConcentration or 0)

			if conc > CO_BREATHE_CONC then
				-- The gas already sitting in the lungs keeps being absorbed,
				-- but it cannot push the blood past the level that same air
				-- would have reached anyway - otherwise holding your breath
				-- would poison you faster than breathing.
				local eq = CO_MAX * conc / (conc + CO_HALF_CONC)

				org.CO = min(org.CO + timeValue * CO_ABSORB * conc, eq)
			end
		end

		if org.CO > CO_SLEEP then
			org.consciousness = math.min(org.consciousness, math.max((CO_MAX - org.CO) / 20, 0))
		end

		--[[Dose-dependent lethality.
		There is no on/off kill threshold any more: the brain damage rate
		follows the amount of gas in the blood through a steep power curve.
		Measured against the model above (the hypoxia makes the top end a
		little faster still):
		  CO ~22 (thick plume):     dies in about 3.5 minutes;
		  CO ~20:                   about 5 minutes;
		  CO ~15:                   about 14 minutes;
		  CO ~12 (thin haze):       about half an hour;
		  CO ~10 (edge of a cloud): over an hour - and the victim can simply
		                            walk out, the blood clears in seconds;
		  CO below ~9:              the brain's own recovery outpaces the
		                            damage, so a trace of gas never kills.
		In other words: breathe a little of it and it eats you away for a very
		long time, breathe a lot and it kills you - but never instantly, and
		never before the victim has had a chance to walk out.----------------]]
		if org.CO > 0.5 then
			local dose = min(org.CO / CO_MAX, 1)
			org.brain = min(org.brain + timeValue * CO_BRAIN_RATE * dose ^ CO_BRAIN_EXP, 1)
		end

		local mask_blevota = owner:GetNetVar("zableval_masku", false)

		local sprayed = org.is_sprayed_at
		org.is_sprayed_at = nil

		local fent = (org.fent or 0) * math.max(1 - (org.naloxone or 0) / 2, 0)
		local regenerate = regen * timeValue * 4 * (org.stamina[1] / org.stamina.max) * (mask_blevota and 0 or 1) * ((org.temperature > 38) and math.Clamp(math.Remap(org.temperature, 38, 41, 1, 0.1), 0.1, 1) or 1) * max(1 - fent * 0.5, 0)
		o2[1] = min(o2[1] + regenerate * math.Clamp(org.o2[1] / 30, 0.25, 1) * (org.holdingbreath and 0 or 1) * (sprayed and 0 or 1) * min((10 / max(org.CO,1)),1), o2.range * math.max(1 - org.pneumothorax * org.pneumothorax, 0.1) * math.min(org.blood / 4500, 1) * math.max(1 - (org.lungsL[1] + org.lungsR[1]) / 2, 0.5))

		o2.curregen = regenerate

		o2[1] = max(o2[1] - (org.CO > 10 and o2.curregen * 1.1 * ((org.CO - 10) / 20) or 0),0)

		//org.owner:ResetNotification("oxygen_cantbreathe")
		//org.owner:ResetNotification("oxygen_cantbreathe2")
	else
		o2.curregen = 0
	end

	if owner:IsBerserk() then
		o2[1] = math.max(5, o2[1])
	end
	
	if org.isPly and not org.otrub and o2.curregen < losing_oxy and org.analgesia <= 1.5 and !org.heartstop then
		if mask_blevota then
			if o2[1] < 15 then
				org.owner:Notify("DROP THE FUCKING MASK", 25, "take_gasmask2", 0, nil, color_red2)
			else
				org.owner:Notify(drop_mask[math.random(#drop_mask)], 15, "take_gasmask", 0)
			end
		else
			if o2[1] < 25 and o2[1] > 12 then
				org.owner:Notify(not_enough_intake[math.random(#not_enough_intake)], 61, "oxygen_lowintake", 0)
			end
		end

		if o2[1] < 12 then
			org.owner:Notify(lowoxy[math.random(#lowoxy)], 30, "lowoxy", 0, nil, color_red3)
	
			if o2[1] < 6 then
				org.owner:Notify("Oxygen... please...", 30, "lowoxy2", 0, nil, color_red)
			end
		end
	end

	if org.analgesia > 1.5 then
		org.owner:Notify(drugged[math.random(#drugged)], 30, "drugged", 0, nil, color_white)
	end

	if org.analgesia > 1.5 or org.painkiller > 2.4 then
		if math.Rand(0, 500) < (org.analgesia + org.painkiller) then
			//org.lungsfunction = false
		end
	end

	if o2[1] == 0 then
		if math.random(50) == 1 then
			org.lungsfunction = false
		end
	else
		if math.random(50) == 1 then
			org.lungsfunction = true
		end
	end

	if (org.lungsL[1] == 1 and org.lungsR[1] == 1) or org.heartstop then
		org.lungsfunction = false
	end

	--[[if (pneumothorax or org.trachea >= 0.6 or org.lungsR[1] >= 0.6 or org.lungsL[1] >= 0.6) and org.alive and o2[1] > 0 then
		local timeSub = org.pneumothorax + org.trachea + org.lungsR[1] + org.lungsL[1]
		org.nextCough = org.nextCough and org.nextCough or (CurTime() + 5)
		
		if org.nextCough < CurTime() then
			org.nextCough = CurTime() + math.random(15,30 - timeSub + math.max(10 - o2[1],0))
			owner:EmitSound("homigrad/player/male/male_cough"..math.random(5)..".wav",50 + Round(timeSub * 2.5))
		end
	end--]]

	if org.isPly then
		if org.pneumothorax > 0 then
			org.owner:Notify("I can feel something filling my lungs.", true, "pneumothorax1",10) // delay of 10 seconds before typing that
		else
			org.owner:ResetNotification("pneumothorax1")
		end

		if org.pneumothorax > 0.3 then
			org.owner:Notify("It's getting harder to breathe.", true, "pneumothorax2", 5)
		else
			org.owner:ResetNotification("pneumothorax2")
		end

		if org.pneumothorax > 0.5 then
			org.owner:Notify("I'm really struggling to breathe.", true, "pneumothorax3", 5)
		else
			org.owner:ResetNotification("pneumothorax3")
		end
	end

	local k = halfValue2(o2[1], o2.range, o2.k)

	if o2[1] < 10 then
		if org.isPly then
			hg.StunPlayer(owner, 3)
		end
	end

	if o2[1] < 12 then
		org.needfake = true

		if org.isPly then
			hg.LightStunPlayer(owner, 3)
		end
	end

	if o2[1] < 4 then
		org.needotrub = true
	end

	if org.lungsR[1] < 0.5 then
		//org.lungsR[1] = max(org.lungsR[1] - timeValue / 240, 0)
	end

	if org.lungsL[1] < 0.5 then
		//org.lungsL[1] = max(org.lungsL[1] - timeValue / 240, 0)
	end

	if owner:IsBerserk() then
		org.brain = math.min(0.5, org.brain)
	end

	if org.skull >= 0.6 then k = 0 end
	if org.brain >= 0.6 then k = 0 end

	if org.skull < 1 and org.skull >= 0.5 and org.bandagedskull then
		org.skull = math.Approach(org.skull, 0, timeValue / 600)
	end

	if org.brain >= 0.3 then
		if org.brain >= 0.5 then
			if math.random(60) == 1 then
				org.heartstop = true
			end
		end

		if org.brain > 0.35 and !org.heartstop then
			if math.random(60) == 1 then
				org.lungsfunction = true
			end
		end

		org.needotrub = true
	end

	local death_from_braindamage = false
	if org.brain >= 0.7 and org.alive then
		death_from_braindamage = true
		org.alive = false
	end

	if org.skull == 1 then org.brain = min(org.brain + timeValue / 1000, 1) end

	if org.isPly then
		if org.brain > 0.1 and org.brain < 0.3 then
			org.owner:Notify(math.random(2) == 1 and "My head hurts..." or "Where am I?", true, "brain", 5)
		else
			org.owner:ResetNotification("brain") 
		end
	end

	org.brain = max(org.brain - timeValue / 400 * ((org.mannitol > 0 and org.brain < 0.6) and 1 or (org.brain > 0.1 and 0.1 or 0)), 0)
	org.mannitol = math.Approach(org.mannitol, 0, timeValue / 200)
	
	if k < 0.25 then
		if not org.alive and owner:IsPlayer() and death_from_braindamage and org.o2[1] == 0 then
			hg.achievements.AddPlayerAchievement(owner,"brain",1)
			if org.analgesia > 1 then
				hg.achievements.AddPlayerAchievement(owner,"drugs",1)
			end
		end
		
		org.brain = min(org.brain + timeValue / (org.brain < 0.3 and 300 or 120) * math.min(((org.o2[1] < 0.25 and 1 or 0) + org.skull), 1), 1)
	end --~120 seconds to fully die (0.3 of 300 and 0.4 of 60 seconds after)
end
