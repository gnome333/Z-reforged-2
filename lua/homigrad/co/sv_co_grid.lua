--[[-------------------------------------------------------------------------
	CO gas — realistic volumetric dispersion solver

	Model
	-----
	The gas lives on a sparse Eulerian grid (one cell = hg_co_cell units).
	Every solver tick the following happens, in this order:

	  1. Sources        — burning entities and hg.COGasAdd() inject CO + heat.
	  2. Geometry       — per-cell face openness (how much of each face is a
	                      real opening) and "is this cell under open sky",
	                      both cached and revalidated in a budgeted way.
	  3. Velocity field — wind (damped indoors) + thermal buoyancy of hot gas.
	                      CO is very slightly lighter than air, so cold gas
	                      still drifts up, only far slower than hot smoke.
	  4. Transport      — mass conservative upwind advection across every open
	                      face, plus Fickian turbulent diffusion. Blocked
	                      faces carry no flux, so gas never crosses a wall;
	                      a doorway is simply a face with partial openness,
	                      which is why gas creeps through doors and gaps.
	  5. Sinks          — Newton cooling towards ambient, ventilation of cells
	                      that are connected to open air (wind dependent),
	                      and a very slow loss to surfaces.

	Everything is budgeted: face probing and sky checks are spread over ticks,
	and the cell count is capped. The solver is safe to run at 10 Hz on a busy
	server and degrades gracefully (gas spreads a bit slower) instead of
	spiking.
---------------------------------------------------------------------------]]

if not SERVER then return end

hg.co = hg.co or {}
local co = hg.co

local math_min = math.min
local math_max = math.max
local math_abs = math.abs
local math_sqrt = math.sqrt
local math_floor = math.floor
local math_exp = math.exp
local math_cos = math.cos
local math_sin = math.sin
local math_Rand = math.Rand
local CurTime = CurTime
local PointContents = util.PointContents
local TraceLine = util.TraceLine
local IsValid = IsValid
local band = bit.band
local isvector = isvector

local CONTENTS_SOLID_BIT = CONTENTS_SOLID
local MASK_SKY = MASK_SOLID_BRUSHONLY

-- Face indices
local FX, NX, FY, NY, FZ, NZ = 1, 2, 3, 4, 5, 6

local faceDirs = {
	{ 1, 0, 0 }, { -1, 0, 0 },
	{ 0, 1, 0 }, { 0, -1, 0 },
	{ 0, 0, 1 }, { 0, 0, -1 },
}

-- Tangent pairs used to sample the 5 probe points of a face
local faceTangents = {
	{ Vector(0, 1, 0), Vector(0, 0, 1) },
	{ Vector(0, 1, 0), Vector(0, 0, 1) },
	{ Vector(1, 0, 0), Vector(0, 0, 1) },
	{ Vector(1, 0, 0), Vector(0, 0, 1) },
	{ Vector(1, 0, 0), Vector(0, 1, 0) },
	{ Vector(1, 0, 0), Vector(0, 1, 0) },
}

-- Only these three faces are processed; the opposite ones are handled by the
-- neighbour itself, which keeps the flux mass conservative (each face once).
local POS_FACES = { FX, FY, FZ }
local NEG_OF = { [FX] = NX, [FY] = NY, [FZ] = NZ }

