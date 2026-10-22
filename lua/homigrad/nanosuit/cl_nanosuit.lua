local NS

local function getNS()
	NS = hg.NanoSuit
	return NS
end

local fonts = {
	{name = "NanoSuit_Label", font = "Apercu Mono", size = 30, weight = 500},
	{name = "NanoSuit_LCD", font = "LCD", size = 34, weight = 400},
	{name = "NanoSuit_Tiny", font = "Apercu Mono", size = 12, weight = 400},
}

local function createFonts()
	for _, f in ipairs(fonts) do
		surface.CreateFont(f.name, {font = f.font, size = f.size, weight = f.weight, extended = true, antialias = true})
	end
end

createFonts()
hook.Add("InitPostEntity", "NanoSuitFonts", createFonts)

local RED = Color(255, 70, 55, 255)

local function getTheme()
	local nsh = hg.NanoSuit
	if not nsh or not nsh.Themes then return end
	local lp = LocalPlayer()
	local variant = IsValid(lp) and lp:GetNetVar("NS_Variant", 0) or 0
	return nsh.Themes[variant] or nsh.Themes[0]
end

local lastSend = 0
local function sendMode(m)
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:GetNetVar("NS_Has", false) then return end
	local ct = CurTime()
	if ct < lastSend + 0.3 then return end
	lastSend = ct
	net.Start("NanoSuit_SetMode")
	net.WriteUInt(m, 3)
	net.SendToServer()
end

local function drawQuad(x1, y1, x2, y2, x3, y3, x4, y4, col)
	surface.SetDrawColor(col)
	surface.DrawPoly({
		{x = x1, y = y1, u = 0, v = 0},
		{x = x2, y = y2, u = 1, v = 0},
		{x = x3, y = y3, u = 1, v = 1},
		{x = x4, y = y4, u = 0, v = 1},
	})
end

