local smoke_mats = {}
for i = 1, 16 do
	smoke_mats[i] = Material("particle/smokesprites_" .. string.format("%04d", i))
end

local math_min = math.min
local math_random = math.random
local math_Rand = math.Rand
local CurTime = CurTime
local FrameTime = FrameTime
local render_SetMaterial = render.SetMaterial
local render_DrawSprite = render.DrawSprite
local table_remove = table.remove

net.Receive("co_gas_vis", function()
	local count = net.ReadUInt(8)
	local list = {}
	for i = 1, count do
		list[i] = {net.ReadVector(), net.ReadUInt(8) / 100}
	end
	hg.COin = list
end)

hook.Add("PostCleanupMap", "co_gas_client_cleanup", function()
	hg.COin = nil
	hg.COvis = {}
end)

local nextSync = 0

hook.Add("Think", "co_gas_sync", function()
	if not hg.COin then return end
	if not hg.COvis then hg.COvis = {} end
	if nextSync > CurTime() then return end
	nextSync = CurTime() + 0.15

	local fresh = hg.COin
	hg.COin = nil

	local vis = hg.COvis
	local claimed = {}
	for i = #vis, 1, -1 do
		local vp = vis[i]
		local bestD, bestJ = 250 * 250, nil

		for j = 1, #fresh do
			if not claimed[j] then
				local d = vp.pos:DistToSqr(fresh[j][1])
				if d < bestD then
					bestD = d
					bestJ = j
				end
			end
		end

		if bestJ then
			claimed[bestJ] = true
			local f = fresh[bestJ]
			vp.topos:Set(f[1])
			vp.toInt = f[2]
			vp.skyDone = false
		else
			vp.toInt = 0

			if not vp.skyDone then
				vp.skyDone = true

				local str = util.TraceLine({
					start = vp.pos,
					endpos = vp.pos + Vector(0, 0, 2400),
					mask = MASK_SOLID_BRUSHONLY
				})

				if str.HitSky or not str.Hit then
					table_remove(vis, i)
					continue
				end
			end
		end
	end

	for j = 1, #fresh do
		if not claimed[j] then
			local f = fresh[j]
			local pos = Vector(f[1].x, f[1].y, f[1].z)
			vis[#vis + 1] = {
				pos = pos,
				pos2 = Vector(pos.x, pos.y, pos.z),
				topos = Vector(pos.x, pos.y, pos.z),
				inten = 0,
				toInt = f[2],
				seed = math_Rand(0, 100),
				size = math_Rand(90, 150),
				mat = smoke_mats[math_random(#smoke_mats)],
				col = Color(155, 148, 140, 0),
				col2 = Color(118, 104, 92, 0)
			}
		end
	end
end)

hook.Add("PostDrawTranslucentRenderables", "co_gas_render", function(isDepth, isSkybox)
	if isSkybox then return end

	local vis = hg.COvis
	if not vis or #vis == 0 then return end

	local eye = EyePos()
	local now = CurTime()
	local ft = FrameTime()
	local kPos = math_min(ft * 4, 1)
	local kInt = math_min(ft * 6, 1)
	local eyeLimit = 3500 * 3500

	for i = #vis, 1, -1 do
		local vp = vis[i]
		vp.inten = vp.inten + (vp.toInt - vp.inten) * kInt

		if vp.inten < 0.02 and vp.toInt == 0 then
			table_remove(vis, i)
			continue
		end

		local pos = vp.pos
		local topos = vp.topos
		pos.x = pos.x + (topos.x - pos.x) * kPos
		pos.y = pos.y + (topos.y - pos.y) * kPos
		pos.z = pos.z + (topos.z - pos.z) * kPos

		if vp.inten <= 0.03 or pos:DistToSqr(eye) > eyeLimit then continue end

		local pos2 = vp.pos2
		pos2.x = pos.x
		pos2.y = pos.y
		pos2.z = pos.z - vp.size * 0.35

		local size = vp.size * (0.85 + 0.25 * math.sin(now * 0.9 + vp.seed))
		local alpha = vp.inten * 110

		vp.col.a = alpha
		vp.col2.a = alpha * 0.7

		render_SetMaterial(vp.mat)
		render_DrawSprite(pos, size * 1.7, size * 1.7, vp.col)
		render_DrawSprite(pos2, size, size, vp.col2)
	end
end)
