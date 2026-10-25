-- Damage Protocol v2 helper (Shared). Server-authoritative lag-compensated traces.
-- Realm: Shared (no side effects on load). Call hg.DamageCompensatedTrace only on SERVER.
hg = hg or {}
local IsValid = IsValid
--- Run fn(startPos, dir) inside LagCompensation with guaranteed release.
--- @param ply Player shooter (server)
--- @param fn function executed while compensated; return its results
--- @return results of fn (or nil + err if invalid)
function hg.DamageCompensatedTrace(ply, fn)
    if SERVER then
        if not IsValid(ply) or not ply:IsPlayer() then return nil end
        ply:LagCompensation(true)
        local ok, a, b, c = pcall(fn)
        if IsValid(ply) then ply:LagCompensation(false) end
        if not ok then ErrorNoHalt("[DamageProtocol] trace error: " .. tostring(a) .. "\n") return nil end
        return a, b, c
    end
    return nil
end