--[[-------------------------------------------------------------------------
	Tuning
---------------------------------------------------------------------------]]
local COOL_TAU = 4.0			-- seconds, Newton cooling of hot gas
local SURFACE_SINK = 0.004		-- 1/s, slow loss of CO to surfaces and leaks
local MAX_CELL_T = 900			-- cap on excess temperature, deg C
local MAX_CELL_C = 32.0			-- numerical safety net only (1.0 = lethal, render saturates at 1.0)
-- Cooled CO is essentially neutrally buoyant (see sh_co.lua). A permanent
-- upward bias is what used to glue the gas to the ceiling, so the resting
-- drift is tiny and only real heat makes the gas climb.
local RISE_MIN = 0.5			-- u/s, residual drift of cold CO
local RISE_MAX = 700			-- u/s, cap on buoyant rise
local CONVECTION_SPEED = 22		-- u/s, peak indoor convection current
local CONVECTION_SCALE = 0.006	-- spatial frequency of the convection field
local CONVECTION_TURN = 0.12	-- how fast the convection field evolves
local CEILING_JET = 0.55		-- fraction of blocked upward velocity turned sideways
local CEILING_JET_MAX = 90		-- u/s, cap on the lateral ceiling jet speed
local SKY_RECHECK = 10.0		-- seconds between sky probes of a cell
local FACE_RECHECK = 30.0		-- seconds between face revalidations (doors open/close)
local FACE_CELL_BUDGET = 32		-- cells whose faces may be probed per tick
local SKY_CELL_BUDGET = 60		-- cells whose sky state may be probed per tick
local FACE_PROBES = 5			-- probe points per face

--[[-------------------------------------------------------------------------
	Grid storage
---------------------------------------------------------------------------]]
local cells = {}
local cellList = {}
local cellCount = 0
local blockedCenters = {}
local cellSize = 64

local probeVec = Vector()
local skyTr = { start = nil, endpos = Vector(), mask = MASK_SKY }

local function getCell(ix, iy, iz, create)
	local key = (ix + 1024) * 4194304 + (iy + 1024) * 2048 + (iz + 1024)
	local cell = cells[key]
	if cell then return cell end
	if not create then return nil end
	if blockedCenters[key] then return nil end

	local L = cellSize
	local pos = Vector(ix * L + L * 0.5, iy * L + L * 0.5, iz * L + L * 0.5)

	-- A cell whose centre is inside solid geometry cannot hold gas
	if band(PointContents(pos), CONTENTS_SOLID_BIT) != 0 or not util.IsInWorld(pos) then
		blockedCenters[key] = true
		return nil
	end

	cell = {
		key = key,
		ix = ix, iy = iy, iz = iz,
		pos = pos,
		c = 0, c0 = 0, dc = 0,		-- concentration and its transport buffers
		T = 0, T0 = 0, dT = 0,		-- excess temperature and its buffers
		u = 0, v = 0, w = 0,		-- velocity, units/s
		fo = nil,					-- per face openness 0..1 (nil = not probed yet)
		nextFace = 0,
		sky = false, nextSky = 0,
		alive = CurTime(),
	}

	cells[key] = cell
	cellCount = cellCount + 1
	cell.idx = cellCount
	cellList[cellCount] = cell
	return cell
end

-- Swap-remove keeps removal O(1); cell.idx is maintained on every add/remove
local function removeCell(cell)
	cells[cell.key] = nil

	local idx = cell.idx
	local last = cellList[cellCount]

	if idx and idx <= cellCount and cellList[idx] == cell then
		if last != cell then
			cellList[idx] = last
			last.idx = idx
		end
		cellList[cellCount] = nil
	else
		-- Defensive fallback: never leak a cell even if the index got out of sync
		for i = 1, cellCount do
			if cellList[i] == cell then
				if last != cell then
					cellList[i] = last
					last.idx = i
				end
				cellList[cellCount] = nil
				break
			end
		end
	end

	cellCount = cellCount - 1
end

