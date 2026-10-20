local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoltStationConfig = require(Shared:WaitForChild("BoltStationConfig"))
local BoltStationWorld = require(Shared:WaitForChild("BoltStationWorld"))
local CrankCharge = require(Shared:WaitForChild("CrankCharge"))
local CrankGeneratorWorld = require(Shared:WaitForChild("CrankGeneratorWorld"))
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))
local UpgradeEffects = require(Shared:WaitForChild("UpgradeEffects"))
local AimTarget = require(script.Parent:WaitForChild("AimTarget"))
local PrimaryAction = require(script.Parent:WaitForChild("PrimaryAction"))
local ToolViewmodel = require(script.Parent:WaitForChild("ToolViewmodel"))

local BoltTightening = {}

local player = Players.LocalPlayer
local crankStation: Model
local stationBolts: Folder
local nextTurnAt = -math.huge

local function isWrenchEquipped(): boolean
	return player:GetAttribute(PlayerAttributes.EQUIPPED_TOOL) == ShopCatalog.WRENCH_ITEM_ID
end

local function ownsBrain(): boolean
	return player:GetAttribute(PlayerAttributes.ownedItem(ShopCatalog.BRAIN_ITEM_ID)) == true
end

local function wrenchLevel(): number
	local level = player:GetAttribute(PlayerAttributes.upgradeLevel(ShopCatalog.WRENCH_ITEM_ID))
	return if typeof(level) == "number" then level else 0
end

local function isPowered(): boolean
	return CrankCharge.isPowered(CrankCharge.current(crankStation))
end

local function acceptsTurn(bolt: Instance): boolean
	local turns = bolt:GetAttribute(BoltStationConfig.TURNS_ATTRIBUTE)
	local isResting = bolt:GetAttribute(BoltStationConfig.ROUTE_ATTRIBUTE) == nil
	local isAtStation = bolt:IsDescendantOf(stationBolts)
	return isAtStation and isResting and typeof(turns) == "number" and turns < BoltStationConfig.TURNS_TO_SEAT
end

local function scheduleNextTurn(now: number, turnInterval: number)
	local isOnSchedule = now - nextTurnAt < turnInterval
	nextTurnAt = (if isOnSchedule then nextTurnAt else now) + turnInterval
end

local function tryTurn()
	local now = os.clock()
	if now < nextTurnAt or not isWrenchEquipped() or not isPowered() then
		return
	end
	local bolt = AimTarget.find(BoltStationConfig.BOLT_TAG)
	if not bolt or not acceptsTurn(bolt) then
		return
	end
	local turnInterval = UpgradeEffects.turnInterval(wrenchLevel())
	scheduleNextTurn(now, turnInterval)
	ToolViewmodel.playSwing(turnInterval)
	Remotes.TightenBolt:FireServer()
end

local function onRenderStepped()
	if PrimaryAction.isHeld() or ownsBrain() then
		tryTurn()
	end
end

function BoltTightening.start()
	crankStation = CrankGeneratorWorld.resolve().station
	stationBolts = BoltStationWorld.resolve().boltFolder
	PrimaryAction.triggered:Connect(tryTurn)
	RunService.RenderStepped:Connect(onRenderStepped)
end

return BoltTightening
