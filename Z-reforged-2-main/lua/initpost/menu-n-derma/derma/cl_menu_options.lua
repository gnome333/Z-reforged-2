hg.settings = hg.settings or {}
hg.settings.tbl = hg.settings.tbl or {}

function hg.settings:AddOpt( strCategory, strConVar, strTitle, bDecimals, bString, category )
    self.tbl[strCategory] = self.tbl[strCategory] or {}
    self.tbl[strCategory][strConVar] = { strCategory, strConVar, strTitle, bDecimals or false, bString or false, category }
end
local hg_firstperson_death = CreateClientConVar("hg_firstperson_death", "0", true, false, "Toggle first-person death camera view", 0, 1)
local hg_font = CreateClientConVar("hg_font", "Bahnschrift", true, false, "change every text font to selected because ui customization is cool")
local hg_attachment_draw_distance = CreateClientConVar("hg_attachment_draw_distance", 0, true, nil, "distance to draw attachments", 0, 4096)

xbars = 17
ybars = 30

gradient_l = Material("vgui/gradient-l")

local blur = Material("pp/blurscreen")
local blur2 = Material("effects/shaders/zb_blur" )
local sw, sh = ScrW(), ScrH()

local font = function() -- hg_coolvetica:GetBool() and "Coolvetica" or "Bahnschrift"
    local usefont = "Bahnschrift"

    if hg_font:GetString() != "" then
        usefont = hg_font:GetString()
    end

    return usefont
end

surface.CreateFont("ZCity_setiings_tiny", {
	font = font(),
	size = ScreenScale(7),
	weight = 100
})

surface.CreateFont("ZCity_setiings_fine", {
	font = font(),
	size = ScreenScale(10),
	weight = 100
})

surface.CreateFont("ZCity_setiings_category", {
	font = font(),
	size = ScreenScale(15),
	weight = 100
})


hg.settings:AddOpt("Gameplay","hg_old_notificate", "Old Notifications")
hg.settings:AddOpt("Gameplay","hg_cheats", "Enable Cheats")
hg.settings:AddOpt("Gameplay","hg_showthoughts", "Show thoughts")
hg.settings:AddOpt("Gameplay","hg_hints", "Show hints")
hg.settings:AddOpt("Gameplay","hg_gary", "Center weapon in fake")
hg.settings:AddOpt("Gameplay","hg_deathfadeout", "Death fade out")
--hg_gary
--hg_deathfadeout
if not game.IsDedicated() then
	hg.settings:AddOpt("Server-side settings","hg_toughnpcs", "Tough npcs")
	hg.settings:AddOpt("Server-side settings","hg_thirdperson", "Thirdperson (WIP)")
	hg.settings:AddOpt("Server-side settings","hg_legacycam", "Legacy camera")
	hg.settings:AddOpt("Server-side settings","hg_ragdollcombat", "Ragdoll combat mode")
	hg.settings:AddOpt("Server-side settings","hg_movement_stamina_debuff", "Movement stamina debuff")
	hg.settings:AddOpt("Server-side settings","hg_furcity", "Furcity")
	hg.settings:AddOpt("Server-side settings","hg_appearance_access_for_all", "Appearance full access for all", nil, nil, "bool")
	hg.settings:AddOpt("Server-side settings","hg_healanims", "Heal & food animations")
	hg.settings:AddOpt("Server-side settings","hg_aimtoshoot", "Toggle DarkRP-like shooting system (aim to shoot): 0 - disabled; 1 - hipfire only; 2 - aiming only", nil, nil, "int")
	hg.settings:AddOpt("Server-side settings","hg_slings", "Sling system")
	hg.settings:AddOpt("Server-side settings","hg_allow_gopro", "Allow GoPro-like first-person camera")
	hg.settings:AddOpt("Server-side settings","hg_allow_gopro_pos", "Allow editing GoPro camera position")
	hg.settings:AddOpt("Server-side settings","hg_giveammomul", "Multiply given ammo for weapon spawned from spawnmenu")
	hg.settings:AddOpt("Server-side settings","hg_ixanims", "Toggle Helix-like animations on NPC models for players. Experimental")
	hg.settings:AddOpt("Server-side settings","hg_coolhands", "Give cool hands instead of default hands on spawn")
	hg.settings:AddOpt("Server-side settings","hg_loadcontent", "Toggle loading content to clients using 'resource.AddWorkshop' (need server restart to apply)")
    hg.settings:AddOpt("Server-side settings","homicide_traitoramount", "Homicide: Traitor Amount", nil, nil, "int")
