local MODE = MODE

MODE.base = "tdm"
MODE.name = "nswar"
MODE.PrintName = "Nanosuit War"
MODE.Description = "Raptor Team vs КНА. Both sides are equipped with nanosuits."

local buyBlacklist = {
	Equipment = true,
	Melee = true,
	Medical = true,
}

function MODE:AfterBaseInheritance()
	local items = {}
	local maxPriority = 0
	for cat, tbl in pairs(self.BuyItems) do
		if not buyBlacklist[cat] then
			items[cat] = tbl
			if (tbl.Priority or 0) > maxPriority then maxPriority = tbl.Priority end
		end
	end
	self.BuyItems = items

	self.BuyItems.Other = {
		Priority = maxPriority + 1,
		["Bow"] = {
			Type = "Weapon",
			ItemClass = "weapon_hg_bow",
			Price = 3000,
			Category = "Other",
			Attachments = {},
		}
	}
end