local function chamfer(corners, ch)
	local n = #corners
	local out = {}
	for i = 1, n do
		local cur = corners[i]
		local prv = corners[(i - 2) % n + 1]
		local nxt = corners[i % n + 1]
		local d1 = Vector(prv.x - cur.x, prv.y - cur.y, 0)
		d1:Normalize()
		local d2 = Vector(nxt.x - cur.x, nxt.y - cur.y, 0)
		d2:Normalize()
		out[#out + 1] = {x = cur.x + d1.x * ch, y = cur.y + d1.y * ch, u = 0, v = 0}
		out[#out + 1] = {x = cur.x + d2.x * ch, y = cur.y + d2.y * ch, u = 0, v = 0}
	end
	return out
end

local function drawOutline(pts, col)
	local n = #pts
	surface.SetDrawColor(col)
	for i = 1, n do
		local a = pts[i]
		local b = pts[i % n + 1]
		local dx, dy = b.x - a.x, b.y - a.y
		local len = math.sqrt(dx * dx + dy * dy)
		if len > 0 then
			local mx, my = -dy / len, dx / len
			for k = 0, 1 do
				surface.DrawLine(a.x + mx * k, a.y + my * k, b.x + mx * k, b.y + my * k)
			end
		end
	end
end

local function cornerMarks(x, y, w, h, s, col)
	surface.SetDrawColor(col)
	surface.DrawLine(x, y, x + s, y)
	surface.DrawLine(x, y, x, y + s)
	surface.DrawLine(x + w, y, x + w - s, y)
	surface.DrawLine(x + w, y, x + w, y + s)
	surface.DrawLine(x, y + h, x + s, y + h)
	surface.DrawLine(x, y + h, x, y + h - s)
	surface.DrawLine(x + w, y + h, x + w - s, y + h)
	surface.DrawLine(x + w, y + h, x + w, y + h - s)
end

local function drawPanel(mode, energy, ct)
	local th = getTheme()
	if not th then return end
	local low = energy <= 20
	local blink = math.sin(ct * 8) > 0

	local pw, ph = 400, 110
	local chamf = 12
	local px = ScrW() - pw - 48
	local py = ScrH() - 170

	local c = {
		{x = px, y = py},
		{x = px + pw, y = py},
		{x = px + pw, y = py + ph},
		{x = px, y = py + ph},
	}
	local poly = chamfer(c, chamf)

	draw.NoTexture()
	surface.SetDrawColor(th.BG)
	surface.DrawPoly(poly)
	drawOutline(poly, th.Accent)

	local margin = 14
	local barH = 56
	local barTop = py + (ph - barH) / 2
	local barBot = barTop + barH
	local lt = px + margin
	local segs = 20
	local gap = 4
	local barWidth = pw - margin * 2
	local segSpan = (barWidth - gap * (segs - 1)) / segs
	local filled = math.floor(math.Clamp(energy / NS.MaxEnergy, 0, 1) * segs + 0.001)

	draw.NoTexture()
	for i = 0, segs - 1 do
		local xTL = lt + i * (segSpan + gap)
		local xTR = xTL + segSpan
		if i < filled then
			drawQuad(xTL, barTop, xTR, barTop, xTR, barBot, xTL, barBot, low and blink and RED or th.SegOn)
		else
			drawQuad(xTL, barTop, xTR, barTop, xTR, barBot, xTL, barBot, th.Seg)
		end
	end

	local lstr = "ENERGY"
	local midY = (barTop + barBot) / 2
	local cx = px + pw / 2

	surface.SetFont("NanoSuit_Label")
	local lw, lh = surface.GetTextSize(lstr)
	local tx = cx - lw / 2
	local ty = midY - lh / 2

	surface.SetTextColor(th.Label)
	surface.SetTextPos(tx, ty)
	surface.DrawText(lstr)
end

local function helmpath(pts, col)
	surface.SetDrawColor(col)
	for i = 1, #pts - 1 do
		surface.DrawLine(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2])
	end
end

local function drawHelmet()
	local th = getTheme()
	if not th then return end
	local w, h = ScrW(), ScrH()
	local m = math.Round(w * 0.022)
	local inset = math.Round(w * 0.07)
	local cut = math.Round(h * 0.02)
	local y = math.Round(h * 0.032)
	local tick = math.Round(w * 0.012)

	helmpath({
		{m, y + cut}, {m, y}, {m + tick, y}, {m + tick + 8, y - 7}, {inset, y - 7},
		{inset + 10, y}, {w / 2 - 70, y}, {w / 2 - 54, y + 10}, {w / 2 + 54, y + 10}, {w / 2 + 70, y},
		{w - inset - 10, y}, {w - inset, y - 7}, {w - m - tick - 8, y - 7}, {w - m - tick, y}, {w - m, y}, {w - m, y + cut},
	}, th.Helm)

	local yb = h - y
	helmpath({
		{m, yb - cut}, {m, yb}, {m + tick, yb}, {m + tick + 8, yb + 7}, {inset, yb + 7},
		{inset + 10, yb}, {w / 2 - 70, yb}, {w / 2 - 54, yb - 10}, {w / 2 + 54, yb - 10}, {w / 2 + 70, yb},
		{w - inset - 10, yb}, {w - inset, yb + 7}, {w - m - tick - 8, yb + 7}, {w - m - tick, yb}, {w - m, yb}, {w - m, yb - cut},
	}, th.Helm)

	surface.SetDrawColor(th.HelmDim)
	surface.DrawLine(inset + 12, y - 7, w / 2 - 72, y - 7)
	surface.DrawLine(w / 2 + 72, y - 7, w - inset - 12, y - 7)
	surface.DrawLine(inset + 12, yb + 7, w / 2 - 72, yb + 7)
	surface.DrawLine(w / 2 + 72, yb + 7, w - inset - 12, yb + 7)
end

hook.Add("HUDPaint", "NanoSuitHUD", function()
	if not getNS() then return end
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	if not ply:GetNetVar("NS_Has", false) then return end

	local mode = ply:GetLocalVar("NS_Mode", ply:GetNetVar("NS_Mode", 0))
	local energy = ply:GetLocalVar("NS_Energy", NS.MaxEnergy)
	local ct = CurTime()

	drawHelmet()
	drawPanel(mode, energy, ct)
end)

hook.Add("radialOptions", "NanoSuit", function()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then return end
	if not lp:GetNetVar("NS_Has", false) then return end
	if not hg.radialOptions then hg.radialOptions = {} end
	hg.radialOptions[#hg.radialOptions + 1] = {function() sendMode(1) end, "Armor"}
	hg.radialOptions[#hg.radialOptions + 1] = {function() sendMode(2) end, "Cloak"}
	hg.radialOptions[#hg.radialOptions + 1] = {function() sendMode(3) end, "Speed"}
end)

local visState = {}
local nextVisualCheck = 0
local modeRamp = {}
local rampState = {}
local rampStepVal = {}
local rampStepEnt = {}

local stateMaps = {}
local suffixes = {
	cloak = "_cloak",
	armor = "_armor",
	run = "_run",
	speed = "_run",
	dmg = "_damaged",
}
local parts = {"body", "arms", "legs", "helmet"}

local function getMap(state)
	if stateMaps[state] then return stateMaps[state] end
	local suf = suffixes[state]
	if state == "cloak" then suf = "_cloak" end
	if not suf then return nil end
	local dir = hg.NanoSuit.MatDir
	local m = {}
	local duf = suf == "_damaged" and "" or "_damaged"
	for _, p in ipairs(parts) do
		m[dir .. p] = dir .. p .. suf
		m[dir .. p .. "_damaged"] = dir .. p .. duf .. suf
	end
	stateMaps[state] = m
	return m
end

local function applyVisual(ent, state)
	local map = getMap(state)
	for i, m in ipairs(ent:GetMaterials()) do
		if map and map[m] then
			ent:SetSubMaterial(i - 1, map[m])
		else
			ent:SetSubMaterial(i - 1, nil)
		end
	end
end

local function getState(ply)
	local mode = ply:GetLocalVar("NS_Mode", ply:GetNetVar("NS_Mode", 0))
	if mode == 2 then return "cloak" end
	if mode == 1 then return "armor" end
	if mode == 3 then return "speed" end
	if ply:Health() <= 40 then return "dmg" end
	return "none"
end

local stepSuffixes = {
	armor = "_armor",
	speed = "_run",
}
local stepMaps = {}
local function getStepMap(state, step)
	local suf = stepSuffixes[state]
	if not suf then return nil end
	local key = state .. "_" .. step
	if stepMaps[key] then return stepMaps[key] end
	local dir = NS.MatDir
	local m = {}
	for _, p in ipairs(parts) do
		local sfx = step >= 10 and suf or (suf .. step)
		m[dir .. p] = dir .. p .. sfx
		m[dir .. p .. "_damaged"] = dir .. p .. "_damaged" .. sfx
	end
	stepMaps[key] = m
	return m
end

local function applyStep(ent, state, step)
	local map = getStepMap(state, step)
	if not map then return end
	for i, m in ipairs(ent:GetMaterials()) do
		if map[m] then
			ent:SetSubMaterial(i - 1, map[m])
		end
	end
end

local function rampFade(state, isIn)
	if state == "speed" then return isIn and NS.SpeedGlowFadeIn or NS.SpeedGlowFadeOut end
	return isIn and NS.ArmorGlowFadeIn or NS.ArmorGlowFadeOut
end

hook.Add("Think", "NanoSuitModeRamp", function()
	if not getNS() then return end
	local dt = FrameTime()
	local seen = {}
	for _, ply in ipairs(player.GetAll()) do
		if not ply:GetNetVar("NS_Has", false) then continue end
		local mode = ply:GetLocalVar("NS_Mode", ply:GetNetVar("NS_Mode", 0))
		local want = mode == 1 and "armor" or mode == 3 and "speed" or nil
		local st = rampState[ply]
		local r = modeRamp[ply]
		if r == nil then
			if not want then continue end
			st = want
			r = 0
		elseif want and want != st then
			st = want
			r = 0
			rampStepVal[ply] = nil
			rampStepEnt[ply] = nil
		end
		local fade = rampFade(st, want != nil)
		local target = want and 1 or 0
		if r < target then
			r = math.min(target, r + dt / fade)
		elseif r > target then
			r = math.max(target, r - dt / fade)
		end
		rampState[ply] = st
		modeRamp[ply] = r

		local ent = ply
		if hg.GetCurrentCharacter then
			local char = hg.GetCurrentCharacter(ply)
			if IsValid(char) then ent = char end
		end
		if not IsValid(ent) or not NS.IsSuitModel(ent:GetModel()) then continue end
		seen[ply] = true

		if not want and r <= 0 then
			modeRamp[ply] = nil
			rampState[ply] = nil
			rampStepVal[ply] = nil
			rampStepEnt[ply] = nil
			applyVisual(ent, getState(ply))
			continue
		end

		local step = math.ceil(r * 10)
		if step < 1 then step = 1 end
		if rampStepVal[ply] != step or rampStepEnt[ply] != ent then
			rampStepVal[ply] = step
			rampStepEnt[ply] = ent
			applyStep(ent, st, step)
		end
	end
	for ply in pairs(modeRamp) do
		if not seen[ply] then
			modeRamp[ply] = nil
			rampState[ply] = nil
			rampStepVal[ply] = nil
			rampStepEnt[ply] = nil
		end
	end
end)

hook.Add("Think", "NanoSuitVisual", function()
	local ct = CurTime()
	if ct < nextVisualCheck then return end
	if not getNS() then return end
	nextVisualCheck = ct + 0.2
	local seen = {}
	for _, ply in ipairs(player.GetAll()) do
		if not ply:GetNetVar("NS_Has", false) then continue end
		local ent = ply
		if hg.GetCurrentCharacter then
			local char = hg.GetCurrentCharacter(ply)
			if IsValid(char) then ent = char end
		end
		if not IsValid(ent) or not NS.IsSuitModel(ent:GetModel()) then continue end
		seen[ent] = true
		local state = getState(ply)
		if visState[ent] != state then
			visState[ent] = state
			local r = modeRamp[ply]
			if state == "cloak" then
				applyVisual(ent, "cloak")
			elseif state == "armor" or state == "speed" then
			elseif r != nil and r > 0 then
			else
				applyVisual(ent, state)
			end
		end
	end
	for ent in pairs(visState) do
		if not IsValid(ent) or not seen[ent] then
			if IsValid(ent) then applyVisual(ent, "none") end
			visState[ent] = nil
		end
	end
end)

local cloakAlpha = {}
local cloakCol = Color(255, 255, 255, 255)

local function cloakEnts(ply)
	local t = {ply}
	if hg.GetCurrentCharacter then
		local char = hg.GetCurrentCharacter(ply)
		if IsValid(char) and char != ply then t[#t + 1] = char end
	end
	if IsValid(ply.FakeRagdoll) and ply.FakeRagdoll != ply then t[#t + 1] = ply.FakeRagdoll end
	return t
end

local function isCloaked(ply)
	if ply:GetNetVar("NS_Stealth", false) then return true end
	return ply:GetLocalVar("NS_Mode", ply:GetNetVar("NS_Mode", 0)) == 2
end

local function applyCloakEnt(ent)
	if ent:GetMaterial() != "" then
		ent:SetMaterial("")
	end
	ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
end

local function resetCloakEnt(ent)
	ent:SetRenderMode(RENDERMODE_NORMAL)
	ent:SetColor(color_white)
end

hook.Add("PreDrawOpaqueRenderables", "NanoSuitCloak", function()
	if not getNS() then return end
	local dt = FrameTime()
	local seen = {}
	for _, ply in ipairs(player.GetAll()) do
		if not ply:GetNetVar("NS_Has", false) then continue end
		local stealth = isCloaked(ply)
		local cur = cloakAlpha[ply]
		if not stealth and (cur == nil or cur >= 255) then continue end
		local target = stealth and NS.CloakRefractAlpha or 255
		cur = cur or 255
		local fade = stealth and NS.CloakFadeIn or NS.CloakFadeOut
		local step = dt / fade * 255
		if cur < target then
			cur = math.min(target, cur + step)
		else
			cur = math.max(target, cur - step)
		end
		cloakAlpha[ply] = cur
		seen[ply] = true
		local a = math.floor(cur)
		if a >= 254 then
			for _, ent in ipairs(cloakEnts(ply)) do
				if IsValid(ent) then resetCloakEnt(ent) end
			end
		else
			cloakCol.r, cloakCol.g, cloakCol.b, cloakCol.a = 255, 255, 255, a
			for _, ent in ipairs(cloakEnts(ply)) do
				if not IsValid(ent) then continue end
				applyCloakEnt(ent)
				ent:SetColor(cloakCol)
			end
		end
	end
	for ply in pairs(cloakAlpha) do
		if not seen[ply] then
			if IsValid(ply) then
				for _, ent in ipairs(cloakEnts(ply)) do
					if IsValid(ent) then resetCloakEnt(ent) end
				end
			end
			cloakAlpha[ply] = nil
		end
	end
end)

hook.Add("CoolPostDrawAppearance", "NanoSuitCloakDraw", function(ent, ply)
	if not getNS() then return end
	if not IsValid(ent) or not IsValid(ply) then return end
	if not ply:GetNetVar("NS_Has", false) then return end
	local cur = cloakAlpha[ply]
	if cur == nil then return end
	if not isCloaked(ply) and cur >= 254 then return end
	local a = math.floor(cur)
	if a >= 254 then
		resetCloakEnt(ent)
		return
	end
	cloakCol.r, cloakCol.g, cloakCol.b, cloakCol.a = 255, 255, 255, a
	applyCloakEnt(ent)
	ent:SetColor(cloakCol)
end)

net.Receive("NanoSuit_ModeSnd", function()
	local mode = net.ReadUInt(3)
	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	if mode == 1 then
		lp:EmitSound("sounds/armormax.mp3")
	elseif mode == 2 then
		lp:EmitSound("sounds/maskirovkaon.mp3")
	end
end)

net.Receive("NanoSuit_WakeSnd", function()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	lp:EmitSound("sounds/reloadsuit.wav")
end)

