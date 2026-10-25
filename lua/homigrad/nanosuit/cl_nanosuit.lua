local NS

local function getNS()
	NS = hg.NanoSuit
	return NS
end

local fonts = {
	{name = "NanoSuit_3D_Mode", font = "Apercu Mono", size = 40, weight = 600},
	{name = "NanoSuit_3D_Tiny", font = "Apercu Mono", size = 22, weight = 500},
}

local function createFonts()
	for _, f in ipairs(fonts) do
		surface.CreateFont(f.name, {font = f.font, size = f.size, weight = f.weight, extended = true, antialias = true})
	end
end

createFonts()
hook.Add("InitPostEntity", "NanoSuitFonts", createFonts)

local RED = Color(255, 70, 55, 255)

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

local suit3dAlpha = 0
local armorA = 0
local hexSpotI, hexLen, hexSpotT, hexSpotNext = 0, 0, 0, 0
local hexSpotI2, hexLen2, hexSpotT2, hexSpotNext2 = 0, 0, 0, 0.7
local lagYaw, lagPitch = 0, 0
local yawShiftSm = 0
local prevYaw, yawVelSm = 0, 0
local prevPitch, pitchVelSm = 0, 0
local disp3dEnergy
local lastMode, modeFlashTime = 0, 0
local glitchT, glitchX, glitchY = 0, 0, 0

local function colMul(c, m)
	return Color(c.r, c.g, c.b, c.a / 255 * m)
end

local function drawViewPanel(eye, eyeAng, offRight, offUp, dist, scale, roll, func)
	local pos = eye + eyeAng:Forward() * dist + eyeAng:Right() * offRight + eyeAng:Up() * offUp
	local ang = Angle(eyeAng.p, eyeAng.y, eyeAng.r)
	ang:RotateAroundAxis(ang:Up(), -90)
	ang:RotateAroundAxis(ang:Forward(), 90)
	ang:RotateAroundAxis(ang:Up(), roll)

	cam.Start3D2D(pos, ang, scale)
		func()
	cam.End3D2D()
end

