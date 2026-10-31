local medItems = {
	weapon_medkit_sh = {model = "models/w_models/weapons/w_eq_medkit.mdl", pos = Vector(-7, 7, -7), ang = Angle(-90, 90, 90), step = 4, max = 2},
	weapon_bloodbag = {model = "models/zcity/other/bloodbag.mdl", pos = Vector(4, 6.7, -6.6), ang = Angle(-90, 90, 180), step = 3.5, max = 2},
	weapon_bandage_sh = {model = "models/bandages.mdl", pos = Vector(6, 1, 1.5), ang = Angle(0, -80, 0), step = -2.5, max = 2},
	weapon_bigbandage_sh = {model = "models/bandages.mdl", pos = Vector(-6, 1, 1.5), ang = Angle(0, 80, 0), step = -2.5, max = 2},
	weapon_painkillers = {model = "models/bloocobalt/l4d/items/w_eq_pills.mdl", pos = Vector(-1, 1, -7), ang = Angle(0, 90, 90), step = -2.5, max = 2},
	weapon_betablock = {model = "models/bloocobalt/l4d/items/w_eq_pills.mdl", pos = Vector(-7, 1, -7), ang = Angle(0, 90, 90), step = -2, max = 2},
	weapon_tourniquet = {model = "models/tourniquet/tourniquet.mdl", pos = Vector(-2, -3, 5), ang = Angle(0, -80, 0), step = 2.5, max = 2},
}

local IsValid = IsValid
local table_remove = table.remove
local ipairs = ipairs
local pairs = pairs
local tempVec = Vector()
local pelvisBone = "ValveBiped.Bip01_Pelvis"

local function itemScale(class, item)
	if class ~= "weapon_bandage_sh" and class ~= "weapon_bigbandage_sh" then return 1 end
	if not item or isbool(item) then return 1 end

	local vals = item.modeValues
	if not istable(vals) or not isnumber(vals[1]) then return 1 end

	local def = item.modeValuesdef
	if not istable(def) then return 1 end
	def = def[1]
	if istable(def) then def = def[1] end
	if not isnumber(def) or def <= 0 then return 1 end

	return math.Clamp(vals[1] / (def * 0.8), 0.5, 1)
end

--;; На поясе не рисуем то, что уже нельзя держать: удалённые сущности и израсходованные предметы
--;; (медицина с modeValues[1] <= 0 остаётся в инвентаре и раньше «всплывала» снова на поясе).
local function itemIsUsable(item)
	if isentity(item) and not IsValid(item) then return false end

	local vals = istable(item) and item.modeValues or nil
	if istable(vals) and isnumber(vals[1]) and vals[1] <= 0 then return false end

	return true
end

function hg.RenderMedBelt(ent, ply)
	if not IsValid(ent) or not IsValid(ply) then return end
	if not ent.shouldTransmit or ent.NotSeen then return end

	local scales = {}
	local act

	if ply.GetWeapons and ply:Alive() then
		act = ply.GetActiveWeapon and ply:GetActiveWeapon()

		for _, wep in ipairs(ply:GetWeapons()) do
			if not IsValid(wep) then continue end
			if wep == act then continue end
			if not itemIsUsable(wep) then continue end

			local class = wep:GetClass()
			local cfg = medItems[class]
			if not cfg then continue end

			local list = scales[class]
			if not list then
				list = {}
				scales[class] = list
			end

			if #list >= cfg.max then continue end

			list[#list + 1] = itemScale(class, wep)
		end
	end

	if not next(scales) then
		local inv = ply.GetNetVar and ply:GetNetVar("Inventory")

		if (not inv or not inv.Weapons or not next(inv.Weapons)) and ent ~= ply and ent.GetNetVar then
			inv = ent:GetNetVar("Inventory")
		end

		if inv and inv.Weapons then
			--;; Предмет в руках с пояса не рисуем: инвентарь всё ещё хранит его, но держать его на поясе нельзя
			local actClass = IsValid(act) and act:GetClass() or nil

			for class, item in pairs(inv.Weapons) do
				if class == actClass then continue end
				if not itemIsUsable(item) then continue end

				local cfg = medItems[class]
				if not cfg then continue end

				local list = scales[class]
				if not list then
					list = {}
					scales[class] = list
				end

				if #list >= cfg.max then continue end

				list[#list + 1] = itemScale(class, item)
			end
		end
	end

	local models = ent.medBeltModels

	if not models then
		models = {}
		ent.medBeltModels = models

		ent:CallOnRemove("medBelt", function()
			for _, list in pairs(models) do
				for _, mdl in ipairs(list) do
					if IsValid(mdl) then mdl:Remove() end
				end
			end
		end)
	end

	for class, cfg in pairs(medItems) do
		local count = scales[class] and #scales[class] or 0
		local list = models[class]

		if count <= 0 then
			if list then
				for i = #list, 1, -1 do
					local mdl = table_remove(list, i)
					if IsValid(mdl) then mdl:Remove() end
				end

				models[class] = nil
			end

			continue
		end

		if not list then
			list = {}
			models[class] = list
		end

		while #list > count do
			local mdl = table_remove(list)
			if IsValid(mdl) then mdl:Remove() end
		end

		while #list < count do
			local mdl = ClientsideModel(cfg.model)
			if not IsValid(mdl) then break end

			mdl:SetNoDraw(true)
			list[#list + 1] = mdl
		end
	end

	if not next(models) then return end

	local bone = ent:LookupBone(pelvisBone)
	if not bone then return end

	local matrix = ent:GetBoneMatrix(bone)
	if not matrix then return end

	local mPos, mAng = matrix:GetTranslation(), matrix:GetAngles()

	for class, list in pairs(models) do
		local cfg = medItems[class]
		local scl = scales[class]

		for i, mdl in ipairs(list) do
			if not IsValid(mdl) then continue end

			local scale = scl and scl[i] or 1
			if mdl.medBeltScale ~= scale then
				mdl:SetModelScale(scale)
				mdl.medBeltScale = scale
			end

			tempVec:Set(cfg.pos)
			tempVec[3] = tempVec[3] + cfg.step * (i - 1)

			local pos, ang = LocalToWorld(tempVec, cfg.ang, mPos, mAng)

			mdl:SetRenderOrigin(pos)
			mdl:SetRenderAngles(ang)
			mdl:DrawModel()
		end
	end
end
