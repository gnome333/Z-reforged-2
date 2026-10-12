MODE.name = "gwars"
local MODE = MODE

local playstart
local ended

local MusicVolume = GetConVar("snd_musicvolume")

net.Receive("gwars_start", function()
	surface.PlaySound("zbattle/nigshit.mp3")
	zb.RemoveFade()
	playstart = true
	ended = nil

	sound.PlayFile("sound/music_themes/ghetto_loop.wav", "noblock noplay", function(station)
		if IsValid(station) then
			GWARS_LoopStation = station
			station:SetVolume(1 * MusicVolume:GetFloat())
			station:EnableLooping(true)
		end
	end)

	sound.PlayFile("sound/music_themes/ghetto_police.wav", "noblock noplay", function(station)
		if IsValid(station) then
			GWARS_LoopStation2 = station
			station:SetVolume(1 * MusicVolume:GetFloat())
			station:EnableLooping(true)
		end
	end)

	//music_themes/ghetto_loop.wav
	//music_themes/ghetto_start.wav
	
end)

local teams = {
	[0] = {
		objective = "Kill all groove mazafakas",
		name = "a Bloodz Member",
		color1 = Color(180, 0, 0),
		color2 = Color(180, 0, 0)
	},
	[1] = {
		objective = "Kill all bloodz mazafakas",
		name = "a Groove Member",
		color1 = Color(0, 180, 0),
		color2 = Color(0, 180, 0)
	},
}
local lerpsnd = 0.3
function MODE:RenderScreenspaceEffects()
	if zb.ROUND_START + 7.5 < CurTime() then return end
	local fade = math.Clamp(zb.ROUND_START + 7.5 - CurTime(), 0, 1)
	surface.SetDrawColor(0, 0, 0, 255 * fade)
	surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

surface.CreateFont("timer_Font2", {
	font = "Bahnschrift", 
	size = ScreenScale(12), 
	extended = true, 
	weight = 650,
	antialias = true,
	italic = false
})