end
--hg_appearance_access_for_all
--hg_furcity
--hg_legacycam
--hg_toughnpcs

hg.settings:AddOpt("Debug","hg_show_hitposmuzzle", "Show weapon hitpos")
hg.settings:AddOpt("Debug","hg_setzoompos", "Edit weapon zoompos, check console for results")
hg.settings:AddOpt("Debug","hg_show_hitbox", "Show hitboxes")

hg.settings:AddOpt("Optimization","hg_potatopc", "Potato PC Mode")
hg.settings:AddOpt("Optimization","hg_anims_draw_distance", "Animations Draw Distance", true, nil, "int")
hg.settings:AddOpt("Optimization","hg_anim_fps", "Animations FPS", nil, nil, "int")
hg.settings:AddOpt("Optimization","hg_attachment_draw_distance", "Attachment Draw Distance", true, nil, "int")
hg.settings:AddOpt("Optimization","hg_maxsmoketrails", "Maximum Smoke Trails", nil, nil, "int")
hg.settings:AddOpt("Optimization","hg_tpik_distance", "TPIK Render Distance", true, nil, "int")

hg.settings:AddOpt("Blood","hg_blood_draw_distance", "Blood Draw Distance")
hg.settings:AddOpt("Blood","hg_blood_fps", "Blood FPS")
hg.settings:AddOpt("Blood","hg_blood_sprites", "Blood Sprites (DISABLED FOR EVERYONE)")
hg.settings:AddOpt("Blood","hg_old_blood", "Old blood")

hg.settings:AddOpt("UI","hg_font", "Set Custom Font", false, true)

hg.settings:AddOpt("Weapons","hg_weaponshotblur_enable", "Shooting Blur")
hg.settings:AddOpt("Weapons","hg_dynamic_mags", "Dynamic Ammo Inspect")
hg.settings:AddOpt("Weapons","hg_zoomsensitivity", "Scope sensitivity")
hg.settings:AddOpt("Weapons","hg_highpitchgunfire", "Toggle high pitched gunfire sounds inside buildings")

hg.settings:AddOpt("View","hg_firstperson_death", "First-Person Death")
hg.settings:AddOpt("View","hg_fov", "Field Of View")
hg.settings:AddOpt("View","hg_newspectate", "Smooth Spectator Camera")
hg.settings:AddOpt("View","hg_cshs_fake", "C'sHS Ragdoll Camera")
hg.settings:AddOpt("View","hg_gun_cam", "Gun Camera (ADMIN ONLY)")
hg.settings:AddOpt("View","hg_nofovzoom", "Disable/Enable FOV Zoom")
hg.settings:AddOpt("View","hg_realismcam", "Realism camera (shitty)")
hg.settings:AddOpt("View","hg_gopro", "GoPro camera")
hg.settings:AddOpt("View","hg_newfakecam", "New fake camera")
hg.settings:AddOpt("View","hg_leancam_mul", "Lean camera mul", true, nil, "int")
hg.settings:AddOpt("View","hg_gun_cam", "Gun camera (WIP Admin only)")
--hg_hints
--hg_leancam_mul
  --hg_newfakecam
hg.settings:AddOpt("Sound","hg_dmusic", "Dynamic Music")
hg.settings:AddOpt("Sound","hg_quietshots", "Enable/Disable Quietshoot Sounds")