local function buildHexSpots(sw, sh)
	local r = sw * 0.0165
	local vr = r * 0.866
	local spots = {}

	local function add(x, y)
		spots[#spots + 1] = {x = x, y = y}
	end

	local colsW = math.ceil(sw / (1.5 * r)) + 2
	local y0 = sh + 0.5 * r
	for j = 0, colsW do
		local x = j * 1.5 * r - r * 0.2
		local off = (j % 2) * vr
		add(x, y0 - off)
		add(x, y0 - off - 2 * vr)
	end

	local yStart = r * 3.8
	local yEnd = sh - r * 4.8
	local colsH = math.max(math.ceil((yEnd - yStart) / (2 * vr)), 0)
	for k = colsH, 1, -1 do
		local y = yStart + (k - 1) * 2 * vr
		add(sw - r * 0.45, y)
		add(sw - r * 0.45 - 1.5 * r, y + vr)
	end

	for j = colsW, 0, -1 do
		local x = j * 1.5 * r - r * 0.2
		local off = (j % 2) * vr
		add(x, -r * 0.5 + off)
		add(x, -r * 0.5 + off + 2 * vr)
	end

	for k = 1, colsH do
		local y = yStart + (k - 1) * 2 * vr
		add(r * 0.45, y)
		add(r * 0.45 + 1.5 * r, y + vr)
	end

	return spots
end

local function drawArmorHexes(a, ct, th, s1, l1, t1, s2, l2, t2)
	local sw, sh = ScrW(), ScrH()
	local spots, r = buildHexSpots(sw, sh), sw * 0.0165
	local n = #spots

	local function hexAt(cx, cy)
		local pts = {}
		for k = 0, 5 do
			local ang = math.pi / 3 * k
			pts[#pts + 1] = {x = cx + r * math.cos(ang), y = cy + r * math.sin(ang), u = 0, v = 0}
		end
		return pts
	end

	draw.NoTexture()
	for i, s in ipairs(spots) do
		local env = 0

		local d = (i - 1 - s1 + n) % n
		if d < l1 then
			local t = ct - t1
			local onT = d * 0.03
			local offT = 0.9 + (l1 - d) * 0.025
			env = env + math.Clamp((t - onT) / 0.12, 0, 1) * math.Clamp((offT + 0.5 - t) / 0.5, 0, 1)
		end

		if s2 >= 0 then
			local d2 = (i - 1 - s2 + n) % n
			if d2 < l2 then
				local t = ct - t2
				local onT = d2 * 0.03
				local offT = 0.9 + (l2 - d2) * 0.025
				env = env + math.Clamp((t - onT) / 0.12, 0, 1) * math.Clamp((offT + 0.5 - t) / 0.5, 0, 1)
			end
		end

		env = math.min(env, 1)
		if a > 0.01 then
			local ch = 0.5 + 0.5 * math.sin(ct * 0.7 + i * 2.7)
			local glow = ch > 0.55 and (ch - 0.55) / 0.45 or 0
			local p = (math.sin(ct * 1.8 - i * 0.4) + 1) / 2
			local hex = hexAt(s.x, s.y)

			local oA = math.min((78 + p * 32 + (130 + p * 65) * env) * a, 255)
			if oA > 1 then
				local fA = (6 + 10 * env + (16 + glow * 45) * glow) * a
				if fA > 1 then
					if glow > 0.01 then
						surface.SetDrawColor(colMul(th.SegOn, fA))
					else
						surface.SetDrawColor(colMul(th.Seg, fA))
					end
					surface.DrawPoly(hex)
				end

				drawOutline(hex, colMul(th.Accent, oA))
				if glow > 0.01 then
					drawOutline(hexAt(s.x + 1, s.y + 1), colMul(th.Helm, 130 * glow * a))
				end
			end
		end
	end
end

local NSView = {origin = Vector(0, 0, 0), angles = Angle(0, 0, 0)}

hook.Add("PostHGCalcView", "NanoSuitView", function(ply, view)
	if not istable(view) or not isvector(view.origin) then return end
	NSView.origin:Set(view.origin)
	NSView.angles:Set(view.angles)
	NSView.time = CurTime()
end)

hook.Add("PostPostHGCalcView", "NanoSuitView2", function(ply, view)
	if not istable(view) or not isvector(view.origin) then return end
	NSView.origin:Set(view.origin)
	NSView.angles:Set(view.angles)
	NSView.time = CurTime()
end)

hook.Add("Think", "NanoSuit3DState", function()
	local ply = LocalPlayer()
	local ft = math.min(FrameTime() * 6, 1)
	local valid = IsValid(ply) and ply:Alive() and ply:GetNetVar("NS_Has", false) and ply == ply:GetViewEntity()

	local mode = valid and ply:GetLocalVar("NS_Mode", 0) or 0
	if mode != lastMode then
		lastMode = mode
		modeFlashTime = CurTime()
	end

	local target = valid and 1 or 0
	suit3dAlpha = suit3dAlpha + (target - suit3dAlpha) * ft

	local armorT = valid and mode == 1 and 1 or 0
	armorA = armorA + (armorT - armorA) * math.min(FrameTime() * (armorT == 1 and 2.5 or 6), 1)
	if armorT ~= 1 and armorA < 0.02 then
		armorA = 0
	end

	local ctN = CurTime()
	local ring = #buildHexSpots(ScrW(), ScrH())
	if ring < 1 then ring = 1 end

	if armorT == 1 and armorA > 0.15 then
		if ctN >= hexSpotNext then
			hexSpotI = math.random(0, ring - 1)
			hexLen = math.random(9, 16)
			hexSpotT = ctN
			hexSpotNext = ctN + math.Rand(1.4, 2.6)
		end
		if ctN >= hexSpotNext2 then
			hexSpotI2 = math.random(0, ring - 1)
			hexLen2 = math.random(6, 12)
			hexSpotT2 = ctN
			hexSpotNext2 = ctN + math.Rand(1.6, 3)
		end
	elseif armorT ~= 1 then
		hexSpotNext = 0
		hexSpotNext2 = 0
	end

	local energy = valid and ply:GetLocalVar("NS_Energy", NS.MaxEnergy) or NS.MaxEnergy
	disp3dEnergy = disp3dEnergy and disp3dEnergy + (energy - disp3dEnergy) * ft or energy

	local eye
	if valid then
		eye = CurTime() - (NSView.time or -99) < 0.02 and NSView.angles or ply:EyeAngles()
	else
		eye = NSView.angles
	end
	local dt = math.max(FrameTime(), 0.001)
	local ftLag = math.min(FrameTime() * 2.5, 1)
	lagYaw = lagYaw + math.AngleDifference(eye.yaw, lagYaw) * ftLag
	lagPitch = lagPitch + math.AngleDifference(eye.pitch, lagPitch) * ftLag

	local yawShiftT = -math.Clamp(math.AngleDifference(eye.yaw, lagYaw), -16, 16) * 0.26
	yawShiftSm = yawShiftSm and yawShiftSm + (yawShiftT - yawShiftSm) * math.min(FrameTime() * 3.5, 1) or yawShiftT

	local ftVel = math.min(FrameTime() * 10, 1)
	local instYawVel = math.AngleDifference(eye.yaw, prevYaw) / dt
	local instPitchVel = math.AngleDifference(eye.pitch, prevPitch) / dt
	prevYaw, prevPitch = eye.yaw, eye.pitch
	yawVelSm = yawVelSm + (instYawVel - yawVelSm) * ftVel
	pitchVelSm = pitchVelSm + (instPitchVel - pitchVelSm) * ftVel

	if disp3dEnergy <= 15 and CurTime() >= glitchT then
		glitchT = CurTime() + 0.05
		glitchX = (math.random(2) == 1 and -1 or 1) * math.Rand(0.48, 1.2)
		glitchY = (math.random(2) == 1 and -1 or 1) * math.Rand(0.24, 0.72)
	end
end)

hook.Add("Post Post Pre Post Processing", "NanoSuit3DHud", function()
	if not getNS() or suit3dAlpha < 0.015 then return end

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local mode = lastMode
	local freshCam = CurTime() - (NSView.time or -99) < 0.02
	local eye, ea = freshCam and NSView.origin or ply:EyePos(), freshCam and NSView.angles or ply:EyeAngles()
	local fov = render.GetViewSetup(true).fov or 90
	local a3d = suit3dAlpha
	local energy = disp3dEnergy or NS.MaxEnergy

	local ct = CurTime()
	local speed = ply:GetVelocity():Length()
	local ctl = ea
	local yawOff = math.AngleDifference(ctl.yaw, lagYaw)
	local punch = GetViewPunchAngles()
	local roll = math.Clamp(yawVelSm * 0.012 + yawOff * 0.2 + punch.p * 0.4 + pitchVelSm * 0.006, -6, 6)
	roll = roll + math.sin(ct * 1.3) * 0.18 + math.sin(ct * 2.1) * 0.09
	roll = roll + math.sin(ct * 9 + ply:EntIndex()) * math.min(speed / 300, 1) * 0.35

	local gx, gy = 0, 0
	if energy <= 15 then gx, gy = glitchX, glitchY end

	local th = NS.GetTheme(ply)
	local low = energy <= 20
	local blink = math.sin(ct * 8) > 0
	local fill = (low and blink) and colMul(RED, 255 * a3d) or colMul(th.SegOn, 255 * a3d)

	local yawShift = yawShiftSm or 0
	render.OverrideDepthEnable(true, false)
	render.ClearDepth()
	render.SetStencilEnable(false)
	cam.Start3D(eye, ea, fov, 0, 0, ScrW(), ScrH())

	drawViewPanel(eye, ea, 37 + gx + yawShift, -23.5 - lagPitch * 0.08 + punch.p * 0.35 + gy * 0.5, 36, 0.072, roll, function()
		local w, h = 380, 104
		local poly = chamfer({
			{x = -w / 2, y = -h / 2},
			{x = w / 2, y = -h / 2},
			{x = w / 2, y = h / 2},
			{x = -w / 2, y = h / 2},
		}, 10)

		draw.NoTexture()
		surface.SetDrawColor(th.BG.r, th.BG.g, th.BG.b, 240 * a3d)
		surface.DrawPoly(poly)
		drawOutline(poly, (low and blink) and colMul(RED, 200 * a3d) or colMul(th.Accent, 190 * a3d))

		local lt = -w / 2 + 20
		local barSpan = w - 40
		local barTop, barH = -34, 30
		local segs, segGap = 24, 2
		local segSpan = (barSpan - (segs - 1) * segGap) / segs
		local filled = math.floor(math.Clamp(disp3dEnergy / NS.MaxEnergy, 0, 1) * segs + 0.001)
		local empty = colMul(th.Seg, 120 * a3d)

		draw.NoTexture()
		for i = 0, segs - 1 do
			local xTL = lt + i * (segSpan + segGap)
			local xTR = xTL + segSpan
			drawQuad(xTL, barTop, xTR, barTop, xTR, barTop + barH, xTL, barTop + barH, i < filled and fill or empty)
		end

		local energyCol = Color(0, 0, 0, 255 * a3d)

		draw.SimpleText("E N E R G Y", "NanoSuit_3D_Tiny", 0, barTop + barH / 2, energyCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local tileH = 30
		local tileW = (barSpan - 16) / 3
		local tileTop = 6
		for i = 1, 3 do
			local mt = NS.Modes[i]
			local x0 = lt + (i - 1) * (tileW + 8)
			local isActive = mode == i
			local tile = chamfer({
				{x = x0, y = tileTop},
				{x = x0 + tileW, y = tileTop},
				{x = x0 + tileW, y = tileTop + tileH},
				{x = x0, y = tileTop + tileH},
			}, 3)

			if isActive then
				draw.NoTexture()
				surface.SetDrawColor(colMul(th.Accent, 215 * a3d))
				surface.DrawPoly(tile)
				drawOutline(tile, colMul(th.Accent, 255 * a3d))
				draw.SimpleText(mt.Name, "NanoSuit_3D_Tiny", x0 + tileW / 2 + 1, tileTop + tileH / 2 + 1, Color(0, 0, 0, 70 * a3d), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(mt.Name, "NanoSuit_3D_Tiny", x0 + tileW / 2, tileTop + tileH / 2, colMul(th.BG, 255 * a3d), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			else
				drawOutline(tile, Color(135, 140, 146, 80 * a3d))
				draw.SimpleText(mt.Name, "NanoSuit_3D_Tiny", x0 + tileW / 2, tileTop + tileH / 2, Color(135, 140, 146, 120 * a3d), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	end)

	cam.End3D()
	if armorA > 0.01 then
		drawArmorHexes(armorA, ct, th, hexSpotI, hexLen, hexSpotT, hexSpotI2, hexLen2, hexSpotT2)
	end
	render.OverrideDepthEnable(false, false)
end)

hook.Add("radialOptions", "NanoSuit", function()
	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then return end
	if not lp:GetNetVar("NS_Has", false) then return end
	if not hg.radialOptions then hg.radialOptions = {} end

	local th = NS.GetTheme(lp)

	hg.radialOptions[#hg.radialOptions + 1] = {function() sendMode(1) end, "Armor", nil, nil, nil, th.BG, th.Accent}
	hg.radialOptions[#hg.radialOptions + 1] = {function() sendMode(2) end, "Cloak", nil, nil, nil, th.BG, th.Accent}
	hg.radialOptions[#hg.radialOptions + 1] = {function() sendMode(3) end, "Speed", nil, nil, nil, th.BG, th.Accent}
end)

local visState = {}
local nextVisualCheck = 0
local modeRamp = {}
local rampState = {}
local rampStepVal = {}
local rampStepEnt = {}

local suffixes = {
	cloak = "_cloak",
	armor = "_armor",
	run = "_run",
	speed = "_run",
	dmg = "_damaged",
}
local parts = {"body", "arms", "legs", "helmet"}
local matDir = "models/vuthakral/crysis/characters/nanosuit/"

local matExists = {}

local function matOK(mat)
	local known = matExists[mat]
	if known == nil then
		known = file.Exists("materials/" .. mat .. ".vmt", "GAME")
		matExists[mat] = known
	end
	return known
end

local matSlots = {}

local function getSlots(ent)
	local key = ent:GetModel()
	if key and matSlots[key] then return matSlots[key] end

	local materials = ent:GetMaterials()
	if not key or #materials == 0 then return {} end

	local t = {}
	for i, m in ipairs(materials) do
		local base = string.lower(string.match(m, "[/\\]([^/\\]+)$") or "")
		for _, p in ipairs(parts) do
			if base == p or base == p .. "_nano" or base == p .. "_damaged" or base == p .. "_nano_damaged" then
				t[i] = p
				break
			end
		end
	end
	matSlots[key] = t
	return t
end

local function isKorea(ent)
	return ent:GetModel() == NS.ModelKorea
end

local koreaTex = {
	body = {base = "body_damaged", bump = "body_n", exp = "body_e", glow = "body_nano"},
	arms = {base = "arms_damaged", bump = "arms_n", exp = "arms_e", glow = "arms_nano"},
	legs = {base = "helmet_e", bump = "legs_n", exp = "legs_e", glow = "legs_nano"},
	helmet = {base = "helmet_damaged", bump = "helmet_damaged_n", exp = "helmet_damaged_e", glow = "helmet_damaged_nano"},
}

local koreaTints = {
	armor = "[ 0 0.4 1 ]",
	cloak = "[ 1 1 1 ]",
	speed = "[ 1 0.85 0 ]",
}

local koreaStrength = {
	armor = 1.5,
	cloak = 0.7,
	speed = 1,
}

local koreaMats = {}

local function koreaMat(state, p)
	local key = state .. "_" .. p
	if koreaMats[key] ~= nil then
		return koreaMats[key] and ("!ns_kna_" .. key) or nil
	end
	local t = koreaTex[p]
	local tint = koreaTints[state]
	if not t or not tint then
		koreaMats[key] = false
		return nil
	end
	local name = "ns_kna_" .. key
	CreateMaterial(name, "VertexLitGeneric", {
		["$basetexture"] = matDir .. t.base,
		["$bumpmap"] = matDir .. t.bump,
		["$phong"] = 1,
		["$phongdisablehalflambert"] = 1,
		["$phongboost"] = 1.77,
		["$phongexponenttexture"] = matDir .. t.exp,
		["$phongalbedotint"] = 1,
		["$phongalbedoboost"] = 33,
		["$phongfresnelranges"] = "[ 0.3 1 1 ]",
		["$color2"] = "[ .7 .7 .7 ]",
		["$rimlight"] = 1,
		["$rimmask"] = 1,
		["$model"] = 1,
		["$emissiveBlendEnabled"] = 1,
		["$emissiveBlendTexture"] = "models/vuthakral/shield_arcs",
		["$emissiveBlendBaseTexture"] = matDir .. t.glow,
		["$emissiveBlendFlowTexture"] = "models/vuthakral/shield_flow",
		["$emissiveBlendTint"] = tint,
		["$emissiveBlendStrength"] = koreaStrength[state] or 1,
		["$emissiveBlendScrollVector"] = "[ .5 .5 ]",
	})
	koreaMats[key] = true
	return "!" .. name
end

local function applyVisual(ent, state)
	local suf = suffixes[state]
	local materials = ent:GetMaterials()
	for i, p in pairs(getSlots(ent)) do
		local mat
		if isKorea(ent) then
			if suf and (state == "armor" or state == "speed" or state == "cloak") then
				mat = koreaMat(state, p) or materials[i]
			else
				mat = materials[i]
			end
		else
			mat = suf and matDir .. p .. suf or materials[i]
			if suffixes[state] != nil and not matOK(mat) then mat = materials[i] end
		end
		if mat ~= ent:GetSubMaterial(i - 1) then
			ent:SetSubMaterial(i - 1, mat)
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

local function applyStep(ent, state, step)
	local suf = stepSuffixes[state]
	if not suf then return end
	local materials = ent:GetMaterials()
	if isKorea(ent) then
		for i, p in pairs(getSlots(ent)) do
			local mat = koreaMat(state, p) or materials[i]
			if mat ~= ent:GetSubMaterial(i - 1) then
				ent:SetSubMaterial(i - 1, mat)
			end
		end
		return
	end
	local tail = step >= 10 and suf or suf .. step
	for i, p in pairs(getSlots(ent)) do
		local mat = matDir .. p .. tail
		if mat != materials[i] and matOK(mat) then
			ent:SetSubMaterial(i - 1, mat)
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

