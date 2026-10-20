local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local COLLISION_GROUP = "SectorTwoRagdoll"
local READY_ATTRIBUTE = "RagdollReady"
local ENABLED_ATTRIBUTE = "RagdollEnabled"
local PART_ATTRIBUTE = "RagdollPart"
local Ragdoll = {}
function Ragdoll.enable(model)
	assert(RunService:IsServer(), "Ragdoll physics must be controlled by the server")
	assert(model:IsA("Model") and model:GetAttribute(READY_ATTRIBUTE), "Expected a prepared ragdoll model")
	if model:GetAttribute(ENABLED_ATTRIBUTE) then return end
	local parts = {}
	for _, instance in model:GetChildren() do
		if instance:IsA("BasePart") and instance:GetAttribute(PART_ATTRIBUTE) then
			table.insert(parts, instance)
		end
	end
	assert(#parts > 0, "Ragdoll has no physical parts")
	if not PhysicsService:IsCollisionGroupRegistered(COLLISION_GROUP) then
		PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
	for _, instance in model:GetDescendants() do
		if instance:IsA("BallSocketConstraint") then
			assert(instance.Attachment0 and instance.Attachment1, "Ragdoll joint is incomplete")
			instance.Enabled = true
		elseif instance:IsA("Motor6D") then
			instance.Enabled = false
		end
	end
	for _, part in parts do
		part.CollisionGroup = COLLISION_GROUP
		part.CanCollide = true
		part.Anchored = false
	end
	for _, part in parts do
		local canSetOwnership = part:CanSetNetworkOwnership()
		if canSetOwnership then part:SetNetworkOwner(nil) end
	end
	model:SetAttribute(ENABLED_ATTRIBUTE, true)
end
return table.freeze(Ragdoll)
