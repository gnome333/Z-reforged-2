hook.Add("EntityEmitSound", "hg_ragdoll_friction", function(data)
	local ent = data.Entity
	if not IsValid(ent) or not ent:IsRagdoll() then return end

	local snd = string.lower(data.SoundName or "")
	if not string.find(snd, "scrape", 1, true) then return end

	return false
end)
