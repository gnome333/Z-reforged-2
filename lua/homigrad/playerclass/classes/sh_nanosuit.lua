local CLASS = player.RegClass("nanosuit")

CLASS.NanoSuit = true
CLASS.CanUseDefaultPhrase = true
CLASS.CanUseGestures = true
CLASS.CanEmitRNDSound = true

local function tryGive(self, attempts)
    if not IsValid(self) then return end
    if self.PlayerClassName != "nanosuit" then return end
    if self:Alive() then
        if not self.ns_suit and hg.NanoSuit then
            hg.NanoSuit.Give(self)
        end
        return
    end
    if attempts > 20 then return end
    timer.Simple(0.5, function()
        tryGive(self, attempts + 1)
    end)
end

function CLASS.Off(self)
    if CLIENT then return end
    if hg.NanoSuit then
        hg.NanoSuit.Take(self)
    end
end

function CLASS.On(self, data)
    if CLIENT then return end
    if not hg.NanoSuit then return end
    ApplyAppearance(self, nil, nil, nil, true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    Appearance.AAttachments = ""
    Appearance.AColthes = ""
    self:SetNetVar("Accessories", "")
    self.CurAppearance = Appearance
    self:SetNWString("PlayerName", "Nanosuit")
    tryGive(self, 0)
end

function CLASS.Guilt(self, Victim)
    if CLIENT then return end
    if Victim:GetPlayerClass() == self:GetPlayerClass() then
        return 1
    end
    return 1
end
