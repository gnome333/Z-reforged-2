function ENT:Draw()
	self:DrawModel()
	local dlight = DynamicLight(self:EntIndex())
	if dlight then
		local c = math.sin(CurTime() * 2) * 0.5 + 0.5
		dlight.pos = self:GetPos() + Vector(0, 0, 40)
		dlight.r = 255
		dlight.g = 90 + c * 90
		dlight.b = 30
		dlight.brightness = 1.2
		dlight.size = 100
		dlight.decay = 200
		dlight.dietime = CurTime() + FrameTime() + 0.05
	end
end
