local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GrabConfig = require(ReplicatedStorage.Shared.GrabConfig)
local GrinderConfig = require(ReplicatedStorage.Shared.GrinderConfig)
local GrinderWorld = require(ReplicatedStorage.Shared.GrinderWorld)
local HarvestYield = require(script.Parent.HarvestYield)
local PlayerData = require(script.Parent.PlayerData)

local Grinder = {}

local grinder: Model
local intake: BasePart
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local function refreshFilter()
	overlapParams.FilterDescendantsInstances = CollectionService:GetTagged(GrabConfig.TAG)
end

local function bodyOf(part: BasePart): Instance?
	local candidate: Instance? = part
	while candidate and candidate ~= Workspace do
		if candidate:HasTag(GrabConfig.TAG) then
			return candidate
		end
		candidate = candidate.Parent
	end
	return nil
end

local function creditedPlayer(body: Instance): Player?
	local userId = body:GetAttribute(GrabConfig.LAST_HOLDER_ATTRIBUTE)
	return if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function grindCount(): number
	local count = grinder:GetAttribute(GrinderConfig.GRIND_COUNT_ATTRIBUTE)
	return if typeof(count) == "number" then count else 0
end

local function grind(body: Instance)
	local meat = body:GetAttribute(GrabConfig.MEAT_YIELD_ATTRIBUTE)
	local player = creditedPlayer(body)
	body:Destroy()
	if player and typeof(meat) == "number" then
		PlayerData.addMeat(player, HarvestYield.roll(player, meat))
	end
	grinder:SetAttribute(GrinderConfig.GRIND_COUNT_ATTRIBUTE, grindCount() + 1)
end

local function onHeartbeat()
	local swallowed: { [Instance]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInBox(intake.CFrame, intake.Size, overlapParams) do
		local body = bodyOf(part)
		if body and not swallowed[body] then
			swallowed[body] = true
			grind(body)
		end
	end
end

function Grinder.snapshot(): number
	return grindCount()
end

function Grinder.restore(count: number)
	grinder:SetAttribute(GrinderConfig.GRIND_COUNT_ATTRIBUTE, count)
end

function Grinder.start()
	grinder = GrinderWorld.resolve()
	intake = GrinderWorld.intake(grinder)
	CollectionService:GetInstanceAddedSignal(GrabConfig.TAG):Connect(refreshFilter)
	CollectionService:GetInstanceRemovedSignal(GrabConfig.TAG):Connect(refreshFilter)
	refreshFilter()
	RunService.Heartbeat:Connect(onHeartbeat)
end

return Grinder
