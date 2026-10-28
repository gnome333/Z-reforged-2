local FirstPickupSounds = {
	["weapon_osipr"] = "sounds/newequ.wav",
}

if SERVER then
	util.AddNetworkString("HG_FirstPickupSound")

	hook.Add("PlayerSpawn", "HG_FirstPickupSound", function(ply)
		ply.HG_FirstPicked = nil
	end)

	hook.Add("PlayerCanPickupWeapon", "HG_FirstPickupSound", function(ply, wep)
		if not IsValid(wep) then return end

		local snd = FirstPickupSounds[wep:GetClass()]
		if not snd then return end
		if ply:HasWeapon(wep:GetClass()) then return end
		if ply.HG_FirstPicked and ply.HG_FirstPicked[wep:GetClass()] then return end

		timer.Simple(0, function()
			if not IsValid(ply) or not ply:Alive() then return end
			if not ply:HasWeapon(wep:GetClass()) then return end

			ply.HG_FirstPicked = ply.HG_FirstPicked or {}
			if ply.HG_FirstPicked[wep:GetClass()] then return end
			ply.HG_FirstPicked[wep:GetClass()] = true

			net.Start("HG_FirstPickupSound")
			net.WriteString(snd)
			net.Send(ply)
		end)
	end)
else
	net.Receive("HG_FirstPickupSound", function()
		local lp = LocalPlayer()
		if not IsValid(lp) then return end

		lp:EmitSound(net.ReadString())
	end)
end
