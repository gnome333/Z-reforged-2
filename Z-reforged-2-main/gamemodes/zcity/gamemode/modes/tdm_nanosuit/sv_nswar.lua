local MODE = MODE

MODE.name = "nswar"
MODE.StartMoney = 4500
MODE.Chance = 0.04

local function syncVariant(ply)
	if not IsValid(ply) then return end
	local team_ = ply:Team()
	if team_ != 0 and team_ != 1 then return end
	local variant = team_ == 0 and 1 or 0
	if ply:GetNetVar("NS_Variant", 0) != variant then
		ply:SetNetVar("NS_Variant", variant)
	end
end

local function giveLoadout(ply, team_)
	local inv = ply:GetNetVar("Inventory")
	if istable(inv) and istable(inv["Weapons"]) then
		inv["Weapons"]["hg_sling"] = true
		ply:SetNetVar("Inventory", inv)
	end

	ply:SetSuppressPickupNotices(true)
	ply.noSound = true

	ply:Give("weapon_melee")
	if ply.organism then
		ply.organism.allowholster = true
	end

	local Radio = ply:Give("weapon_walkie_talkie")
	if IsValid(Radio) then
		Radio.Frequency = (team_ == 1 and math.Round(math.Rand(88, 95), 1)) or math.Round(math.Rand(100, 108), 1)
	end

	ply:Give("weapon_hands_sh")
	ply:SelectWeapon("weapon_hands_sh")

	timer.Simple(0.1, function()
		if IsValid(ply) then ply.noSound = false end
	end)

	ply:SetSuppressPickupNotices(false)
end

function MODE:Intermission()
	game.CleanUpMap()

	for _, ply in player.Iterator() do
		ply:SetupTeam(ply:Team())

		ply:SetNWInt("TDM_Money", self.StartMoney)

		syncVariant(ply)
	end

	net.Start("tdm_start")
		net.WriteString("nswar")
	net.Broadcast()
end

function MODE:EndRound()
	self.BaseClass.EndRound(self)

	local NS = hg.NanoSuit

	for _, ply in player.Iterator() do
		if NS then NS.Take(ply, true) end

		if ply.PlayerClassName == "nanosuit" then
			ply:SetPlayerClass()
		end
	end
end

function MODE:GiveEquipment()
	timer.Simple(0.1, function()
		for _, ply in player.Iterator() do
			if not IsValid(ply) or not ply:Alive() then continue end

			local team_ = ply:Team()
			if team_ != 0 and team_ != 1 then continue end

			syncVariant(ply)
			ply:SetPlayerClass("nanosuit")

			if team_ == 1 then
				zb.GiveRole(ply, "Raptor Team", Color(60, 235, 165))
			else
				zb.GiveRole(ply, "КНА", Color(245, 200, 50))
			end

			giveLoadout(ply, team_)
		end
	end)
end

function MODE:PlayerSpawn(ply)
	if not IsValid(ply) then return end

	syncVariant(ply)

	timer.Simple(0, function()
		if not IsValid(ply) or not ply:Alive() then return end
		local team_ = ply:Team()
		if team_ != 0 and team_ != 1 then return end

		syncVariant(ply)

		if not ply.PlayerClassName or ply.PlayerClassName == "none" then
			ply:SetPlayerClass("nanosuit")

			if ply:GetNWInt("TDM_Money", 0) <= 0 then
				ply:SetNWInt("TDM_Money", MODE.StartMoney)
				giveLoadout(ply, team_)
			end
		end

		local suit = ply.ns_suit
		if not suit then return end

		local NS = hg.NanoSuit
		if not NS then return end

		local wantModel = NS.GetModel(ply)
		if ply:GetModel() != wantModel then
			ply:SetModel(wantModel)
			ply:SetSubMaterial()
			NS.ResetBodygroups(ply)
			NS.ApplyGlow(ply, suit.Mode != 0)
		end
	end)
end

util.AddNetworkString("nswar_open_buymenu")

function MODE:ShowSpare1(ply)
	if not IsValid(ply) or not ply:Alive() then return end
	net.Start("nswar_open_buymenu")
	net.Send(ply)
end