--[[-------------------------------------------------------------------------
	Geometry probes
---------------------------------------------------------------------------]]
local function probeFaceOpenness(cell)
	local L = cellSize
	local half = L * 0.5
	local eps = L * 0.06		-- sample slightly outside the face, into the neighbour
	local spread = L * 0.3
	local p = cell.pos
	local fo = cell.fo
	if not fo then
		fo = { 0, 0, 0, 0, 0, 0 }
		cell.fo = fo
	end

	for f = 1, 6 do
		local d = faceDirs[f]
		local t1 = faceTangents[f][1]
		local t2 = faceTangents[f][2]

		local cx = p.x + d[1] * (half + eps)
		local cy = p.y + d[2] * (half + eps)
		local cz = p.z + d[3] * (half + eps)

		local free = 0

		probeVec:SetUnpacked(cx, cy, cz)
		if band(PointContents(probeVec), CONTENTS_SOLID_BIT) == 0 then free = free + 1 end

		probeVec:SetUnpacked(cx + t1.x * spread, cy + t1.y * spread, cz + t1.z * spread)
		if band(PointContents(probeVec), CONTENTS_SOLID_BIT) == 0 then free = free + 1 end

		probeVec:SetUnpacked(cx - t1.x * spread, cy - t1.y * spread, cz - t1.z * spread)
		if band(PointContents(probeVec), CONTENTS_SOLID_BIT) == 0 then free = free + 1 end

		probeVec:SetUnpacked(cx + t2.x * spread, cy + t2.y * spread, cz + t2.z * spread)
		if band(PointContents(probeVec), CONTENTS_SOLID_BIT) == 0 then free = free + 1 end

		probeVec:SetUnpacked(cx - t2.x * spread, cy - t2.y * spread, cz - t2.z * spread)
		if band(PointContents(probeVec), CONTENTS_SOLID_BIT) == 0 then free = free + 1 end

		fo[f] = free / FACE_PROBES
	end

	cell.nextFace = CurTime() + FACE_RECHECK
end

local function probeSky(cell)
	local p = cell.pos
	skyTr.start = p
	skyTr.endpos:SetUnpacked(p.x, p.y, p.z + 12000)
	local tr = TraceLine(skyTr)
	cell.sky = tr.HitSky or not tr.Hit
	cell.nextSky = CurTime() + SKY_RECHECK
end

--[[-------------------------------------------------------------------------
	Sources
---------------------------------------------------------------------------]]
local fireSources = setmetatable({}, { __mode = "k" })

hook.Add("vFireCreated", "co_grid_fire_source", function(fire)
	if IsValid(fire) then fireSources[fire] = true end
end)
hook.Add("vFireRemoved", "co_grid_fire_source", function(fire)
	fireSources[fire] = nil
end)

function hg.COAddSource(pos, amount, heat)
	if not isvector(pos) then return nil end
	local L = cellSize
	local cell = getCell(math_floor(pos.x / L), math_floor(pos.y / L), math_floor(pos.z / L), true)
	if not cell then return nil end

	if amount and amount > 0 then
		cell.c = math_min(cell.c + amount, MAX_CELL_C)
	end
	if heat and heat > 0 then
		cell.T = math_min(cell.T + heat, MAX_CELL_T)
	end
	cell.alive = CurTime()
	return cell
end

--[[-------------------------------------------------------------------------
	Queries
---------------------------------------------------------------------------]]
function hg.COGetConcentration(pos)
	if not co.physics:GetBool() then return nil end
	if not isvector(pos) then return nil end

	local L = cellSize
	local fx = pos.x / L - 0.5
	local fy = pos.y / L - 0.5
	local fz = pos.z / L - 0.5

	local ix = math_floor(fx)
	local iy = math_floor(fy)
	local iz = math_floor(fz)

	local tx = fx - ix
	local ty = fy - iy
	local tz = fz - iz

	local x0, x1 = 1 - tx, tx
	local y0, y1 = 1 - ty, ty
	local z0, z1 = 1 - tz, tz

	local c = 0

	for dx = 0, 1 do
		local wx = dx == 0 and x0 or x1
		if wx > 0 then
			for dy = 0, 1 do
				local wy = dy == 0 and y0 or y1
				if wy > 0 then
					local wxy = wx * wy
					for dz = 0, 1 do
						local wz = dz == 0 and z0 or z1
						if wz > 0 then
							local cell = getCell(ix + dx, iy + dy, iz + dz, false)
							if cell then
								c = c + cell.c * wxy * wz
							end
						end
					end
				end
			end
		end
	end

	return c
end

function hg.COGetHeat(pos)
	if not isvector(pos) then return 0 end
	local L = cellSize
	local cell = getCell(math_floor(pos.x / L), math_floor(pos.y / L), math_floor(pos.z / L), false)
	return cell and cell.T or 0
end

-- Read-only access to the cell storage, used by the network layer
function hg.COGetCells()
	return cellList, cellCount
