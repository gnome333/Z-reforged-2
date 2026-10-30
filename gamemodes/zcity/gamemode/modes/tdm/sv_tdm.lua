local MODE = MODE

MODE.name = "tdm"
MODE.BuyTime = 40
MODE.StartMoney = 6500
MODE.start_time = 20
MODE.buymenu = true

MODE.ROUND_TIME = 240

MODE.Chance = 0.04

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
	return 1, true--returning true so guilt bans
end

function MODE:CanLaunch()
	return true
	--[[local points = zb.GetMapPoints( "HMCD_TDM_T" )
	local points2 = zb.GetMapPoints( "HMCD_TDM_CT" )
    return (#points > 0) and (#points2 > 0)]] -- can work without them
end

MODE.ForBigMaps = true

util.AddNetworkString("tdm_start")
function MODE:Intermission()
	game.CleanUpMap()

	for i, ply in player.Iterator() do
		ply:SetupTeam(ply:Team())
		
		ply:SetNWInt( "TDM_Money", self.StartMoney )
	end

	net.Start("tdm_start")
	net.Broadcast()
end

function MODE:CheckAlivePlayers()
	return zb:CheckAliveTeams(true)
end

function MODE:ShouldRoundEnd()
	local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())
	return endround
end

function MODE:RoundStart()
	for k,ply in player.Iterator() do
		ply:Freeze(false)
	end
end

local tblweps = {
	[0] = {
		"weapon_akm",
	},
	[1] = {
		"weapon_m4a1",
	},
}

local tblatts = {
	[0] = {
		{""},
	},
	[1] = {
		{"holo14","laser2","grip3"},
	},
}

local tblarmors = {
	[0] = {
		{"vest4","helmet1"},
	},
	[1] = {
		{"vest4","helmet1"},
	},
}

-- local giveweapons = CreateConVar("zb_tdm_giveweapon","1",FCVAR_LUA_SERVER,"TDMSPAWNS",0,1)

function MODE:GetPlySpawn(ply)
end

function MODE:GiveEquipment()
	timer.Simple(0.1,function()
		local mrand = math.random(#tblweps[0])

		for _, ply in player.Iterator() do
			if not ply:Alive() then continue end
			
			local inv = ply:GetNetVar("Inventory")
			inv["Weapons"]["hg_sling"] = true
			ply:SetNetVar("Inventory",inv)

			ply:SetSuppressPickupNotices(true)
			ply.noSound = true

			if ply:Team() == 1 then
				ply:SetPlayerClass("swat")
				zb.GiveRole(ply, "Counter Terrorist", Color(0,0,190))
				ply:SetNetVar("CurPluv", "pluvberet")
			else
				ply:SetPlayerClass("terrorist")
				zb.GiveRole(ply, "Terrorist", Color(190,0,0))
				ply:SetNetVar("CurPluv", "pluvboss")
			end

			--[[if giveweapons:GetBool() then
				local gun = ply:Give(tblweps[ply:Team()][mrand])
				ply:GiveAmmo(gun:GetMaxClip1() * 3,gun:GetPrimaryAmmoType(),true)
				
				hg.AddAttachmentForce(ply,gun,tblatts[ply:Team()][mrand])
				hg.AddArmor(ply, tblarmors[ply:Team()][mrand])


				ply:Give("weapon_hg_rgd_tpik")
				ply:Give("weapon_walkie_talkie")
				ply:Give("weapon_bandage_sh")
				ply:Give("weapon_tourniquet")
			end--]]

			//ply:Give("weapon_melee")

			ply:Give("weapon_melee")
			ply:Give("weapon_bandage_sh")
			ply:Give("weapon_tourniquet")
			ply.organism.allowholster = true

			local Radio = ply:Give("weapon_walkie_talkie")
			Radio.Frequency = (ply:Team() == 1 and math.Round(math.Rand(88,95),1)) or math.Round(math.Rand(100,108),1)
			local hands = ply:Give("weapon_hands_sh")
			ply:SelectWeapon("weapon_hands_sh")

			timer.Simple(0.1,function()
				ply.noSound = false
			end)

			ply:SetSuppressPickupNotices(false)
		end
	end)
end

function MODE:RoundThink()
end

function MODE:GetTeamSpawn()
	return zb.TranslatePointsToVectors(zb.GetMapPoints( "HMCD_TDM_T" )), zb.TranslatePointsToVectors(zb.GetMapPoints( "HMCD_TDM_CT" ))
end

function MODE:CanSpawn()
end

util.AddNetworkString("tdm_roundend")
function MODE:EndRound()
	timer.Simple(2,function()
		net.Start("tdm_roundend")
		net.Broadcast()
	end)
	local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())
	for k,ply in player.Iterator() do
		if ply:Team() == winner then
			ply:GiveExp(math.random(15,30))
			ply:GiveSkill(math.Rand(0.1,0.15))
			--print("give",ply)
		else
			--print("take",ply)
			ply:GiveSkill(-math.Rand(0.05,0.1))
		end
	end
end

function MODE:PlayerDeath(ply)
end
util.AddNetworkString( "tdm_open_buymenu" )
function MODE:ShowSpare1(ply ) -- OpenMenu
	if not ply:Alive() then return end
	net.Start( "tdm_open_buymenu" )
	net.Send( ply )
end

util.AddNetworkString( "tdm_buyitem" )

local AttachmentPrice = 50
local RefillPrices = {
	weapon_bandage_sh = 100,
	weapon_bigbandage_sh = 200,
	weapon_medkit_sh = 350,
}

local function findAmmoWeapon(ply, ammoName)
	local function match(wep)
		if not IsValid(wep) or not wep.Primary then return end
		if wep.Primary.Ammo == ammoName then return wep, 0 end
		if istable(wep.AmmoTypes) then
			for i, t in ipairs(wep.AmmoTypes) do
				if istable(t) and t[1] == ammoName then return wep, i end
			end
		end
	end

	local wep, idx = match(ply:GetActiveWeapon())
	if wep then return wep, idx end

	for _, w in ipairs(ply:GetWeapons()) do
		wep, idx = match(w)
		if wep then return wep, idx end
	end
end

local function loadBoughtAmmo(ply, ammoName)
	timer.Simple(0.15, function()
		if not IsValid(ply) or not ply:Alive() then return end

		local wep, idx = findAmmoWeapon(ply, ammoName)
		if not IsValid(wep) then return end

		if idx and idx > 0 then
			if not wep.ApplyAmmoChanges then return end

			local clip = wep:Clip1()
			if clip > 0 then
				ply:GiveAmmo(clip, wep.Primary.Ammo, true)
				wep:SetClip1(0)
			end

			wep:ApplyAmmoChanges(idx)
			if wep.Primary.Ammo != ammoName then return end
		end

		if not wep.GetMaxClip1 then return end

		local maxClip = wep:GetMaxClip1()
		if maxClip <= 0 then return end

		local ammoID = game.GetAmmoID(ammoName)
		if ammoID < 0 then return end

		local clip = wep:Clip1()
		if clip < 0 then clip = 0 end

		local reserve = ply:GetAmmoCount(ammoID)
		local need = math.min(reserve, maxClip - clip)
		if need <= 0 then return end

		wep:SetClip1(clip + need)
		ply:SetAmmo(reserve - need, ammoID)

		net.Start("hg_insertAmmo")
			net.WriteEntity(wep)
			net.WriteInt(wep:Clip1(), 10)
		net.Broadcast()
	end)
end

local MaxGrenadeCount = 3

local function buyItem(ply, tItem, silent)
	local function notify(msg)
		if silent then return end
		ply:ChatPrint(msg)
	end

	local category = tItem[1]
	local index = tItem[2]
	if not category or not index then return false end
	local buyItems = CurrentRound().BuyItems
	if not buyItems or not buyItems[category] or not buyItems[category][index] then return false end
	local item = buyItems[category][index]

	if not item then return false end

	if tItem[3] then
		if not ply:HasWeapon(item.ItemClass) then notify("You can't buy this attachment without a weapon.") return false end

		local shortAtt = string.Replace(tItem[3], "ent_att_", "")
		local price = (MODE.AttachmentPrices and MODE.AttachmentPrices[shortAtt]) or AttachmentPrice
		if ((ply:GetNWInt("TDM_Money",0) - price) < 0) then notify("Not enough money.") return false end

		local wep = ply:GetWeapon(item.ItemClass)
		if not IsValid(wep) then notify("This item is unavailable.") return false end

		-- Проверяем, что attachment реально подходит этому оружию
		local attName = string.Replace(tItem[3], "ent_att_", "")
		local placement
		for plc, tbl in pairs(hg.attachments) do
			if tbl[attName] then placement = plc break end
		end

		if not placement then notify("This attachment does not exist.") return false end

		local available = wep.availableAttachments and wep.availableAttachments[placement]
		if not available then notify("This weapon has no slot for this attachment.") return false end

		local mountType = available["mountType"]
		local attMount = hg.attachments[placement][attName].mountType
		local fits = istable(mountType) and not table.IsEmpty(mountType) and table.HasValue(mountType, attMount) or mountType == attMount

		if not fits then notify("This attachment does not fit this weapon.") return false end

		local current = wep.attachments and wep.attachments[placement]
		if current and current[1] == attName then notify("This attachment is already installed.") return false end

		hg.AddAttachmentForce( ply,wep,attName )
		ply:SetNWInt( "TDM_Money", ply:GetNWInt("TDM_Money",0) - price )
		ply:EmitSound("items/itempickup.wav")

		return true
	end

	local refillPrice = RefillPrices[item.ItemClass]
	if refillPrice then
		local wep = ply:GetWeapon(item.ItemClass)
		if IsValid(wep) and istable(wep.modeValues) and istable(wep.modeValuesdef) then
			local vals = wep.modeValues
			local defs = wep.modeValuesdef

			local needRefill = false
			for i, def in ipairs(defs) do
				if (vals[i] or 0) < (istable(def) and def[1] or def) then
					needRefill = true
					break
				end
			end

			if not needRefill then notify("This item is already full.") return false end
			if ((ply:GetNWInt("TDM_Money",0) - refillPrice) < 0) then notify("Not enough money.") return false end

			for i, def in ipairs(defs) do
				vals[i] = istable(def) and def[1] or def
			end

			wep:SetNetVar("modeValues", vals)
			wep.modeValues = vals
			ply:SetNWInt( "TDM_Money", ply:GetNWInt("TDM_Money",0) - refillPrice )
			ply:EmitSound("items/itempickup.wav")

			return true
		end
	end

	if item.TeamBased != nil and item.TeamBased != ply:Team() then notify("This item is not available for your team.") return false end

	if ((ply:GetNWInt("TDM_Money",0) - item.Price) < 0) then notify("Not enough money.") return false end

	-- Stackable grenades: allow buying up to MaxGrenadeCount of the same type
	local currentGrenade = ply:GetWeapon(item.ItemClass)
	if IsValid(currentGrenade) and currentGrenade.count ~= nil then
		if currentGrenade.count >= MaxGrenadeCount then
			notify("You already have the maximum amount (" .. MaxGrenadeCount .. ") of this grenade.")
			return false
		end

		currentGrenade.count = currentGrenade.count + 1

		ply:SetNWInt( "TDM_Money", ply:GetNWInt("TDM_Money",0) - item.Price )
		ply:EmitSound("items/itempickup.wav")

		return true
	end

	local ent = ply:Give(item.ItemClass)

	if not IsValid(ent) then
		notify("This item is unavailable.")
		return false
	end

	if item.Amount then
		ent.AmmoCount = item.Amount
	end

	local ammoName = item.Type == "Ammo" and ent.AmmoType or nil

	if IsValid(ent) and ent.Use then
		ent:Use( ply )
	end

	if IsValid(ent) and ent:GetClass() == "weapon_bloodbag" then
		ent.bloodtype = "o-"
		ent.modeValues[1] = 1
	end

	if IsValid(ent) and ent.GetPrimaryAmmoType then
		ply:GiveAmmo(ent:GetMaxClip1() * 1,ent:GetPrimaryAmmoType(),true)
	end

	if ammoName then
		loadBoughtAmmo(ply, ammoName)
	end

	ply:SetNWInt( "TDM_Money", ply:GetNWInt("TDM_Money",0) - item.Price )
	ply:EmitSound("items/itempickup.wav")

	return true
end

net.Receive("tdm_buyitem",function(len,ply)
	if !CurrentRound().buymenu then return end
	if ((zb.ROUND_START or 0) + 40 < CurTime()) then ply:ChatPrint("Time's up!") return end
	local tItem = net.ReadTable()
	if not istable(tItem) then return end

	buyItem(ply, tItem)
end)

util.AddNetworkString( "tdm_buypreset" )
net.Receive("tdm_buypreset",function(len,ply)
	if !CurrentRound().buymenu then return end
	if ((zb.ROUND_START or 0) + 40 < CurTime()) then ply:ChatPrint("Time's up!") return end
	local preset = net.ReadTable()
	if not istable(preset) then return end
	local items = preset.items
	if not istable(items) or #items == 0 or #items > 24 then return end

	local ammoItems, otherItems = {}, {}

	for _, tItem in ipairs(items) do
		if not istable(tItem) then continue end

		if tItem[1] == "Ammo" then
			ammoItems[#ammoItems + 1] = tItem
		else
			otherItems[#otherItems + 1] = tItem
		end
	end

	local bought, total = 0, 0

	for _, tItem in ipairs(otherItems) do
		local count = math.Clamp(math.floor(tonumber(tItem[4]) or 1), 1, 24)

		for _ = 1, count do
			total = total + 1

			if buyItem(ply, tItem, true) then
				bought = bought + 1
			end
		end
	end

	for _, tItem in ipairs(ammoItems) do
		local count = math.Clamp(math.floor(tonumber(tItem[4]) or 1), 1, 24)

		for _ = 1, count do
			total = total + 1

			if buyItem(ply, tItem, true) then
				bought = bought + 1
			end
		end
	end
end)
