hg = hg or {}
hg.particles = hg.particles or {}
hg.co = hg.co or {}

local co = hg.co

local function coConVar(name, default, flags, desc, min, max)
	if ConVarExists(name) then
		return GetConVar(name)
	end
	return CreateConVar(name, default, flags, desc, min, max)
end

local CV = bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED)

co.speed = coConVar("hg_co_speed", "0.6", CV,
	"CO gas drift speed multiplier (lower = slower, smoother spreading)", 0.1, 2)

co.turbulence = coConVar("hg_co_turbulence", "0.5", CV,
	"CO gas turbulence strength (lower = calmer, straighter plumes)", 0, 3)

co.maxparts = coConVar("hg_co_maxparts", "500", CV,
	"Maximum number of CO gas pockets", 100, 4000)

co.UNIT_PER_METRE = 39.3701
co.wind = co.wind or Vector(0, 0, 0)