function hg.CreateCategory(ctgName, ParentPanel, yPos)
    local pppanel = vgui.Create('DPanel', ParentPanel)
    pppanel:SetSize(ParentPanel:GetWide() / 1.05, ParentPanel:GetTall() * 0.07)
    pppanel:SetPos(ParentPanel:GetWide() / 2 -pppanel:GetWide() / 2, yPos)
    --pppanel:SetText(ctgName)
    pppanel.Paint = function(self,w,h)
        surface.SetDrawColor(60,60,60,145)
        surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(42, 42, 42, 184)
		surface.DrawRect(0, h-5, w, 5)
    
        draw.SimpleText(ctgName, 'ZCity_setiings_category', w / 2, h / 2, color3, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    return pppanel
end

function hg.GetConVarType(convar)
    local stringv = convar:GetString()
    local floatVal = convar:GetFloat()
    local intVal = convar:GetInt()
    local boolVal = convar:GetBool()

    if (stringv == '0' and not boolVal) or (stringv == '1' and boolVal) then
        return 'bool'
    end

    if tonumber(stringv) and math.floor(stringv) == floatVal then
        if intVal == floatVal then
            return "int"
        end
    end

    return "string"
end

local function SetConVarValue(convar, value)
    if not convar then
        return
    end

    local name = convar.GetName and convar:GetName()
    if not name or name == "" then
        return
    end

    if isbool(value) then
        RunConsoleCommand(name, value and "1" or "0")
        return
    end

    RunConsoleCommand(name, tostring(value))
end

local clr_1 = Color(255,255,255,104)
local clr_2 = Color(122,122,122,104)
local clr_3 = Color(28,28,28)
local clr_4 = Color(0, 0, 0, 30)
local clr_5 = Color(30, 29, 29, 30)
local clr_6 = Color(255, 255, 255, 100)
local clr_7 = Color(255, 255, 255, 200)
local clr_8 = Color(70, 130, 180)
function hg.CreateButton(buttonData, convarName, ParentPanel, yPos)
    local convar = GetConVar(convarName)

    if not convar then 
        return 
    end
    local pppanel = vgui.Create('DPanel', ParentPanel)
    pppanel:SetSize(ParentPanel:GetWide()/1.05, ParentPanel:GetTall()/15)
    pppanel:SetPos(ParentPanel:GetWide()/2-pppanel:GetWide()/2, yPos)
    
    surface.SetFont('ZCity_setiings_fine')
    local width2, height2 = surface.GetTextSize(buttonData[3])
    
    convarType = buttonData[6] or hg.GetConVarType(convar)
    pppanel.Paint = function(self,w,h)
        surface.SetDrawColor(43, 43, 43,145)
        surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(47, 47, 47,145)
		surface.DrawRect(0, h-3, w, 3)
        
        draw.SimpleText(buttonData[3], 'ZCity_setiings_fine', 30, h / 2 -height2/2.5, clr_1, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(convar:GetHelpText(), 'ZCity_setiings_tiny', 30, h / 2+height2/2, clr_2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if convarType == 'bool' then
        local toggle = vgui.Create('DButton', pppanel)
        toggle:SetSize(pppanel:GetWide() / 18, pppanel:GetTall() / 2)

        
        toggle:SetPos(pppanel:GetWide() - toggle:GetWide()*1.4 - pppanel:GetWide() / 20, pppanel:GetTall() / 2 - toggle:GetTall() / 2)
        toggle:SetText('')
        
        local animProgress = convar:GetBool() and 1 or 0
        local targetProgress = animProgress
        
        function toggle:Paint(w, h)
            if animProgress ~= targetProgress then
                animProgress = Lerp(FrameTime() * 8, animProgress, targetProgress)
            end
            
            local bgColor = Color(
                Lerp(animProgress, 180, 80),  
                Lerp(animProgress, 30, 120),  
                Lerp(animProgress, 30, 50)   
            )
            
            local shadowColor = Color(0, 0, 0, Lerp(animProgress, 150, 40))
            surface.SetDrawColor(clr_3)
            draw.RoundedBox(0, 0, 0, w, h, clr_3)
            
            surface.SetDrawColor(clr_5)
            draw.RoundedBox(0, 2, 2, w - 4, h - 4, clr_4)
            
            local slsize = h - 12
            local slPos = Lerp(animProgress, 6, w - slsize - 6)
            surface.SetDrawColor(bgColor)
            draw.RoundedBox(0, slPos, 6, slsize, slsize, bgColor)
            surface.SetDrawColor(shadowColor)
            surface.DrawRect(slPos, slsize+4, slsize, 3)
    
            surface.SetDrawColor(clr_6)
        end
        
        function toggle:DoClick()
            if convar then
                local newValue = not convar:GetBool()
                SetConVarValue(convar, newValue)

                surface.PlaySound('glide/headlights_on.wav')
                targetProgress = newValue and 1 or 0
            end
        end
        
    elseif convarType == 'int' then
        local slider = vgui.Create('DNumSlider', pppanel)
        slider:SetSize(280, 30)
        slider:SetPos(pppanel:GetWide() - 300, pppanel:GetTall() / 2 - 15)
        slider:SetText('')
        
        local min = convar:GetMin() or 0
        local max = convar:GetMax() or 100
        local decimals = buttonData[4] and 2 or 0
        
        slider:SetMin(min)
        slider:SetMax(max)
        slider:SetDecimals(decimals)
        slider:SetValue(decimals > 0 and convar:GetFloat() or convar:GetInt())
        
        function slider:OnValueChanged(val)
            if convar then
                SetConVarValue(convar, decimals > 0 and math.Round(val, decimals) or math.Round(val))
            end
        end
        
        local valueLabel = vgui.Create('DLabel', pppanel)
        valueLabel:SetPos(pppanel:GetWide() - 350, pppanel:GetTall() / 2 - 8)
        valueLabel:SetSize(50, 20)
        valueLabel:SetText(convar:GetInt())
        valueLabel:SetTextColor(clr_7)
        valueLabel:SetFont('ZCity_setiings_tiny')
        
        slider.Think = function()
            if convar then
                valueLabel:SetText(convar:GetInt())
            end
        end
        
    elseif convarType == 'string' then
        local textEntry = vgui.Create('DTextEntry', pppanel)
        textEntry:SetSize(pppanel:GetWide()/8, pppanel:GetTall()/2)
        textEntry:SetPos(pppanel:GetWide()-pppanel:GetWide()/8-20, pppanel:GetTall()/2-textEntry:GetTall()/2)
        textEntry:SetText(convar:GetString())
        textEntry:SetUpdateOnType(true) 
        textEntry:SetFont('ZCity_Tiny')
        
    
        textEntry.Paint = function(self, w, h)
            surface.SetDrawColor(30, 30, 30, 255)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(60, 60, 60, 255)
            surface.DrawOutlinedRect(0, 0, w, h)
            
            self:DrawTextEntryText(color_white, clr_8, color_white)
        end
        
        function textEntry:OnValueChange(val)
            if convar then
                SetConVarValue(convar, val)
            end
        end
    end
    
    return pppanel
end

function hg.DrawSettings(ParentPanel)
    ParentPanel:SetAlpha(0)
    ParentPanel.Paint = function(self,w,h)

        surface.SetDrawColor(28,28,28,255)
        surface.DrawRect(0, 0, w, h)

        surface.SetDrawColor(107, 107, 107,20)

        for i = 1, (ybars + 1) do
            surface.DrawRect((sw / ybars) * i - (CurTime() * 30 % (sw / ybars)), 0, ScreenScale(1), sh)
        end

        for i = 1, (xbars + 1) do
            surface.DrawRect(0, (sh / xbars) * (i - 1) + (CurTime() * 30 % (sh / xbars)), sw, ScreenScale(1))
        end

        local border_size = ScreenScale(2)

        surface.SetDrawColor(0, 0, 0)
        surface.SetMaterial(gradient_l)
        surface.DrawTexturedRect(0, 0, border_size, sh)
		surface.SetMaterial(blur)
        surface.SetDrawColor(28,28,28,208)
        surface.DrawRect(0, 0, w, h)
    end
    hg.DrawBlur(ParentPanel, 5)
    ParentPanel:AlphaTo(255,0.15,0)
    local pppanel3 = vgui.Create('DScrollPanel', ParentPanel)
    pppanel3:SetSize(ParentPanel:GetWide(), ParentPanel:GetTall())
    pppanel3:SetPos(0,0)
    --pppanel3:SetAlpha(0)
    pppanel3.Paint = function()end
    -- 🥴 <- лучший смайлик

    local yOffset = pppanel3:GetTall()/100

    for categoryName, categoryTable in pairs(hg.settings.tbl) do
        local category = hg.CreateCategory(categoryName, pppanel3, yOffset)
        yOffset = yOffset + category:GetTall() + 12
        for convarName, settingData in pairs(categoryTable) do
            local vbv = hg.CreateButton(settingData,convarName,pppanel3,yOffset)
            if not vbv then continue end
            yOffset = yOffset + (vbv:GetTall()) + 12
        end
    end
    local pppanel23 = vgui.Create('DPanel', pppanel3)
    pppanel23:SetSize(0, 0)
    pppanel23:SetPos(0,yOffset+12)
end

local bindTrap
local bindTrapping = false
local bindState = {}

local clr_bind_bg = Color(28, 28, 28, 190)
local clr_bind_bg_hover = Color(28, 28, 28, 235)
local clr_bind_border = Color(60, 60, 60, 150)
local clr_bind_border_hover = Color(60, 60, 60, 255)
local clr_hint = Color(160, 160, 160, 220)

local mouseButtons = {[107] = true, [108] = true, [109] = true, [110] = true, [111] = true, [112] = true, [113] = true}

hg.binds_capturing = false

hg.binds = {
    {cmd = "fake", title = "Fake (ragdolling)", id = "fake"},
    {cmd = "+hmcd_holdbreath", title = "Hold breath", id = "holdbreath"},
    {cmd = "+neckbreak", title = "Break neck (infiltrator)", id = "neckbreak"},
    {cmd = "+hg_disarm", title = "Disarm (assassin)", id = "disarm"},
    {cmd = "+hg_zoom", title = "Zoom", id = "zoom"},
    {cmd = "suicide", title = "Suicide", id = "suicide"},
    {cmd = "+alt1", title = "Lean right", id = "leanright"},
    {cmd = "+alt2", title = "Lean left", id = "leanleft"},
}

for _, data in ipairs(hg.binds) do
    data.code = tonumber(cookie.GetString("hg_bind_" .. data.id, "0")) or 0
end

local function EngineBoundKey(cmd)
    local key = input.LookupBinding(cmd)
    if not key or key == "" then return nil end
    return string.lower(key)
end

local function KeyName(code)
    if not code or code <= 0 then return nil end
    local name = input.GetKeyName(code)
    if not name or name == "" then return nil end
    return string.lower(name)
end

local function GetBoundKey(data)
    return KeyName(data.code) or EngineBoundKey(data.cmd)
end

local function SetBindKey(data, code)
    data.code = code or 0
    cookie.Set("hg_bind_" .. data.id, tostring(data.code))
end

local function IsBindKeyDown(code)
    if not code or code <= 0 then return false end
    if mouseButtons[code] then return input.IsMouseDown(code) end
    return input.IsKeyDown(code)
end

local function BindsBlocked()
    return hg.binds_capturing
        or gui.IsGameUIVisible()
        or gui.IsConsoleVisible()
        or IsValid(vgui.GetKeyboardFocus())
        or vgui.CursorVisible()
end

local function RunBindCommand(cmd)
    RunConsoleCommand(cmd)
end

hook.Add("Think", "ZCity.BindExecute", function()
    local blocked = BindsBlocked()

    for _, data in ipairs(hg.binds) do
        local down = not blocked and IsBindKeyDown(data.code)

        if down and KeyName(data.code) == EngineBoundKey(data.cmd) then
            down = false
        end

        local prev = bindState[data.cmd] or false
        if down == prev then continue end

        bindState[data.cmd] = down

        if down then
            RunBindCommand(data.cmd)
        elseif string.sub(data.cmd, 1, 1) == "+" then
            RunBindCommand("-" .. string.sub(data.cmd, 2))
        end
    end
end)

hook.Add("Think", "ZCity.BindKeyTrap", function()
    if not bindTrapping then return end

    if not IsValid(bindTrap) then
        bindTrap = nil
        bindTrapping = false
        hg.binds_capturing = false
        if input.IsKeyTrapping() then input.CheckKeyTrapping() end
        return
    end

    if not input.IsKeyTrapping() then return end

    local code = input.CheckKeyTrapping()
    if not code then return end

    local btn = bindTrap
    bindTrap = nil
    bindTrapping = false
    hg.binds_capturing = false

    btn:FinishTrap(code)
end)

function hg.CreateBindRow(data, ParentPanel, yPos)
    local row = vgui.Create("DPanel", ParentPanel)
    row:SetSize(ParentPanel:GetWide() / 1.05, ParentPanel:GetTall() / 15)
    row:SetPos(ParentPanel:GetWide() / 2 - row:GetWide() / 2, yPos)

    surface.SetFont("ZCity_setiings_fine")
    local _, titleTall = surface.GetTextSize(data.title)

    row.Paint = function(self, w, h)
        surface.SetDrawColor(43, 43, 43, 145)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(47, 47, 47, 145)
        surface.DrawRect(0, h - 3, w, 3)

        draw.SimpleText(data.title, "ZCity_setiings_fine", 30, h / 2 - titleTall / 2.5, clr_1, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(data.cmd, "ZCity_setiings_tiny", 30, h / 2 + titleTall / 2, clr_2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local margin = row:GetWide() / 30

    local unbind = vgui.Create("DButton", row)
    unbind:SetSize(row:GetWide() / 12, row:GetTall() / 2)
    unbind:SetPos(row:GetWide() - unbind:GetWide() - margin, row:GetTall() / 2 - unbind:GetTall() / 2)
    unbind:SetText("")
    unbind.LabelText = "UNBIND"

    local key = vgui.Create("DButton", row)
    key:SetSize(row:GetWide() / 8, row:GetTall() / 2)
    key:SetPos(unbind:GetX() - key:GetWide() - margin, row:GetTall() / 2 - key:GetTall() / 2)
    key:SetText("")

    function key:Refresh()
        local cur = GetBoundKey(data)
        self.LabelText = cur and string.upper(cur) or "NONE"
    end

    function key:FinishTrap(code)
        self.Capturing = false

        if not code or code <= 0 or code == KEY_ESCAPE or code == 107 then
            self:Refresh()
            return
        end

        local existing = input.LookupKeyBinding(code)

        local function apply()
            SetBindKey(data, code)
            self:Refresh()
            for i = 1, 3 do surface.PlaySound("shitty/tap_depress.wav") end
        end

        if existing and existing != "" and existing != data.cmd then
            Derma_Query("This key is already used by \"" .. existing .. "\" in the engine, pressing it will trigger both.", "Binds",
                "Use key", apply,
                "Cancel", function() self:Refresh() end)
            return
        end

        apply()
    end

    function key:DoClick()
        bindTrap = self
        bindTrapping = true
        hg.binds_capturing = true
        input.StartKeyTrapping()
        self.Capturing = true
    end

    function unbind:DoClick()
        if data.code > 0 then
            SetBindKey(data, 0)
            for i = 1, 3 do surface.PlaySound("shitty/tap_depress.wav") end
        end

        key:Refresh()

        local eng = EngineBoundKey(data.cmd)
        if eng then
            Derma_Message("This command is still bound in the engine to \"" .. eng .. "\".\nThe addon can't change engine binds, remove it in console:\nunbind \"" .. eng .. "\"", "Binds", "OK")
        end
    end

    local function PaintBind(btn, w, h)
        local hovered = btn:IsHovered() or btn.Capturing

        draw.RoundedBox(0, 0, 0, w, h, hovered and clr_bind_bg_hover or clr_bind_bg)
        surface.SetDrawColor(hovered and clr_bind_border_hover or clr_bind_border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.SimpleText(btn.Capturing and "PRESS KEY" or (btn.LabelText or ""), "ZCity_setiings_fine", w / 2, h / 2, hovered and color_white or clr_1, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    key.Paint = PaintBind
    unbind.Paint = PaintBind

    key:Refresh()

    return row
end

function hg.DrawBinds(ParentPanel)
    ParentPanel:SetAlpha(0)
    ParentPanel.Paint = function(self, w, h)
        surface.SetDrawColor(28, 28, 28, 255)
        surface.DrawRect(0, 0, w, h)

        surface.SetDrawColor(107, 107, 107, 20)

        for i = 1, (ybars + 1) do
            surface.DrawRect((sw / ybars) * i - (CurTime() * 30 % (sw / ybars)), 0, ScreenScale(1), sh)
        end

        for i = 1, (xbars + 1) do
            surface.DrawRect(0, (sh / xbars) * (i - 1) + (CurTime() * 30 % (sh / xbars)), sw, ScreenScale(1))
        end

        local border_size = ScreenScale(2)

        surface.SetDrawColor(0, 0, 0)
        surface.SetMaterial(gradient_l)
        surface.DrawTexturedRect(0, 0, border_size, sh)
        surface.SetMaterial(blur)
        surface.SetDrawColor(28, 28, 28, 208)
        surface.DrawRect(0, 0, w, h)
    end
    hg.DrawBlur(ParentPanel, 5)
    ParentPanel:AlphaTo(255, 0.15, 0)

    local scroll = vgui.Create("DScrollPanel", ParentPanel)
    scroll:SetSize(ParentPanel:GetWide(), ParentPanel:GetTall())
    scroll:SetPos(0, 0)
    scroll.Paint = function() end

    local yOffset = scroll:GetTall() / 100

    local category = hg.CreateCategory("Binds", scroll, yOffset)
    yOffset = yOffset + category:GetTall() + 12

    for _, data in ipairs(hg.binds) do
        local row = hg.CreateBindRow(data, scroll, yOffset)
        yOffset = yOffset + row:GetTall() + 12
    end

    local hint = vgui.Create("DLabel", scroll)
    hint:SetFont("ZCity_setiings_tiny")
    hint:SetTextColor(clr_hint)
    hint:SetPos(scroll:GetWide() / 2 - (scroll:GetWide() / 1.05) / 2 + 30, yOffset + ScreenScale(6))
    hint:SetText("Click a key field, then press a key or mouse button. ESC / LMB cancels.\nUNBIND clears it. GMod blocks bind/unbind from Lua, so the addon fires the command itself.")
    hint:SizeToContents()
end