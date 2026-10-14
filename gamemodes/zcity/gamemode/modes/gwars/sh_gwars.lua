local MODE = MODE

zb = zb or {}
--[[zb.Points = zb.Points or {}

zb.Points.HMCD_TDM_CT = zb.Points.HMCD_TDM_CT or {}
zb.Points.HMCD_TDM_CT.Color = Color(0,0,150)
zb.Points.HMCD_TDM_CT.Name = "HMCD_TDM_CT"

zb.Points.HMCD_TDM_T = zb.Points.HMCD_TDM_T or {}
zb.Points.HMCD_TDM_T.Color = Color(150,95,0)
zb.Points.HMCD_TDM_T.Name = "HMCD_TDM_T"]]

MODE.BuyList = {
	{
		category = "Medical",
		items = {
			{ name = "Fentanyl", class = "weapon_fentanyl", price = 550 },
			{ name = "Bandage", class = "weapon_bandage_sh", price = 200 },
			{ name = "Tourniquet", class = "weapon_tourniquet", price = 50 },
		},
	},
	{
		category = "Pistols",
		items = {
			{ name = "PX4 Beretta", class = "weapon_px4beretta", price = 400 },
			{ name = "Beretta M9", class = "weapon_m9beretta", price = 450 },
			{ name = "Glock-17", class = "weapon_glock17", price = 500 },
			{ name = "M1911", class = "weapon_m1911", price = 400 },
			{ name = "TEC-9", class = "weapon_tec9", price = 570 },
			{ name = "CZ 75", class = "weapon_cz75", price = 500 },
			{ name = "CZ 75A", class = "weapon_cz75a", price = 600 },
			{ name = "Revolver", class = "weapon_revolver2", price = 350 },
			{ name = "P22", class = "weapon_p22", price = 300 },
		},
	},
	{
		category = "Carbines",
		items = {
			{ name = "Mini-14", class = "weapon_mini14", price = 1150, team = 0 },
			{ name = "AR-15", class = "weapon_ar15", price = 1350, team = 1 },
		},
	},
	{
		category = "SMGs",
		items = {
			{ name = "Skorpion", class = "weapon_skorpion", price = 750 },
			{ name = "Uzi", class = "weapon_uzi", price = 700 },
			{ name = "MAC-11", class = "weapon_mac11", price = 800 },
		},
	},
	{
		category = "Shotguns",
		items = {
			{ name = "Remington-870", class = "weapon_remington870", price = 1350, team = 0 },
			{ name = "Sawed-off IZh-43", class = "weapon_doublebarrel_short", price = 500, team = 0 },
			{ name = "Mossberg 590A1", class = "weapon_m590a1", price = 1250, team = 1 },
			{ name = "IZh-43", class = "weapon_doublebarrel", price = 650, team = 1 },
		},
	},
	{
		category = "Melee",
		items = {
			{ name = "SOG Knife", class = "weapon_sogknife", price = 200 },
			{ name = "Combat knife", class = "weapon_melee", price = 200 },
			{ name = "Machete", class = "weapon_hg_machete", price = 300 },
			{ name = "Hatchet", class = "weapon_hatchet", price = 350 },
			{ name = "Axe", class = "weapon_hg_axe", price = 400 },
		},
	},
	{
		category = "Armor",
		items = {
			{ name = "IIIA Vest", class = "ent_armor_vest3", price = 450, kind = "armor" },
			{ name = "III Vest", class = "ent_armor_vest4", price = 650, kind = "armor" },
		},
	},
}
