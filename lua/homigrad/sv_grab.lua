function hg.ReleaseGrab(ply)
	if not IsValid(ply) then return end

	local attacker = ply.GrabbedBy
	ply.GrabbedBy = nil
	ply.GrabEscapeTime = nil

	if IsValid(attacker) then
		local carry = attacker:GetNetVar("carryent2")

		if IsValid(carry) and (carry == ply or carry == ply.FakeRagdoll) then
			hg.SetCarryEnt2(attacker)
		end
	end
end