function MODE:HUDPaint()
	//if !lply.organism or !lply.organism.fear then return end

	local timeBeforeSWAT = (zb.ROUND_START - CurTime() + 120)
	if timeBeforeSWAT > 0 and zb.ROUND_START + 10.5 < CurTime() then
		local time = string.FormattedTime(timeBeforeSWAT, "%02i:%02i:%02i")
		local text = "00:00:00"
		surface.SetFont("timer_Font2")
		surface.SetDrawColor(255, 255, 255, 255)
		local w, h = surface.GetTextSize(text)
		local w2, h2 = surface.GetTextSize("11:11:11 time left before SWAT arrives!")
		surface.SetTextPos(sw * 0.5 - w2 / 2, sh * 0.05)
		surface.DrawText(time)
		surface.SetTextPos(sw * 0.5 - w2 / 2 + w, sh * 0.05)
		surface.DrawText("time left before SWAT arrives!")
		//draw.SimpleText(" left before SWAT arrives!", "timer_Font2", sw * 0.432, sh * 0.05, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		//draw.SimpleText(time, "timer_Font2", sw * 0.36, sh * 0.05, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	if (lply:Team() == 0 or lply:Team() == 1) and lply:Alive() and ((zb.ROUND_START or 0) + 40 > CurTime()) then
		draw.SimpleText("Press F3 to open buy menu", "ZB_HomicideMedium", sw * 0.5, sh * 0.96, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if zb.ROUND_START + 8 < CurTime() then
		if playstart then
			sound.PlayFile("sound/music_themes/ghetto_start.wav", "noblock noplay", function(station)
				if IsValid(station) then
					station:SetVolume(0.3 * MusicVolume:GetFloat())
					station:Play()
				end
			end)

			playstart = nil
		end

		lerpsnd = LerpFT(0.01, lerpsnd, !ended and (lply:Alive() and lply.organism and !lply.organism.otrub and lply.organism.fear and math.Clamp(lply.organism.fear + 0.3 + (timeBeforeSWAT <= 0 and 2 or 0), 0, 1) or 0.3) or 0)
		
		if zb.ROUND_START + 12 < CurTime() then
			if IsValid(GWARS_LoopStation) then
				GWARS_LoopStation:SetVolume(lerpsnd * MusicVolume:GetFloat())
				GWARS_LoopStation:Play()
				
				if IsValid(GWARS_LoopStation2) then
					GWARS_LoopStation2:SetVolume(0)
					GWARS_LoopStation2:Play()
				end
			end
		end

		if IsValid(GWARS_LoopStation) and GWARS_LoopStation:GetState() == GMOD_CHANNEL_PLAYING then
			GWARS_LoopStation:SetVolume(lerpsnd * MusicVolume:GetFloat())
		end
	
		if timeBeforeSWAT <= 0 then
			if IsValid(GWARS_LoopStation2) then
				GWARS_LoopStation2:SetVolume(lerpsnd * MusicVolume:GetFloat())
			end
			
			if IsValid(GWARS_LoopStation) then
				GWARS_LoopStation:SetVolume(0)
			end
		end
	end

	if zb.ROUND_START + 8.5 < CurTime() then return end

	if not lply:Alive() then return end
	zb.RemoveFade()
	local fade = math.Clamp(zb.ROUND_START + 8 - CurTime(), 0, 1)
	local team_ = lply:Team()
	draw.SimpleText("ZBattle | Gang Wars", "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.1, Color(0, 162, 255, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	local Rolename = teams[team_].name
	local ColorRole = teams[team_].color1
	ColorRole.a = 255 * fade
	draw.SimpleText("You are " .. Rolename, "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.5, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	local Objective = teams[team_].objective
	local ColorObj = teams[team_].color2
	ColorObj.a = 255 * fade
	draw.SimpleText(Objective, "ZB_HomicideMedium", sw * 0.5, sh * 0.9, ColorObj, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if hg.PluvTown.Active then
		surface.SetMaterial(hg.PluvTown.PluvMadness)
		surface.SetDrawColor(255, 255, 255, math.random(175, 255) * fade / 2)
		surface.DrawTexturedRect(sw * 0.25, sh * 0.44 - ScreenScale(15), sw / 2, ScreenScale(30))

		draw.SimpleText("SOMEWHERE IN PLUVTOWN", "ZB_ScrappersLarge", sw / 2, sh * 0.44 - ScreenScale(2), Color(0, 0, 0, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

local CreateEndMenu
net.Receive("gwars_roundend", function()
	ended = true
	CreateEndMenu()
end)

local colGray = Color(85, 85, 85, 255)
local colRed = Color(130, 10, 10)
local colRedUp = Color(160, 30, 30)
local colBlue = Color(10, 10, 160)
local colBlueUp = Color(40, 40, 160)
local col = Color(255, 255, 255, 255)
local colSpect1 = Color(75, 75, 75, 255)
local colSpect2 = Color(255, 255, 255)
local colorBG = Color(55, 55, 55, 255)
local colorBGBlacky = Color(40, 40, 40, 255)
local blurMat = Material("pp/blurscreen")
local Dynamic = 0
BlurBackground = BlurBackground or hg.DrawBlur

if IsValid(hmcdEndMenu) then
	hmcdEndMenu:Remove()
	hmcdEndMenu = nil
end

CreateEndMenu = function()
	if IsValid(hmcdEndMenu) then
		hmcdEndMenu:Remove()
		hmcdEndMenu = nil
	end

	Dynamic = 0
	hmcdEndMenu = vgui.Create("ZFrame")
	surface.PlaySound("ambient/alarms/warningbell1.wav")
	local sizeX, sizeY = ScrW() / 2.5, ScrH() / 1.2
	local posX, posY = ScrW() / 1.3 - sizeX / 2, ScrH() / 2 - sizeY / 2
	hmcdEndMenu:SetPos(posX, posY)
	hmcdEndMenu:SetSize(sizeX, sizeY)
	--hmcdEndMenu:SetBackgroundColor(colGray)
	hmcdEndMenu:MakePopup()
	hmcdEndMenu:SetKeyboardInputEnabled(false)
	hmcdEndMenu:ShowCloseButton(false)
	local closebutton = vgui.Create("DButton", hmcdEndMenu)
	closebutton:SetPos(5, 5)
	closebutton:SetSize(ScrW() / 20, ScrH() / 30)
	closebutton:SetText("")
	closebutton.DoClick = function()
		if IsValid(hmcdEndMenu) then
			hmcdEndMenu:Close()
			hmcdEndMenu = nil
		end
	end

	closebutton.Paint = function(self, w, h)
		surface.SetDrawColor(122, 122, 122, 255)
		surface.DrawOutlinedRect(0, 0, w, h, 2.5)
		surface.SetFont("ZB_InterfaceMedium")
		surface.SetTextColor(col.r, col.g, col.b, col.a)
		local lengthX, lengthY = surface.GetTextSize("Close")
		surface.SetTextPos(lengthX - lengthX / 1.1, 4)
		surface.DrawText("Close")
	end

	hmcdEndMenu.Paint = function(self, w, h)
		BlurBackground(self)
		surface.SetFont("ZB_InterfaceMediumLarge")
		surface.SetTextColor(col.r, col.g, col.b, col.a)
		local lengthX, lengthY = surface.GetTextSize("Players:")
		surface.SetTextPos(w / 2 - lengthX / 2, 20)
		surface.DrawText("Players:")
		surface.SetDrawColor(255, 0, 0, 128)
		surface.DrawOutlinedRect(0, 0, w, h, 2.5)
	end

	-- PLAYERS
	local DScrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
	DScrollPanel:SetPos(10, 80)
	DScrollPanel:SetSize(sizeX - 20, sizeY - 90)
	function DScrollPanel:Paint(w, h)
		BlurBackground(self)
		surface.SetDrawColor(255, 0, 0, 128)
		surface.DrawOutlinedRect(0, 0, w, h, 2.5)
	end

	for i, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		local but = vgui.Create("DButton", DScrollPanel)
		but:SetSize(100, 50)
		but:Dock(TOP)
		but:DockMargin(8, 6, 8, -1)
		but:SetText("")
		but.Paint = function(self, w, h)
			local col1 = (ply:Alive() and colRed) or colGray
			local col2 = (ply:Alive() and colRedUp) or colSpect1
			surface.SetDrawColor(col1.r, col1.g, col1.b, col1.a)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(col2.r, col2.g, col2.b, col2.a)
			surface.DrawRect(0, h / 2, w, h / 2)
			local col = ply:GetPlayerColor():ToColor()
			surface.SetFont("ZB_InterfaceMediumLarge")
			local lengthX, lengthY = surface.GetTextSize(ply:GetPlayerName() or "He quited...")
			surface.SetTextColor(0, 0, 0, 255)
			surface.SetTextPos(w / 2 + 1, h / 2 - lengthY / 2 + 1)
			surface.DrawText(ply:GetPlayerName() or "He quited...")
			surface.SetTextColor(col.r, col.g, col.b, col.a)
			surface.SetTextPos(w / 2, h / 2 - lengthY / 2)
			surface.DrawText(ply:GetPlayerName() or "He quited...")
			local col = colSpect2
			surface.SetFont("ZB_InterfaceMediumLarge")
			surface.SetTextColor(col.r, col.g, col.b, col.a)
			local lengthX, lengthY = surface.GetTextSize(ply:GetPlayerName() or "He quited...")
			surface.SetTextPos(15, h / 2 - lengthY / 2)
			surface.DrawText((ply:Name() .. (not ply:Alive() and " - died" or "")) or "He quited...")
			surface.SetFont("ZB_InterfaceMediumLarge")
			surface.SetTextColor(col.r, col.g, col.b, col.a)
			local lengthX, lengthY = surface.GetTextSize(ply:Frags() or "He quited...")
			surface.SetTextPos(w - lengthX - 15, h / 2 - lengthY / 2)
			surface.DrawText(ply:Frags() or "He quited...")
		end

		function but:DoClick()
			if ply:IsBot() then
				chat.AddText(Color(255, 0, 0), "no, you can't")
				return
			end

			gui.OpenURL("https://steamcommunity.com/profiles/" .. ply:SteamID64())
		end

		DScrollPanel:AddItem(but)
	end
	return true
end

function MODE:RoundStart()
	if IsValid(hmcdEndMenu) then
		hmcdEndMenu:Remove()
		hmcdEndMenu = nil
	end
end

surface.CreateFont("GWARS_BUYMENU", {
	font = "Bahnschrift",
	size = ScreenScale(12),
	extended = true,
	weight = 400,
	antialias = true
})

surface.CreateFont("GWARS_BUYDESC", {
	font = "Bahnschrift",
	size = ScreenScale(7),
	extended = true,
	weight = 400,
	antialias = true
})

surface.CreateFont("GWARS_BUYCAT", {
	font = "Bahnschrift",
	size = ScreenScale(6),
	extended = true,
	weight = 400,
	antialias = true
})

local gradMat = Material("vgui/gradient-l")
local GWARS_OpenedBuyMenu

local function GWARS_TeamColor()
	if lply:Team() == 1 then return Color(0, 190, 0) end
	return Color(190, 0, 0)
end

local function OpenGWARSBuyMenu()
	if IsValid(GWARS_OpenedBuyMenu) then
		GWARS_OpenedBuyMenu:Remove()
		GWARS_OpenedBuyMenu = nil
	end

	local StartTime = zb.ROUND_START or CurTime()
	if not lply:Alive() or StartTime + 40 < CurTime() then return end
	if lply:Team() != 0 and lply:Team() != 1 then return end

	local accent = GWARS_TeamColor()

	GWARS_OpenedBuyMenu = vgui.Create("ZFrame")
	local Frame = GWARS_OpenedBuyMenu
	Frame:SetSize(ScrW() * 0.35, ScrH() * 0.85)
	Frame:Center()
	Frame:MakePopup()
	Frame:SetTitle("Gang Wars Buy Menu")

	Frame.Paint = function(self, w, h)
		BlurBackground(self)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 160)
		surface.DrawOutlinedRect(0, 0, w, h, 2.5)
	end

	local Sheet = vgui.Create("DPropertySheet", Frame)
	Sheet:Dock(FILL)
	Sheet:SetTextInset(50)
	Sheet.Paint = function() end
	Sheet.tabScroller:SetOverlap(0)
	Sheet.tabScroller:DockMargin(8, 0, 8, 0)
	Sheet:SetFadeTime(0.1)

	Sheet.OnActiveTabChanged = function(self, old, new)
		if IsValid(old) then
			old:SetTextStyleColor(Color(255, 255, 255, 150))
			old:UpdateFGColor()
		end
		if IsValid(new) then
			new:SetTextStyleColor(color_white)
			new:UpdateFGColor()
		end
	end

	for _, category in ipairs(MODE.BuyList) do
		local CategoryPanel = vgui.Create("DScrollPanel")
		CategoryPanel.Paint = function() end

		for _, item in ipairs(category.items) do
			local ItemPanel = vgui.Create("DPanel", CategoryPanel)
			ItemPanel:SetSize(0, ScrH() * 0.1)
			ItemPanel:Dock(TOP)
			ItemPanel:DockMargin(0, 8, 0, 0)
			ItemPanel.Paint = function(self, w, h)
				surface.SetDrawColor(0, 0, 0, 155)
				surface.DrawRect(0, 0, w, h, 2.5)
				surface.SetDrawColor(accent.r, accent.g, accent.b, 128)
				surface.DrawOutlinedRect(0, 0, w, h, 2.5)
				surface.SetDrawColor(accent.r, accent.g, accent.b, 55)
				surface.SetMaterial(gradMat)
				surface.DrawTexturedRect(0, 0, w / 1.5, h)
			end

			local iconPath
			local iconSquare = false
			local weapon = weapons.GetStored(item.class)
			if weapon != nil and ((weapon.WepSelectIcon2 and weapon.WepSelectIcon2:GetName()) or weapon.IconOverride) then
				iconPath = (weapon.WepSelectIcon2 and weapon.WepSelectIcon2:GetName() .. ".png") or weapon.IconOverride
			elseif item.kind == "armor" then
				iconSquare = true
				local key = string.Replace(item.class, "ent_armor_", "")
				local path = hg.armorIcons and hg.armorIcons[key]
				if path and not Material(path):IsError() then
					iconPath = path
				else
					local ent = scripted_ents.GetStored(item.class)
					local model = ent and ent.t and ent.t.Model
					if model then
						iconPath = "spawnicons/" .. string.StripExtension(model) .. ".png"
					end
				end
			end

			if iconPath then
				local icon = vgui.Create("DImage", ItemPanel)
				icon:SetSize(ScrH() * (iconSquare and 0.1 or 0.17), ScrH() * 0.1)
				icon:Dock(LEFT)
				icon:DockMargin(5, 5, 5, 5)
				icon:SetImage(iconPath)
			end

			local ItemButton = vgui.Create("DPanel", ItemPanel)
			ItemButton:Dock(FILL)
			ItemButton:DockMargin(0, 5, 0, 0)
			ItemButton.Paint = function() end

			local name = vgui.Create("DLabel", ItemButton)
			name:SetText(item.name)
			name:DockMargin(10, 0, 5, 0)
			name:Dock(TOP)
			name:SetFont("GWARS_BUYMENU")
			name:SetSize(ScrW() * 0.5, ScrH() * 0.04)

			local price = vgui.Create("DLabel", ItemButton)
			price:SetText("Price: $" .. item.price)
			price:DockMargin(10, 0, 5, 0)
			price:Dock(TOP)
			price:SetTextColor(Color(155, 200, 155))
			price:SetFont("GWARS_BUYDESC")
			price:SetSize(ScrW() * 0.5, ScrH() * 0.02)

			local BuyBtn = vgui.Create("DButton", ItemButton)
			BuyBtn:DockMargin(10, 5, 10, 10)
			BuyBtn:Dock(LEFT)
			BuyBtn:SetText("Buy")
			BuyBtn:SetTextColor(Color(200, 200, 200))
			BuyBtn:SetFont("GWARS_BUYDESC")
			BuyBtn:SetHeight(ScrH() * 0.025)
			BuyBtn.Paint = function(self, w, h)
				surface.SetDrawColor(0, 0, 0, 155)
				surface.DrawRect(0, 0, w, h, 2.5)
				surface.SetDrawColor(accent.r, accent.g, accent.b, self:IsHovered() and 230 or 128)
				surface.DrawOutlinedRect(0, 0, w, h, 2.5)
			end
			BuyBtn.GWARS_Class = item.class

			function BuyBtn:DoClick()
				net.Start("gwars_buyitem")
					net.WriteString(self.GWARS_Class)
				net.SendToServer()
			end
		end

		local tab = Sheet:AddSheet(category.category, CategoryPanel)
		local Tab = tab.Tab
		Tab:SetFont("GWARS_BUYCAT")
		Tab:SetContentAlignment(5)
		Tab.Paint = function() end
		Tab.UpdateColours = function(self)
			self:SetTextStyleColor(self:IsActive() and color_white or Color(255, 255, 255, 150))
		end
		Tab.ApplySchemeSettings = function(self)
			self:SetTextInset(0, 4)
			local textW = self:GetContentSize()
			self:SetSize(textW + 10, 24)
			self:UpdateColours()
			self:UpdateFGColor()
		end
		Tab:ApplySchemeSettings()
	end

	local timeLbl = vgui.Create("DLabel", Frame)
	timeLbl:SetText("Time Left: " .. string.FormattedTime(StartTime + 40 - CurTime(), "%02i:%02i:%02i"))
	timeLbl:DockMargin(10, 0, 10, 10)
	timeLbl:Dock(BOTTOM)
	timeLbl:SetTextColor(Color(255, 255, 255))
	timeLbl:SetFont("GWARS_BUYDESC")
	timeLbl:SetSize(0, ScrH() * 0.015)

	function timeLbl:Think()
		if not lply:Alive() or StartTime + 40 < CurTime() then
			if IsValid(GWARS_OpenedBuyMenu) then
				GWARS_OpenedBuyMenu:Remove()
				GWARS_OpenedBuyMenu = nil
			end
			return
		end
		self:SetText("Time Left: " .. string.FormattedTime(StartTime + 40 - CurTime(), "%02i:%02i:%02i"))
	end

	local cashLbl = vgui.Create("DLabel", Frame)
	cashLbl:DockMargin(10, 5, 10, 5)
	cashLbl:Dock(BOTTOM)
	cashLbl:SetTextColor(Color(61, 173, 61))
	cashLbl:SetFont("GWARS_BUYDESC")
	cashLbl:SetSize(0, ScrH() * 0.02)

	function cashLbl:Think()
		self:SetText("Cash: $" .. lply:GetNWInt("GWARS_Money", 0))
	end
end

net.Receive("gwars_open_buymenu", function()
	OpenGWARSBuyMenu()
end)