function ENT:Initialize()
	self:SetModel(self.Model)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:PhysicsInit(SOLID_VPHYSICS)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
		phys:Sleep()
	end
	self.NextUse = 0
end

function ENT:Use(activator)
	if not IsValid(activator) or not activator:IsPlayer() then return end
	if not activator:Alive() then return end
	if CurTime() < self.NextUse then return end
	self.NextUse = CurTime() + 1
	if hg and hg.NanoSuit then
		hg.NanoSuit.Give(activator)
	end
end
