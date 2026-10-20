local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))

local AIM_DISTANCE = 10

local AimTarget = {}

local player = Players.LocalPlayer

local function isCaptured(): boolean
	return player:GetAttribute(PlayerAttributes.CAPTURED) == true
end

local function taggedAncestor(instance: Instance, tag: string): Instance?
	local candidate: Instance? = instance
	while candidate and candidate ~= Workspace do
		if candidate:HasTag(tag) then
			return candidate
		end
		candidate = candidate.Parent
	end
	return nil
end

local function castAim(): RaycastResult?
	if isCaptured() then
		return nil
	end
	local camera = Workspace.CurrentCamera
	local exclusions: { Instance } = { camera }
	local character = player.Character
	if character then
		table.insert(exclusions, character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions
	return Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * AIM_DISTANCE, params)
end

function AimTarget.findHit(tag: string): (Instance?, RaycastResult?)
	local result = castAim()
	local target = if result then taggedAncestor(result.Instance, tag) else nil
	return target, if target then result else nil
end

function AimTarget.find(tag: string): Instance?
	return (AimTarget.findHit(tag))
end

return AimTarget