end

function hg.COGetCellSize()
	return cellSize
end

--[[-------------------------------------------------------------------------
	Solver
---------------------------------------------------------------------------]]
local lastStep = 0
local lastCellSize = 64

local function resetGrid()
	cells = {}
	cellList = {}
	cellCount = 0
	blockedCenters = {}
	lastStep = 0
end

local function enforceCellCap(maxCells)
	-- O(n) trim from the tail of the list. This only ever runs when the grid
	-- is far beyond its cap (a pathological fire), and losing arbitrary cells
	-- there is much better than burning CPU looking for the perfect victim.
	local excess = cellCount - maxCells
	for _ = 1, excess do
		if cellCount <= 0 then break end
		removeCell(cellList[cellCount])
	end
end

local function step(dt, now)
	local L = cellSize
	local wind = co.wind
	local windSpeed = math_sqrt(wind.x * wind.x + wind.y * wind.y)

	local buoyMul = co.buoyancy:GetFloat()
	local diffCoef = co.diffusion:GetFloat() * co.UNIT_PER_METRE * co.UNIT_PER_METRE
	local ventMul = co.vent:GetFloat()
	local sourceMul = co.source:GetFloat()

	--[[--- 1. Sources ------------------------------------------------------]]
	for fire in pairs(fireSources) do
		if not IsValid(fire) then
			fireSources[fire] = nil
			continue
		end
		local state = fire.GetFireState and fire:GetFireState() or 1
		-- Small fires (1-2) are smouldering at worst: no meaningful CO output
		if state > 2 then
			local pos = fire:GetPos()
			-- CO output. Calibrated so a size 5 fire takes a closed 10x10x5 m
			-- room from nothing to a lethal concentration in about half a
			-- minute, and fills it evenly in about a minute.
			local rate = 0.5 * (state - 2) * sourceMul * dt
			-- Heat is a rate too: it equilibrates against COOL_TAU, so a big
			-- fire settles around a couple of hundred degrees of excess
			-- temperature instead of saturating the cap.
			local heat = 12 * (state - 2) * dt
			hg.COAddSource(pos, rate, heat)
		end
	end

	--[[--- 2. Geometry (budgeted) ------------------------------------------]]
	local faceBudget = FACE_CELL_BUDGET
	local skyBudget = SKY_CELL_BUDGET
	for i = 1, cellCount do
		local cell = cellList[i]
		if cell.c > 0.001 or cell.T > 1 then
			if faceBudget > 0 and (not cell.fo or cell.nextFace < now) then
				probeFaceOpenness(cell)
				faceBudget = faceBudget - 1
			end
			if skyBudget > 0 and cell.nextSky < now then
				probeSky(cell)
				skyBudget = skyBudget - 1
			end
			if faceBudget <= 0 and skyBudget <= 0 then break end
		end
	end

	--[[--- 3. Velocity field -----------------------------------------------]]
	local kz = math_min(dt / 0.6, 1)
	local kh = math_min(dt / 1.2, 1)

	-- Indoor convection: a slow, spatially varying drift. It does not do the
	-- mixing on its own (turbulent diffusion does), but it keeps the gas from
	-- sitting in a perfectly static lattice and carries it between rooms.
	local convMul = co.convection:GetFloat() * CONVECTION_SPEED
	local convTime = now * CONVECTION_TURN
	local doConv = convMul > 0

	-- Ceiling jet budget: how many cells may be turned sideways this tick
	local jetBudget = 400

	for i = 1, cellCount do
		local cell = cellList[i]
		local T = cell.T

		-- Thermal updraft. Cold CO is neutral: it only drifts slowly.
		local targetW = RISE_MIN
		if T > 0.5 then
			local vT = math_sqrt(2 * co.GRAVITY * (T / 293) * L) * buoyMul
			targetW = math_min(vT + RISE_MIN, RISE_MAX)
		end

		-- Wind only exists outdoors. A closed room is not ventilated by the
		-- outside wind, so the indoor term is zero and all indoor mixing is
		-- done by turbulent diffusion + convection. `exposure` is 1 under
		-- open sky (where the wind genuinely disperses the gas) and 0 inside.
		local exposure = cell.sky and 1 or 0
		local targetU = wind.x * exposure
		local targetV = wind.y * exposure

		if doConv then
			local p = cell.pos
			local ang = p.x * CONVECTION_SCALE + p.y * CONVECTION_SCALE * 1.25 + convTime
			local indoor = 1 - exposure
			targetU = targetU + math_cos(ang) * convMul * indoor
			targetV = targetV + math_sin(ang * 1.37) * convMul * indoor
		end

		-- Ceiling jet: a plume that hits a closed face has to go sideways,
		-- otherwise the gas just stacks up in a thin layer under the ceiling.
		-- This sets a *target* velocity (not an impulse), so it cannot run away.
		local fo = cell.fo
		if fo and fo[FZ] <= 0.05 and targetW > 1 and jetBudget > 0 then
			jetBudget = jetBudget - 1
			if not cell.jetAng then
				cell.jetAng = math_Rand(0, math.pi * 2)
			end
			local lateral = math_min(targetW * CEILING_JET, CEILING_JET_MAX)
			targetU = targetU + math_cos(cell.jetAng) * lateral
			targetV = targetV + math_sin(cell.jetAng) * lateral
			targetW = targetW * (1 - CEILING_JET)
		end

		cell.w = cell.w + (targetW - cell.w) * kz
		cell.u = cell.u + (targetU - cell.u) * kh
		cell.v = cell.v + (targetV - cell.v) * kh
	end

	--[[--- 4. Transport ----------------------------------------------------]]
	-- Snapshot, then accumulate deltas, then apply: this keeps the scheme
	-- stable and order independent.
	local snapshotCount = cellCount
	for i = 1, snapshotCount do
		local cell = cellList[i]
		cell.c0 = cell.c
		cell.dc = 0
		cell.T0 = cell.T
		cell.dT = 0
	end

	-- CFL guard. Each cell has three outgoing faces, so a per face fraction of
	-- 0.3 keeps the total outflow below 1 and the scheme cannot produce
	-- negative concentrations. The explicit diffusion term needs its own limit
	-- (1/6 in 3D); above it the solve would oscillate, so it is clamped. If the
	-- clamp kicks in, mixing is simply a bit slower than requested - the gas
	-- still fills the room, just over more ticks.
	local maxVel = L / dt * 0.3
	local diffQ = diffCoef * dt / (L * L)
	if diffQ > 0.15 then diffQ = 0.15 end

	for i = 1, snapshotCount do
		local a = cellList[i]
		local ca = a.c0
		local Ta = a.T0

		-- Nothing to transport out of an empty cell
		if ca < 1e-5 and Ta < 0.05 then continue end

		local fo = a.fo

		for k = 1, 3 do
			local f = POS_FACES[k]
			local nf = NEG_OF[f]
			local d = faceDirs[f]

			local b = getCell(a.ix + d[1], a.iy + d[2], a.iz + d[3], false)

			-- Openness of the shared face (both sides must agree on a wall)
			local openness = 0
			if b then
				if fo and b.fo then
					openness = math_min(fo[f], b.fo[nf])
				elseif fo then
					openness = fo[f]
				elseif b.fo then
					openness = b.fo[nf]
				end
			elseif fo then
				openness = fo[f]
			end
			if openness <= 0 then continue end

			-- Only now materialise the neighbour: the gas front advances one
			-- cell at a time, and getCell refuses centres that are inside a
			-- wall, which is exactly what stops gas from crossing geometry.
			if not b then
				b = getCell(a.ix + d[1], a.iy + d[2], a.iz + d[3], true)
				if not b then continue end
			end

			local vel
			if f == FX then vel = (a.u + b.u) * 0.5
			elseif f == FY then vel = (a.v + b.v) * 0.5
			else vel = (a.w + b.w) * 0.5 end

			if vel > maxVel then vel = maxVel elseif vel < -maxVel then vel = -maxVel end

			local qc, qT

			-- Upwind advective flux
			if vel > 0 then
				qc = ca * vel * dt / L
				qT = Ta * vel * dt / L
			else
				qc = b.c0 * vel * dt / L
				qT = b.T0 * vel * dt / L
			end

			-- Fickian diffusion (independent of flow direction)
			qc = qc + diffQ * (ca - b.c0)
			qT = qT + diffQ * (Ta - b.T0)

			qc = qc * openness
			qT = qT * openness

			a.dc = a.dc - qc
			b.dc = b.dc + qc
			a.dT = a.dT - qT
			b.dT = b.dT + qT
		end
	end

	--[[--- 5. Sinks --------------------------------------------------------]]
	local cool = math_exp(-dt / COOL_TAU)
	local sink = math_exp(-SURFACE_SINK * dt)
	-- Ventilation rate of a cell that is connected to open air
	local ventOpen = (0.35 + windSpeed * 0.012) * ventMul
	local ventFactor = math_exp(-ventOpen * dt)

	-- Iterate the *current* count: cells materialised during transport carry
	-- their flux in dc/dT and must be integrated in the same tick, otherwise
	-- the mass that entered them would be dropped.
	local totalCount = cellCount

	for i = 1, totalCount do
		local cell = cellList[i]

		local c = cell.c0 + cell.dc
		local T = cell.T0 + cell.dT

		if c < 0 then c = 0 elseif c > MAX_CELL_C then c = MAX_CELL_C end
		if T < 0 then T = 0 elseif T > MAX_CELL_T then T = MAX_CELL_T end

		if cell.sky then
			c = c * ventFactor
			T = T * ventFactor * cool
		else
			c = c * sink
			T = T * cool
		end

		cell.c = c
		cell.T = T

		if c > 1e-3 or T > 0.5 then
			cell.alive = now
		end
	end

	--[[--- 6. Cleanup ------------------------------------------------------]]
	local maxCells = co.maxcells:GetInt()
	if cellCount > maxCells then
		enforceCellCap(maxCells)
	end

	for i = cellCount, 1, -1 do
		local cell = cellList[i]
		if cell.c < 1e-4 and cell.T < 0.2 and (now - cell.alive) > 1.5 then
			removeCell(cell)
		end
	end
