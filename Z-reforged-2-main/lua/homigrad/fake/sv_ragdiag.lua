local function hg_ragdiag_dump(ply)
	if not IsValid(ply) then return end

	local org = ply.organism
	local rag = ply.FakeRagdoll
	local lines = {}

	local function add(k, v)
		lines[#lines + 1] = tostring(k) .. " = " .. tostring(v)
	end

	add("time", os.date("%H:%M:%S"))
	add("class", ply.PlayerClassName)
	add("subclass", tostring(ply.subClass))
	add("model", ply:GetModel())
	add("alive", ply:Alive())

	local okw, weight = pcall(hg.CalculateWeight, ply, 250)
	add("weight_mul", okw and weight or "err")

	local weps = {}
	for i, wep in ipairs(ply:GetWeapons()) do
		weps[#weps + 1] = wep:GetClass() .. ":" .. tostring(wep.weight)
	end
	add("weapons", table.concat(weps, ", "))

	local activewep = ply:GetActiveWeapon()
	if IsValid(activewep) then
		add("active_weapon", activewep:GetClass() .. " ishgweapon=" .. tostring(activewep.ishgweapon) .. " ismelee=" .. tostring(activewep.ismelee) .. " ismelee2=" .. tostring(activewep.ismelee2) .. " resting=" .. tostring(activewep.IsResting and activewep:IsResting() or false))
	else
		add("active_weapon", "none")
	end

	local ammototal = 0
	for id, count in pairs(ply:GetAmmo()) do
		ammototal = ammototal + count
	end
	add("ammo_count", ammototal)

	local arm = {}
	for k, v in pairs(ply.armors or {}) do
		arm[#arm + 1] = k .. "=" .. v
	end
	add("armors", table.concat(arm, ", "))

	if org then
		add("alive_org", org.alive)
		add("otrub", org.otrub)
		add("needotrub", org.needotrub)
		add("fake", org.fake)
		add("needfake", org.needfake)
		add("canmove", org.canmove)
		add("canmovehead", org.canmovehead)
		add("stun_left", (org.stun or 0) - CurTime())
		add("lightstun_left", (org.lightstun or 0) - CurTime())
		add("spine1", org.spine1)
		add("spine2", org.spine2)
		add("spine3", org.spine3)
		add("pain", org.pain)
		add("blood", org.blood)
		if org.o2 then
			add("o2", tostring(org.o2[1]) .. "/" .. tostring(org.o2.range))
		else
			add("o2", "MISSING")
		end
		add("consciousness", org.consciousness)
		add("disorientation", org.disorientation)
		add("immobilization", org.immobilization)
		if org.stamina then
			add("stamina", tostring(org.stamina[1]) .. "/" .. tostring(org.stamina.max))
		else
			add("stamina", "MISSING")
		end
		add("larm", org.larm)
		add("rarm", org.rarm)
		add("lleg", org.lleg)
		add("rleg", org.rleg)
		add("fear", org.fear)

		if org.o2 then
			local power = org.pain and ((org.pain > 50 or org.blood < 2900 or org.o2[1] < 5) and 0.3) or ((org.pain > 20 or org.blood < 4200 or org.o2[1] < 10) and 0.5) or 1
			add("power", power * org.consciousness)
		else
			add("power", "no o2")
		end
		add("thresholds", "spine1=" .. tostring(hg.organism.fake_spine1) .. " spine2=" .. tostring(hg.organism.fake_spine2) .. " spine3=" .. tostring(hg.organism.fake_spine3))
	else
		add("organism", "MISSING")
	end

	add("fakereag_valid", IsValid(rag))
	add("lastFake_left", ((ply.lastFake or 0) - CurTime()))
	add("fakecd_left", ((ply.fakecd or 0) - CurTime()))
	add("ragdollcombat", GetConVar("hg_ragdollcombat"):GetBool())
	add("jumpedfake", ply.jumpedfake)

	if IsValid(rag) then
		add("rag_model", rag:GetModel())
		add("rag_physcount", rag:GetPhysicsObjectCount())

		local cached = hg.cachedmodels[rag:GetModel()]
		if cached then
			local map = {}
			for bonename, physnum in pairs(cached) do
				map[#map + 1] = bonename .. "->" .. physnum
			end
			table.sort(map)
			add("cached_map", table.concat(map, " | "))
		else
			add("cached_map", "MISSING")
		end

		add("realPhysNum_1_spine", hg.realPhysNum(rag, 1))
		add("realPhysNum_5_lhand", hg.realPhysNum(rag, 5))
		add("realPhysNum_7_rhand", hg.realPhysNum(rag, 7))
		add("realPhysNum_10_head", hg.realPhysNum(rag, 10))

		local massline = {}
		for i = 0, rag:GetPhysicsObjectCount() - 1 do
			local phys = rag:GetPhysicsObjectNum(i)
			local bonename = rag:GetBoneName(rag:TranslatePhysBoneToBone(i))
			massline[#massline + 1] = i .. ":" .. tostring(bonename) .. ":" .. (IsValid(phys) and math.Round(phys:GetMass(), 1) or "!")
		end
		add("masses", table.concat(massline, " "))

		add("ConsLH", IsValid(rag.ConsLH))
		add("ConsRH", IsValid(rag.ConsRH))
		add("power_field", rag.power)
		add("dtime", rag.dtime)
		add("eyes_attachment", rag:LookupAttachment("eyes"))
	else
		add("fakereag_reason", "no FakeRagdoll (not in fake state yet)")
	end

	local txt = table.concat(lines, "\n")
	print("[hg_ragdiag]\n" .. txt)
	ply:PrintMessage(HUD_PRINTCONSOLE, "\n[hg_ragdiag]\n" .. txt)

	file.Write("hg_ragdiag.txt", txt)
end

concommand.Add("hg_ragdiag", function(ply)
	if not IsValid(ply) then return end
	hg_ragdiag_dump(ply)
end)
