local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrankCharge = require(Shared:WaitForChild("CrankCharge"))
local CrankGeneratorWorld = require(Shared:WaitForChild("CrankGeneratorWorld"))
local HeartLineConfig = require(Shared:WaitForChild("HeartLineConfig"))
local ProductionLineConfig = require(Shared:WaitForChild("ProductionLineConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AimTarget = require(script.Parent:WaitForChild("AimTarget"))
local HammerSwing = require(script.Parent:WaitForChild("HammerSwing"))
local PrimaryAction = require(script.Parent:WaitForChild("PrimaryAction"))

local HeartStrike = {}

local crankStation: Model

local function isPowered(): boolean
	return CrankCharge.isPowered(CrankCharge.current(crankStation))
end

local function lineOf(heart: Instance): Instance?
	local candidate = heart.Parent
	while candidate and not candidate:HasTag(ProductionLineConfig.TAG) do
		candidate = candidate.Parent
	end
	return candidate
end

local function isResting(heart: Instance): boolean
	local line = lineOf(heart)
	return line ~= nil and line:GetAttribute(HeartLineConfig.CYCLE_STARTED_AT_ATTRIBUTE) == nil
end

local function tryStrike()
	if not HammerSwing.isReady() or not isPowered() then
		return
	end
	local heart = AimTarget.find(HeartLineConfig.HEART_TAG)
	if not heart or not isResting(heart) then
		return
	end
	HammerSwing.swing()
	Remotes.StrikeHeart:FireServer(heart)
end

function HeartStrike.start()
	crankStation = CrankGeneratorWorld.resolve().station
	PrimaryAction.triggered:Connect(tryStrike)
end

return HeartStrike