end

--[[-------------------------------------------------------------------------
	Entry point, called from sv_co.lua's Think hook
---------------------------------------------------------------------------]]
function hg.COGridThink()
	if not co.physics:GetBool() then return end

	local now = CurTime()

	-- Cell size is a convar: changing it invalidates the whole grid
	local wanted = co.cell:GetInt()
	if wanted != lastCellSize then
		lastCellSize = wanted
		cellSize = wanted
		resetGrid()
		return
	end

	local rate = co.rate:GetFloat()
	if rate <= 0 then return end

	if lastStep > now then
		-- Clock went backwards (map change): restart cleanly
		lastStep = now
		return
	end

	local interval = 1 / rate
	if now - lastStep < interval then return end

	local dt = math_min(now - lastStep, 0.25)
	lastStep = now

	step(dt, now)
end

--[[-------------------------------------------------------------------------
	Maintenance
---------------------------------------------------------------------------]]
hook.Add("PostCleanupMap", "co_grid_cleanup", function()
	resetGrid()
end)

concommand.Add("hg_co_grid", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end

	local maxC, avgC, hot = 0, 0, 0
	for i = 1, cellCount do
		local cell = cellList[i]
		if cell.c > maxC then maxC = cell.c end
		if cell.T > 100 then hot = hot + 1 end
		avgC = avgC + cell.c
	end
	if cellCount > 0 then avgC = avgC / cellCount end

	local msg = string.format(
		"[CO grid] cells=%d  size=%d  maxC=%.3f  avgC=%.4f  hot=%d  rate=%.1fHz  model=%s",
		cellCount, cellSize, maxC, avgC, hot, co.rate:GetFloat(),
		co.physics:GetBool() and "grid" or "legacy"
	)
	if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

concommand.Add("hg_co_clear", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end
	resetGrid()
	hg.particles = {}
end)
