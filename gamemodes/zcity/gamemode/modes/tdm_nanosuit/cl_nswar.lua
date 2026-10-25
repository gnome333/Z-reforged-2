local MODE = MODE

MODE.name = "nswar"

local teams = {
	[0] = {
		objective = "Eliminate the enemy team.",
		name = "КНА",
		color1 = Color(245, 200, 50),
		color2 = Color(245, 200, 50),
	},
	[1] = {
		objective = "Eliminate the enemy team.",
		name = "Raptor Team",
		color1 = Color(90, 255, 190),
		color2 = Color(90, 255, 190),
	},
}

local colorWhite = Color(255, 255, 255)
local colorBlue = Color(0, 162, 255)

function MODE:HUDPaint()
	local StartTime = zb.ROUND_START or CurTime()
	self:AddHudPaint()

	local lp = LocalPlayer()
	local team_ = IsValid(lp) and lp:Team() or -1
	local info = teams[team_]

	if StartTime + 20 > CurTime() then
		draw.SimpleText(string.FormattedTime(StartTime + 20 - CurTime(), "%02i:%02i:%02i"), "ZB_HomicideMedium", sw * 0.5, sh * 0.95, colorWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("Press F3 to open buymenu", "ZB_HomicideMedium", sw * 0.5, sh * 0.9, colorWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		local time = string.FormattedTime(math.max(StartTime + (zb.ROUND_TIME or 400) - CurTime(), 0), "%02i:%02i:%02i")
		draw.SimpleText(time, "ZB_HomicideMedium", sw * 0.5, sh * 0.95, colorWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if StartTime + 20 < CurTime() then return end

	if not IsValid(lp) or not lp:Alive() then return end
	zb.RemoveFade()
	local fade = math.Clamp(StartTime + 8 - CurTime(), 0, 1)

	draw.SimpleText("ZBattle | " .. (self.PrintName or "Nanosuit War"), "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.1, Color(colorBlue.r, colorBlue.g, colorBlue.b, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if not info then return end

	draw.SimpleText("You are " .. info.name, "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.5, Color(info.color1.r, info.color1.g, info.color1.b, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(info.objective, "ZB_HomicideMedium", sw * 0.5, sh * 0.9, Color(info.color2.r, info.color2.g, info.color2.b, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("StartCommand", "NSWar_DisallowMoveOrShoting", function(ply, mv)
	if zb.CROUND == "nswar" and (zb.ROUND_START or 0) + 20 > CurTime() then
		mv:RemoveKey(IN_ATTACK)
		mv:RemoveKey(IN_ATTACK2)
		mv:RemoveKey(IN_FORWARD)
		mv:RemoveKey(IN_BACK)
		mv:RemoveKey(IN_MOVELEFT)
		mv:RemoveKey(IN_MOVERIGHT)
	end
end)

local shopFallbackMint = {Shop = Color(90, 255, 190, 128), Price = Color(120, 235, 190, 255)}
local shopFallbackYellow = {Shop = Color(255, 200, 40, 128), Price = Color(245, 205, 90, 255)}

local function getShopTheme()
	local lp = LocalPlayer()
	local variant = IsValid(lp) and lp:Team() == 0 and 1 or 0
	local nsh = hg.NanoSuit
	if nsh and nsh.Themes and nsh.Themes[variant] then return nsh.Themes[variant] end
	if variant == 1 then return shopFallbackYellow end
	return shopFallbackMint
end

local gradient_l = Material("vgui/gradient-l")

local function PaintFrame(self, w, h)
	hg.DrawBlur(self)

	local th = getShopTheme()
	surface.SetDrawColor(th.Shop)
	surface.DrawOutlinedRect(0, 0, w, h, 2.5)
end

local function PaintPanel(self, w, h)
	surface.SetDrawColor(0, 0, 0, 155)
	surface.DrawRect(0, 0, w, h, 2.5)

	local th = getShopTheme()
	surface.SetDrawColor(th.Shop)
	surface.DrawOutlinedRect(0, 0, w, h, 2.5)
end

local function PaintPanel1(self, w, h)
	surface.SetDrawColor(0, 0, 0, 155)
	surface.DrawRect(0, 0, w, h, 2.5)

	local th = getShopTheme()
	surface.SetDrawColor(th.Shop)
	surface.DrawOutlinedRect(0, 0, w, h, 2.5)
	draw.RoundedBox(0, 2.5, 2.5, w - 5, h - 5, Color(0, 0, 0, 140))
	surface.SetDrawColor(th.Shop.r, th.Shop.g, th.Shop.b, 55)
	surface.SetMaterial(gradient_l)
	surface.DrawTexturedRect(0, 0, w / 1.5, h)
end

local function PaintPanel2(self, w, h)
	local th = getShopTheme()
	surface.SetDrawColor(th.Shop.r, th.Shop.g, th.Shop.b, 25)
	surface.SetMaterial(gradient_l)
	surface.DrawTexturedRect(0, 0, w * 1.2, h)
end

local rtabFunc = function(self)
	local ExtraInset = 10

	if (self.Image) then
		ExtraInset = ExtraInset + self.Image:GetWide()
	end

	self:SetTextInset(ExtraInset, 2)
	local w, h = self:GetContentSize()
	h = self:GetTabHeight()

	self:SetSize(w + 10, h + 7)

	DLabel.ApplySchemeSettings(self)
end

local RefillPrices = {
	weapon_bandage_sh = 100,
	weapon_bigbandage_sh = 200,
	weapon_medkit_sh = 350,
}

local function GetRefillPrice(class)
	local price = RefillPrices[class]
	if not price then return end

	local wep = LocalPlayer():GetWeapon(class)
	if not IsValid(wep) then return end

	local vals = wep:GetNetVar("modeValues")
	local defs = wep.modeValuesdef
	if not istable(vals) or not istable(defs) then return end

	for i, def in ipairs(defs) do
		if (vals[i] or 0) < (istable(def) and def[1] or def) then return price end
	end
end

local NSW_BuyMenu

local function OpenBuyMenu()
	if IsValid(NSW_BuyMenu) then
		NSW_BuyMenu:Remove()
		NSW_BuyMenu = nil
	end

	local StartTime = zb.ROUND_START or CurTime()
	if not LocalPlayer():Alive() or StartTime + 40 < CurTime() then return end

	local th = getShopTheme()

	NSW_BuyMenu = vgui.Create("ZFrame")
	local Frame = NSW_BuyMenu
	Frame:SetSize(ScrW() * 0.35, ScrH() * 0.85)
	Frame:Center()
	Frame:MakePopup()
	Frame:SetTitle("Buy menu")
	Frame.Paint = PaintFrame

	local Sheet = vgui.Create("DPropertySheet", Frame)
	Sheet:Dock(FILL)
	Sheet:SetTextInset(50)
	Sheet.Paint = function() end
	Sheet.tabScroller:SetOverlap(0)
	Sheet.tabScroller:DockMargin(8, 0, 8, 0)
	Sheet:SetFadeTime(0.1)

	for k, category in SortedPairsByMemberValue(MODE.BuyItems, "Priority") do
		local CategoryPanel = vgui.Create("DScrollPanel", Sheet)
		CategoryPanel.Paint = function() end
		local itemcount = 0
		for n, Item in pairs(category) do
			if n == "Priority" then continue end
			if Item.TeamBased != nil and Item.TeamBased != LocalPlayer():Team() then continue end
			itemcount = itemcount + 1
			local weapon = weapons.GetStored(Item.ItemClass)
			local ent = scripted_ents.GetStored(Item.ItemClass)

			local ItemPanel = vgui.Create("DPanel", CategoryPanel)
			ItemPanel:SetSize(0, ScrH() * 0.1)
			ItemPanel:Dock(TOP)
			ItemPanel:DockMargin(0, 8, 0, 0)
			ItemPanel.Paint = PaintPanel1

			if (weapon ~= nil and ((weapon.WepSelectIcon2 and weapon.WepSelectIcon2:GetName()) or weapon.IconOverride)) or ((ent and ent.t.IconOverride)) then
				local ItemButton = vgui.Create("DImage", ItemPanel)
				local bBox = ((ent and ent.t.IconOverride) or weapon ~= nil and weapon.WepSelectIcon2box)
				ItemButton:SetSize(ScrH() * ((bBox and 0.1) or 0.17), ScrH() * 0.1)
				ItemButton:Dock(LEFT)
				local boxed = ScrH() * 0.07 / 2
				ItemButton:DockMargin(5 + (bBox and boxed or 0), 5, 5 + (bBox and boxed or 0), 5)
				ItemButton:SetImage((weapon ~= nil and ((weapon.WepSelectIcon2 and weapon.WepSelectIcon2:GetName() .. ".png") or weapon.IconOverride)) or ((ent and ent.t.IconOverride) or "none"))
			end

			local ItemButton = vgui.Create("DPanel", ItemPanel)
			ItemButton:Dock(FILL)
			ItemButton:DockMargin(0, 5, 0, 0)
			ItemButton.Paint = function() end

			local lbl = vgui.Create("DLabel", ItemButton)
			lbl:SetText(n)
			lbl:DockMargin(10, 0, 5, 0)
			lbl:Dock(TOP)
			lbl:SetFont("ZB_TDM_MENU")
			lbl:SetSize(ScrW() * 0.5, ScrH() * 0.04)

			local lbl = vgui.Create("DLabel", ItemButton)
			local refillPrice = GetRefillPrice(Item.ItemClass)
			lbl:SetText(refillPrice and ("Refill: $" .. refillPrice) or ("Price: $" .. Item.Price))
			lbl:DockMargin(10, 0, 5, 0)
			lbl:Dock(TOP)
			lbl:SetTextColor(th.Price)
			lbl:SetFont("ZB_TDM_DESC")
			lbl:SetSize(ScrW() * 0.5, ScrH() * 0.02)

			local BuyBtn = vgui.Create("DButton", ItemButton)
			BuyBtn:DockMargin(10, 5, 10, 10)
			BuyBtn:Dock(LEFT)
			BuyBtn:SetText("Buy")
			BuyBtn:SetTextColor(Color(200, 200, 200))
			BuyBtn:SetFont("ZB_TDM_DESC")
			BuyBtn:SetHeight(ScrH() * 0.025)
			BuyBtn.Paint = PaintPanel
			BuyBtn.Item = {k, n}

			function BuyBtn:DoClick()
				net.Start("tdm_buyitem")
					net.WriteTable(self.Item)
				net.SendToServer()
			end

			if weapon then
				local ammo = weapon.Primary.Ammo != "none" and weapon.Primary.Ammo or weapon.Ammo or (weapons.GetStored(weapon.Base) and weapons.GetStored(weapon.Base).Primary.Ammo)

				if hg.ammotypeshuy[ammo] then
					local amm = vgui.Create("DButton", ItemButton)
					amm:DockMargin(10, 5, 10, 10)
					amm:Dock(LEFT)
					amm:SetText(ammo)
					amm:SetTextColor(Color(200, 200, 200))
					amm:SetFont("ZB_TDM_DESCSMALL")

					surface.SetFont("ZB_TDM_DESCSMALL")
					local w, h = surface.GetTextSize(ammo)

					amm:SetHeight(ScrH() * 0.025)
					amm:SetWidth(w + 7)
					local ammo2 = "ent_ammo_" .. hg.ammotypeshuy[ammo].name
					local name
					for name2, ammoEntry in pairs(MODE.BuyItems["Ammo"] or {}) do
						if not istable(ammoEntry) then continue end
						if ammoEntry.ItemClass == ammo2 then
							name = name2
						end
					end

					amm.huy = {"Ammo", name}

					function amm:DoClick()
						if not self.huy[2] then return end

						net.Start("tdm_buyitem")
							net.WriteTable(self.huy)
						net.SendToServer()
					end

					amm.Paint = PaintPanel
				end
			end

			if Item.Attachments and #Item.Attachments > 0 then
				local ItemAtt = vgui.Create("DGrid", ItemPanel)
				local ItemIcon = math.ceil(ScrH() * 0.06)
				ItemAtt:Dock(RIGHT)
				ItemAtt:DockMargin(0, 5, 0, 0)
				ItemAtt:SetCols(4)
				ItemAtt:SetColWide(ItemIcon)
				ItemAtt:SetRowHeight(ItemIcon)
				ItemAtt.Paint = function() end
				for id, AttachN in pairs(Item.Attachments) do
					local ico = hg.attachmentsIcons[AttachN]
					local Attach = vgui.Create("DImageButton")
					Attach:SetImage(ico)
					Attach:SetSize(ItemIcon - 5, ItemIcon - 5)

					Attach.Attachment = {k, n, AttachN}

					function Attach:DoClick()
						net.Start("tdm_buyitem")
							net.WriteTable(self.Attachment)
						net.SendToServer()
					end

					Attach.Paint = PaintPanel2
					ItemAtt:AddItem(Attach)
				end
			end
		end
		if itemcount > 0 then
			local tab = Sheet:AddSheet(k, CategoryPanel)
			local rTab = tab["Tab"]
			rTab.Paint = PaintPanel
			rTab:SetFont("ZB_TDM_CATEGORY")
			rTab.ApplySchemeSettings = rtabFunc
		end
	end

	local lbl = vgui.Create("DLabel", Frame)
	lbl:SetText("Time Left: " .. string.FormattedTime(StartTime + 40 - CurTime(), "%02i:%02i:%02i"))
	lbl:DockMargin(10, 0, 10, 10)
	lbl:Dock(BOTTOM)
	lbl:SetTextColor(Color(255, 255, 255))
	lbl:SetFont("ZB_TDM_DESC")
	lbl:SetSize(0, ScrH() * 0.015)

	function lbl:Think()
		if not LocalPlayer():Alive() or StartTime + 40 < CurTime() then
			if IsValid(NSW_BuyMenu) then NSW_BuyMenu:Remove() end
			NSW_BuyMenu = nil
			return
		end
		self:SetText("Time Left: " .. string.FormattedTime(StartTime + 40 - CurTime(), "%02i:%02i:%02i"))
	end

	local lbl = vgui.Create("DLabel", Frame)
	lbl:SetText("Cash: $" .. LocalPlayer():GetNWInt("TDM_Money", 0))
	lbl:DockMargin(10, 5, 10, 5)
	lbl:Dock(BOTTOM)
	lbl:SetTextColor(th.Price)
	lbl:SetFont("ZB_TDM_DESC")
	lbl:SetSize(0, ScrH() * 0.02)

	function lbl:Think()
		self:SetText("Cash: $" .. LocalPlayer():GetNWInt("TDM_Money", 0))
	end
end

net.Receive("nswar_open_buymenu", function()
	OpenBuyMenu()
end)
