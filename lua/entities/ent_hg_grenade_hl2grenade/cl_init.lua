include("shared.lua")
function ENT:Draw()
	self:DrawModel()
end

function ENT:Think()
	if not self:GetNWBool("hg_armed") then return end

	local dlight = self.Dlight
	if not dlight then
		dlight = DynamicLight(self:EntIndex())
		if not dlight then return end
		self.Dlight = dlight
	end

	dlight.pos = self:GetPos()
	dlight.r = 255
	dlight.g = 0
	dlight.b = 0
	dlight.brightness = 2
	dlight.size = 60 + 60 * (math.sin(CurTime() * 16) + 1) / 2
	dlight.decay = 0
	dlight.dietime = CurTime() + 0.1
end