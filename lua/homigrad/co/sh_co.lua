--[[-------------------------------------------------------------------------
	CO gas — shared configuration

	Two simulation models live side by side and are switched by hg_co_physics:
		1 = realistic Eulerian grid solver (sv_co_grid.lua, default)
		0 = legacy Lagrangian "pockets" (sv_co.lua), kept as a fallback
---------------------------------------------------------------------------]]

hg = hg or {}
hg.particles = hg.particles or {}
hg.co = hg.co or {}

local co = hg.co

--[[-------------------------------------------------------------------------
	ConVars
---------------------------------------------------------------------------]]
local function coConVar(name, default, flags, desc, min, max)
	if ConVarExists(name) then
		return GetConVar(name)
	end
	return CreateConVar(name, default, flags, desc, min, max)
end

local CV = bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED)

-- 1 = grid solver, 0 = legacy pockets
co.physics = coConVar("hg_co_physics", "1", CV,
	"CO gas physics model: 1 = realistic volumetric dispersion, 0 = legacy particle pockets", 0, 1)

-- Size of a simulation cell in Source units (1 m = 39.37 u). 64 u ~ 1.6 m.
co.cell = coConVar("hg_co_cell", "64", CV,
	"CO gas simulation cell size in units (smaller = more detail, more CPU)", 24, 160)

-- Solver tick rate in Hz.
co.rate = coConVar("hg_co_rate", "10", CV,
	"CO gas solver tick rate in Hz", 1, 30)

-- Turbulent diffusion coefficient, m^2/s.
-- Real molecular diffusion of CO in air is ~1.6e-5 m^2/s, which would take
-- hours to fill a room. What actually mixes gas indoors is turbulence: eddies
-- with a mixing length of ~1 m and a velocity of a few cm/s, which gives an
-- effective eddy diffusivity of a few m^2/s in a room. That is the value used
-- here - it is what makes a closed room fill up uniformly instead of leaving a
-- gas layer glued to the ceiling.
-- NOTE: the solver is explicit, so values above ~4.4 m^2/s become unstable at
-- 10 Hz and get clamped internally (raising hg_co_rate allows higher values).
co.diffusion = coConVar("hg_co_diffusion", "3.8", CV,
	"Turbulent diffusion coefficient of CO in air, m^2/s (higher = mixes faster)", 0, 20)

-- Buoyancy multiplier (thermal updraft strength).
co.buoyancy = coConVar("hg_co_buoyancy", "1", CV,
	"Thermal buoyancy multiplier for hot CO", 0, 4)

-- Indoor convection: slow, spatially varying air currents that mix a room.
co.convection = coConVar("hg_co_convection", "1", CV,
	"Strength of indoor convection currents that mix the gas, 0 disables", 0, 3)

-- Ventilation multiplier (how fast gas escapes through openings to the outside).
co.vent = coConVar("hg_co_vent", "1", CV,
	"Ventilation multiplier: how quickly gas escapes through openings to open air", 0, 5)

-- CO production multiplier for burning entities.
co.source = coConVar("hg_co_source", "1", CV,
	"CO production multiplier for fires", 0, 10)

-- Hard cap on simulated cells.
co.maxcells = coConVar("hg_co_maxcells", "6000", CV,
	"Maximum number of active CO gas cells", 200, 40000)

--[[-------------------------------------------------------------------------
	Shared constants (server solver and client renderer must agree on these)
---------------------------------------------------------------------------]]
co.UNIT_PER_METRE = 39.3701
co.GRAVITY = 9.81 * co.UNIT_PER_METRE	-- m/s^2 -> units/s^2

-- Air molar mass is 28.97 g/mol, CO is 28.01 g/mol: CO is only ~3% lighter than
-- air. That is far too little to float a cloud up to the ceiling and hold it
-- there, which is why the solver treats cooled CO as neutrally buoyant and lets
-- turbulence do the mixing (exactly like the real gas).
co.CO_EQUIV_HEAT = 3.0

-- How much a single hg.COGasAdd() call raises the concentration of its cell.
co.INJECT_SCALE = 0.25

-- Wind vector, updated by sv_co.lua every tick (shared so the solver and any
-- other gas code agree on the same wind field).
co.wind = co.wind or Vector(0, 0, 0)
