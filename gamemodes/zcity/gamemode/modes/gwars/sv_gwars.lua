MODE.name = "gwars"
MODE.PrintName = "Gang Wars"

MODE.ForBigMaps = false
MODE.ROUND_TIME = 180

MODE.Chance = 0.02

MODE.OverideSpawnPos = true
MODE.LootSpawn = false

function MODE:CanLaunch()
	return true
	--[[local points = zb.GetMapPoints( "HMCD_TDM_T" )
	local points2 = zb.GetMapPoints( "HMCD_TDM_CT" )
    return (#points > 0) and (#points2 > 0)--]]
end

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
	return 1, true--returning true so guilt bans
end

util.AddNetworkString("gwars_start")
function MODE:Intermission()
	game.CleanUpMap()

	self.CTPoints = {}
	table.CopyFromTo(zb.GetMapPoints( "HMCD_TDM_CT" ),self.CTPoints)
	self.TPoints = {}
	table.CopyFromTo(zb.GetMapPoints( "HMCD_TDM_T" ),self.TPoints)
	
	for i, ply in player.Iterator() do
		ply:SetupTeam(ply:Team())
		ply:SetNWInt("GWARS_Money", 1500)
		ply.GWARS_PurchasedItems = {}
	end

	net.Start("gwars_start")
	net.Broadcast()
end

function MODE:CheckAlivePlayers()
	return zb:CheckAliveTeams(true)
end

function MODE:ShouldRoundEnd()
	local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())

	return endround or boringround
end

function MODE:BoringRoundFunction()		
	timer.Simple(2, function()
		//PrintMessage(HUD_PRINTTALK, "IT IS A GANG SHOOTOUT FFS...")
	end)
end

local swatSpawned = false

function MODE:RoundStart()
    swatSpawned = false 
end

--[[local tblatts = {
	[0] = {
		{"optic4"},
	},
	[1] = {
		{"holo14","laser2","grip3"}
	}
}]]

local tblarmors = {
	[0] = {
		{"ent_armor_vest3","ent_armor_helmet2"}
	},
	[1] = {
		{"ent_armor_vest3","ent_armor_helmet2"}
	}
}

function MODE:GetPlySpawn(ply)
end

function MODE:GiveEquipment()
	self.CTPoints = {}
	table.CopyFromTo(zb.GetMapPoints( "HMCD_TDM_CT" ),self.CTPoints)
	self.TPoints = {}
	table.CopyFromTo(zb.GetMapPoints( "HMCD_TDM_T" ),self.TPoints)
	timer.Simple(0.1,function()
		local teamArmorCount = { [0] = 0, [1] = 0 } 

		for _, ply in player.Iterator() do
			if not ply:Alive() then continue end
			ply:SetSuppressPickupNotices(true)
			ply.noSound = true

			if ply:Team() == 0 then
				ply:SetPlayerClass("bloodz")
				zb.GiveRole(ply, "Bloodz", Color(190,0,0))
				ply:SetNetVar("CurPluv", "pluvred")
			else
				ply:SetPlayerClass("groove")
				zb.GiveRole(ply, "Groove", Color(0,190,0))
				ply:SetNetVar("CurPluv", "pluvgreen")
			end

			ply:SetNetVar("Accessories", "")
			if ply.CurAppearance then
				ply.CurAppearance.AAttachments = ""
			end

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
    if not swatSpawned and (CurTime() - zb.ROUND_BEGIN) >= 120 then
        local deadPlayers = {}

        for _, ply in player.Iterator() do
            if not ply:Alive() and ply:Team() != TEAM_SPECTATOR then
                table.insert(deadPlayers, ply)
            end
        end

		local startpos = self.TPoints and #self.TPoints > 0 and self.TPoints[1].pos or zb:GetRandomSpawn()

		for i = 1, math.min(4, #deadPlayers) do
            local ply = deadPlayers[i]

            //if self.TPoints and #self.TPoints > 0 then
                ply:Spawn()
				ply:SetTeam(2)
				if !startpos then
					startpos = ply:GetPos()
				else
					hg.tpPlayer(startpos, ply, i, 0)
				end

                ply:SetPlayerClass("swat")
				zb.GiveRole(ply, "SWAT", Color(0,0,122))
				local gun = ply:Give("weapon_ar15")
                ply:GiveAmmo(gun:GetMaxClip1() * 3, gun:GetPrimaryAmmoType(), true)
                ply:Give("weapon_medkit_sh")
                ply:Give("weapon_tourniquet")
                ply:Give("weapon_walkie_talkie")
                ply:Give("weapon_hg_flashbang_tpik")
                hg.AddArmor(ply, "ent_armor_helmet1")
                hg.AddArmor(ply, "ent_armor_vest4")

                local hands = ply:Give("weapon_hands_sh")
                ply:SelectWeapon("weapon_hands_sh")
            //end
        end

        swatSpawned = true
    end
end

function MODE:GetTeamSpawn()
	return zb.TranslatePointsToVectors(zb.GetMapPoints( "HMCD_TDM_T" )), zb.TranslatePointsToVectors(zb.GetMapPoints( "HMCD_TDM_CT" ))
end

function MODE:CanSpawn()
end

util.AddNetworkString("gwars_roundend")
function MODE:EndRound()
	timer.Simple(2,function()
		net.Start("gwars_roundend")
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

local GWARS_MODE = MODE

util.AddNetworkString("gwars_open_buymenu")
util.AddNetworkString("gwars_buyitem")

function MODE:ShowSpare1(ply)
	if not ply:Alive() then return end
	if ply:Team() != 0 and ply:Team() != 1 then return end
	if ((zb.ROUND_START or 0) + 40 < CurTime()) then ply:ChatPrint("Time's up!") return end

	net.Start("gwars_open_buymenu")
	net.Send(ply)
end

local function buyItem(ply, class, silent)
	local function notify(msg)
		if silent then return end
		ply:ChatPrint(msg)
	end

	if not ply:Alive() then return false end
	if ply:Team() != 0 and ply:Team() != 1 then return false end
	if ((zb.ROUND_START or 0) + 40 < CurTime()) then notify("Time's up!") return false end
	if not isstring(class) or #class > 64 then return false end

	local buyList = GWARS_MODE.BuyList
	if not buyList then return false end

	local item
	for _, category in ipairs(buyList) do
		for _, it in ipairs(category.items) do
			if it.class == class then
				item = it
				break
			end
		end
		if item then break end
	end
	if not item then return false end
	if item.team and item.team != ply:Team() then return false end

	ply.GWARS_PurchasedItems = ply.GWARS_PurchasedItems or {}
	if ply.GWARS_PurchasedItems[class] then
		return false
	end

	local money = ply:GetNWInt("GWARS_Money", 0)
	if money < item.price then notify("Not enough money.") return false end
	ply:SetNWInt("GWARS_Money", money - item.price)
	ply.GWARS_PurchasedItems[class] = true

	if item.kind == "armor" then
		hg.AddArmor(ply, class)
	else
		local wep = ply:Give(class)
		if IsValid(wep) then
			local ammoType = wep:GetPrimaryAmmoType()
			local clip = wep:GetMaxClip1()
			if ammoType >= 0 and clip > 0 then
				ply:GiveAmmo(clip * 3, ammoType)
			end
		end
	end

	ply:EmitSound("items/itempickup.wav")
	return true
end

net.Receive("gwars_buyitem", function(len, ply)
	local class = net.ReadString()
	buyItem(ply, class)
end)

util.AddNetworkString("gwars_buypreset")
net.Receive("gwars_buypreset", function(len, ply)
	if not ply:Alive() then return end
	if ply:Team() != 0 and ply:Team() != 1 then return end
	if ((zb.ROUND_START or 0) + 40 < CurTime()) then ply:ChatPrint("Time's up!") return end

	local preset = net.ReadTable()
	if not istable(preset) then return end
	local items = preset.items
	if not istable(items) or #items == 0 or #items > 48 then return end

	local bought, total = 0, 0
	for _, class in ipairs(items) do
		if not isstring(class) then continue end
		total = total + 1

		if buyItem(ply, class, true) then
			bought = bought + 1
		end
	end

	ply:ChatPrint("Preset: bought " .. bought .. "/" .. total .. " items.")
end)