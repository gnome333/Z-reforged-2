zb = zb or {}

local KARMA_PUNISH_LIMIT = 50
local PUNISH_MESSAGE = "I was punished for my sins"

if CLIENT then
	local vector_one = Vector(1, 1, 1)

	function zb.SwayText(text, font, x, y, color, alignX, alignY, phase, startAt, hold)
		render.PushFilterMag(TEXFILTER.ANISOTROPIC)
		render.PushFilterMin(TEXFILTER.ANISOTROPIC)

		local m = Matrix()

		surface.SetFont(font)
		local w, h = surface.GetTextSize(text)

		local live = CurTime() - (startAt or zb.ROUND_START or 0)
		local holdTime = hold or 6.5
		local reach = ScrW() * 0.5 + w * 0.5 + 50
		local off = -reach

		if live >= 0 then
			off = 0

			if live < 0.75 then
				local k = live / 0.75
				off = -reach * (1 - k) * (1 - k) * (1 - k)
			elseif live > holdTime then
				local k = math.Clamp((live - holdTime) / 0.32, 0, 1)
				off = reach * k * k * k
			end
		end

		m:Translate(Vector(x + off, y, 0))
		m:Rotate(Angle(0, math.sin(CurTime() * 0.9 + (phase or 0)) * 4, 0))
		m:Scale(vector_one)
		m:Translate(Vector(-w / 2, -h / 2, 0))

		cam.PushModelMatrix(m)
			draw.DrawText(text, font, 0, 0, color)
		cam.PopModelMatrix()

		render.PopFilterMag()
		render.PopFilterMin()
	end

	local PUNISH_COLOR = Color(190, 0, 0)
	local punishStart = -100

	net.Receive("zb_karma_punish", function()
		punishStart = CurTime()
	end)

	function zb.KarmaPunishText()
		local lply = LocalPlayer()

		if not IsValid(lply) or not lply:Alive() then return end

		local live = CurTime() - punishStart

		if live < 0 or live > 9 then return end

		local alpha = 255

		if live < 0.4 then
			alpha = 255 * (live / 0.4)
		elseif live > 7.5 then
			alpha = 255 * math.Clamp((9 - live) / 1.5, 0, 1)
		end

		draw.SimpleText(PUNISH_MESSAGE, "ZB_HomicideMedium", ScrW() * 0.5, ScrH() * 0.82, Color(PUNISH_COLOR.r, PUNISH_COLOR.g, PUNISH_COLOR.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	hook.Add("HUDPaint", "zb_karma_punish_text", zb.KarmaPunishText)

	local activeMusic = {}

	function zb.StopRoundMusic()
		for _, snd in ipairs(activeMusic) do
			snd:Stop()
		end

		activeMusic = {}
	end

	function zb.PlayRoundMusic(paths)
		zb.StopRoundMusic()

		for _, path in ipairs(paths) do
			local snd = CreateSound(LocalPlayer(), path)

			if snd then
				snd:Play()
				table.insert(activeMusic, snd)

				timer.Simple(7, function()
					snd:ChangeVolume(0, 1.5)
				end)

				timer.Simple(8.6, function()
					snd:Stop()
				end)
			end
		end
	end
end

if SERVER then
	util.AddNetworkString("zb_karma_punish")

	local limbs = {"lleg", "rleg", "larm", "rarm"}

	local ribCounts = {2, 2, 3, 3, 5}

	local punishPool = {
		{t = "limb"},
		{t = "ribs"},
		{t = "skull"},
		{t = "organ", organ = "liver", destroyed = false},
		{t = "organ", organ = "liver", destroyed = true},
		{t = "organ", organ = "stomach", destroyed = false},
		{t = "organ", organ = "stomach", destroyed = true},
		{t = "organ", organ = "intestines", destroyed = false},
		{t = "organ", organ = "intestines", destroyed = true},
	}

	local function applyLimb(ply, org)
		local key = limbs[math.random(#limbs)]

		org[key] = 1
		org[key .. "dislocation"] = false
	end

	local function applyBrokenRibs(ply, org)
		local count = ribCounts[math.random(#ribCounts)]

		org.chest = math.min(count / 3, 1)
		org.brokenribs = count
	end

	local function applySkull(ply, org)
		org.skull = math.Rand(0.35, 0.75)
	end

	local function applyOrgan(ply, org, organ, destroyed)
		local target = destroyed and 1 or math.Rand(0.35, 0.75)

		if (org[organ] or 0) < target then
			org[organ] = target
		end
	end

	local function applyPunishments(ply)
		local org = ply.organism

		if not IsValid(ply) or not ply:Alive() then return end
		if not org or not org.alive or org.otrub or org.fake then return end
		if (ply.Karma or 100) >= KARMA_PUNISH_LIMIT then return end
		if OverrideSpawn then return end
		if ply:Team() == TEAM_SPECTATOR then return end

		local round = CurrentRound()

		if istable(round) and round.name == "nswar" then return end

		local poolCopy = table.Copy(punishPool)
		local total = math.random(3, 10)

		while total > 0 and #poolCopy > 0 do
			total = total - 1

			local item = table.remove(poolCopy, math.random(#poolCopy))

			if item.t == "limb" then
				applyLimb(ply, org)
			elseif item.t == "ribs" then
				applyBrokenRibs(ply, org)
			elseif item.t == "skull" then
				applySkull(ply, org)
			elseif item.t == "organ" then
				applyOrgan(ply, org, item.organ, item.destroyed)
			end
		end

		ply.fullsend = true
		ply:Notify(PUNISH_MESSAGE, 16, "karma_punish", 0, nil, Color(255, 60, 60))

		net.Start("zb_karma_punish")
		net.Send(ply)
	end

	hook.Add("Player Spawn", "KarmaPunishments", function(ply)
		timer.Simple(0, function()
			if not IsValid(ply) then return end

			applyPunishments(ply)
		end)
	end)
end
