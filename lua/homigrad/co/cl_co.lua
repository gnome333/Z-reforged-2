local smoke_mats = {}
for i = 1, 16 do
	smoke_mats[i] = Material("particle/smokesprites_" .. string.format("%04d", i))
end

local math_min = math.min
local math_floor = math.floor
local math_sin = math.sin
local math_random = math.random
local math_Rand = math.Rand
local CurTime = CurTime
local FrameTime = FrameTime
local render_SetMaterial = render.SetMaterial
local render_DrawSprite = render.DrawSprite
local table_remove = table.remove

net.Receive("co_gas_vis", function()
	local count = net.ReadUInt(16)
	local list = {}
	for i = 1, count do
		list[i] = { net.ReadVector(), net.ReadUInt(8) / 100 }
	end
	hg.COin = list
end)

hook.Add("PostCleanupMap", "co_gas_client_cleanup", function()
	hg.COin = nil
	hg.COvis = {}
end)

local nextSync = 0

local cell = 700
local grid = {}
local gridKeys = 0
local usedBuckets = {}
local claimed = {}

local function clearClaimed()
	for k in pairs(claimed) do
		claimed[k] = nil
	end
end

hook.Add("Think", "co_gas_sync", function()
	if not hg.COin then return end
	if not hg.COvis then hg.COvis = {} end
	if nextSync > CurTime() then return end
	nextSync = CurTime() + 0.15

	local fresh = hg.COin
	hg.COin = nil

	local vis = hg.COvis
	clearClaimed()

	local usedCount = 0
	for j = 1, #fresh do
		local p = fresh[j][1]
		local key = math_floor(p.x / cell) + math_floor(p.y / cell) * 1024 + math_floor(p.z / cell) * 1048576
		local bucket = grid[key]
		if not bucket then
			bucket = { n = 0 }
			grid[key] = bucket
			gridKeys = gridKeys + 1
		end
		local n = bucket.n + 1
		if n == 1 then
			usedCount = usedCount + 1
			usedBuckets[usedCount] = bucket
		end
		bucket.n = n
		bucket[n] = j
	end

	for i = #vis, 1, -1 do
		local vp = vis[i]
		local p = vp.pos
		local bestD, bestJ = cell * cell, nil
		local ix, iy, iz = math_floor(p.x / cell), math_floor(p.y / cell), math_floor(p.z / cell)

		for dx = -1, 1 do
			for dy = -1, 1 do
				for dz = -1, 1 do
					local bucket = grid[ix + dx + (iy + dy) * 1024 + (iz + dz) * 1048576]
					if bucket then
						for k = 1, bucket.n do
							local j = bucket[k]
							if not claimed[j] then
								local d = p:DistToSqr(fresh[j][1])
								if d < bestD then
									bestD = d
									bestJ = j
								end
							end
						end
					end
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
					endpos = vp.pos + Vector(0, 0, 12000),
					mask = MASK_SOLID_BRUSHONLY
				})

				if str.HitSky then
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
				born = CurTime(),
				seed = math_Rand(0, 100),
				size = math_Rand(190, 280),
				mat = smoke_mats[math_random(#smoke_mats)],
				col = Color(150, 146, 138, 0),
				col2 = Color(118, 110, 100, 0)
			}
		end
	end

	for i = 1, usedCount do
		local bucket = usedBuckets[i]
		local n = bucket.n
		for k = 1, n do bucket[k] = nil end
		bucket.n = 0
		usedBuckets[i] = nil
	end

	if gridKeys > 4096 then
		grid = {}
		gridKeys = 0
	end
end)

local function drawPockets(eye, now, ft)
	local vis = hg.COvis
	if not vis or #vis == 0 then return end

	local kPos = math_min(ft * 2.5, 1)
	local kInt = math_min(ft * 3, 1)
	local eyeLimit = 6500 * 6500
	local nearLimit = 2500 * 2500

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

		local dist2 = pos:DistToSqr(eye)
		if vp.inten <= 0.03 or dist2 > eyeLimit then continue end

		local pos2 = vp.pos2
		pos2.x = pos.x
		pos2.y = pos.y
		pos2.z = pos.z - vp.size * 0.35

		local grow = 1 + math_min((now - (vp.born or now)) * 0.02, 0.35)
		local size = vp.size * grow * (0.9 + 0.14 * math_sin(now * 0.35 + vp.seed))
		local alpha = vp.inten * 125 / grow

		vp.col.a = alpha
		vp.col2.a = alpha * 0.7

		render_SetMaterial(vp.mat)
		render_DrawSprite(pos, size * 1.7, size * 1.7, vp.col)
		if dist2 < nearLimit then
			render_DrawSprite(pos2, size, size, vp.col2)
		end
	end
end

hook.Add("PostDrawTranslucentRenderables", "co_gas_render", function(isDepth, isSkybox)
	if isSkybox then return end

	local now = CurTime()
	local ft = FrameTime()
	local eye = EyePos()

	drawPockets(eye, now, ft)
end)
