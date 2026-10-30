--\\ Stamina API
	-- Single entry point for reading stamina as a ratio.
	--
	-- The movement code used to compare the absolute value against a hardcoded 180/120. That
	-- silently broke for anything that raises stamina.max above 180: homicide traitors run at 300,
	-- so the clamped expression stayed at 1 and those players never suffered a stamina penalty.
	--
	-- Nothing here changes behaviour on its own; it only centralises the maths so the numbers can
	-- be changed in one place instead of several.

	hg.stamina = hg.stamina or {}

	local STAMINA = hg.stamina

	STAMINA.DEFAULT_MAX = 180

	-- stamina.max is recomputed every organism tick from adrenaline, pneumothorax and hunger, and
	-- is nil for a moment right after an organism is created, so never read it raw.
	function STAMINA.getMax(org)
		if not org or not org.stamina then return STAMINA.DEFAULT_MAX end

		local m = org.stamina.max

		if not isnumber(m) or m <= 0 then
			return org.stamina.range or STAMINA.DEFAULT_MAX
		end

		return m
	end

	function STAMINA.get(org)
		if not org or not org.stamina then return nil end

		return org.stamina[1]
	end

	-- Current stamina as 0..1. This is what every penalty curve should be written against,
	-- instead of comparing the absolute value to a magic number.
	function STAMINA.ratio(org)
		local cur = STAMINA.get(org)

		if not isnumber(cur) then return 1 end

		return math.Clamp(cur / STAMINA.getMax(org), 0, 1)
	end

	--\\ Ground surface
		-- The engine already knows what the player stands on: util.GetSurfacePropName(trace.SurfaceProps)
		-- returns the surfaceprop from the map's surfaceproperties.txt -- "sand", "dirt", "concrete".
		-- Running on loose ground costs real energy; on tarmac it does not.
		--
		-- Only the exceptions are listed. Anything absent (concrete, metal, tile, asphalt, wood,
		-- glass, plastic...) is the 1.0 baseline, so an unknown custom surfaceprop can never make
		-- things worse by accident.
		--
		-- Keys are lowercase surfaceprop names. The mod already relies on "dirt"/"sand"/"grass"
		-- elsewhere (cl_camera.lua, vehicle wheel slip), so these are known to occur in its maps.
		local hg_surface_effects = ConVarExists("hg_surface_effects") and GetConVar("hg_surface_effects") or CreateConVar("hg_surface_effects", "1", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "Stamina drain and speed depend on the ground surface", 0, 1)
		local hg_surface_strength = ConVarExists("hg_surface_strength") and GetConVar("hg_surface_strength") or CreateConVar("hg_surface_strength", "1", {FCVAR_REPLICATED,FCVAR_ARCHIVE,FCVAR_NOTIFY}, "How strongly the ground surface affects movement (0 = off, 1 = full)", 0, 2)

		STAMINA.SURFACE_DRAIN = {
			-- loose ground: you sink in and slide back, so it is much more work than flat
			mud = 1.32,
			sand = 1.30,
			snow = 1.28,
			gravel = 1.22,
			slime = 1.20,
			-- firm natural ground: uneven, slightly worse than tarmac
			dirt = 1.10,
			grass = 1.10,
			carpet = 1.06,
		}

		-- The same ground also costs a little top speed. Kept separate from the drain table because
		-- the two are not proportional: snow is exhausting but not especially slow, mud is both.
		STAMINA.SURFACE_SPEED = {
			mud = 0.90,
			sand = 0.92,
			snow = 0.92,
			slime = 0.94,
			gravel = 0.95,
			dirt = 0.98,
			grass = 0.98,
		}

		-- Both default to 1, so a missing entry means "normal ground", never a penalty.
		function STAMINA.surfaceDrain(name)
			if not name then return 1 end

			return STAMINA.SURFACE_DRAIN[name:lower()] or 1
		end

		function STAMINA.surfaceSpeed(name)
			if not name then return 1 end

			return STAMINA.SURFACE_SPEED[name:lower()] or 1
		end

		-- Cached trace, used by BOTH sides. The organism table is only networked about once per
		-- second (sv_organism sets sendPlyTime = CurTime() + 1), so a synced surface value would
		-- lag the player by up to a second and disagree with client-side prediction. Tracing locally
		-- on each side from the same position gives both realms the same answer immediately.
		--
		-- The cache matters because sh_inertia runs per usercmd (~66 Hz) while sv_stamina runs at
		-- 10 Hz; without it the movement hook would trace a hundred times a second for a value that
		-- only changes when the player walks onto different ground.
		local SURFACE_CACHE_TIME = 0.2

		function STAMINA.groundSurfaceMuls(ply)
			if not IsValid(ply) then return 1, 1 end
			if not hg_surface_effects:GetBool() then return 1, 1 end

			local cache = ply.HgSurfaceCache

			if cache and cache.time > CurTime() then
				return cache.drain, cache.speed
			end

			local pos = ply:GetPos()
			-- 16 units down catches the ground through a small step or on a slope; mid-air or on a
			-- ladder it hits nothing and both multipliers stay 1
			local tr = util.TraceLine({
				start = pos,
				endpos = pos - vector_up * 16,
				filter = ply,
				mask = MASK_SOLID,
			})

			local name = tr.Hit and util.GetSurfacePropName(tr.SurfaceProps) or nil

			if name == "" then name = nil end

			local s = hg_surface_strength:GetFloat()
			local drain = 1 + (STAMINA.surfaceDrain(name) - 1) * s
			local speed = 1 + (STAMINA.surfaceSpeed(name) - 1) * s

			ply.HgSurfaceCache = {time = CurTime() + SURFACE_CACHE_TIME, drain = drain, speed = speed, name = name}

			return drain, speed
		end
	--//
--//
