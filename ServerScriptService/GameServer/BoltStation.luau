local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoltStationConfig = require(ReplicatedStorage.Shared.BoltStationConfig)
local BoltStationWorld = require(ReplicatedStorage.Shared.BoltStationWorld)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local UpgradeEffects = require(ReplicatedStorage.Shared.UpgradeEffects)
local BoltConveyor = require(script.Parent.BoltConveyor)
local BoltValue = require(script.Parent.BoltValue)
local CrankGenerator = require(script.Parent.CrankGenerator)
local PlayerData = require(script.Parent.PlayerData)
local PlayerReach = require(script.Parent.PlayerReach)
local RemoteThrottle = require(script.Parent.RemoteThrottle)
local ToolBelt = require(script.Parent.ToolBelt)
local WorkActivity = require(script.Parent.WorkActivity)

local TIGHTEN_RANGE = 14
local TURN_JITTER_WINDOW = 0.25
local TIGHTEN_REQUESTS_PER_SECOND = 20

type TurnBudget = {
	tokens: number,
	refilledAt: number,
}

local boltTightenedEvent = Instance.new("BindableEvent")

local BoltStation = {
	boltTightened = boltTightenedEvent.Event,
}

local slotPosition: Vector3
local conveyor: BoltConveyor.Conveyor
local turnBudgets: { [Player]: TurnBudget } = {}

local function takeTurnToken(player: Player): boolean
	local now = os.clock()
	local turnInterval = UpgradeEffects.turnInterval(PlayerData.upgradeLevel(player, ShopCatalog.WRENCH_ITEM_ID))
	local capacity = 1 + TURN_JITTER_WINDOW / turnInterval
	local budget = turnBudgets[player] or { tokens = capacity, refilledAt = now }
	budget.tokens = math.min(budget.tokens + (now - budget.refilledAt) / turnInterval, capacity)
	budget.refilledAt = now
	turnBudgets[player] = budget
	if budget.tokens < 1 then
		return false
	end
	budget.tokens -= 1
	return true
end

local function canTighten(player: Player): boolean
	return CrankGenerator.isPowered()
		and ToolBelt.isEquipped(player, ShopCatalog.WRENCH_ITEM_ID)
		and PlayerReach.isWithin(player, slotPosition, TIGHTEN_RANGE)
end

local function onTightenRequested(player: Player)
	local bolt = BoltConveyor.restingBolt(conveyor)
	if not bolt or not canTighten(player) or not takeTurnToken(player) then
		return
	end
	WorkActivity.record(player)
	local turns = (bolt:GetAttribute(BoltStationConfig.TURNS_ATTRIBUTE) :: number) + 1
	bolt:SetAttribute(BoltStationConfig.TURNS_ATTRIBUTE, turns)
	if turns >= BoltStationConfig.TURNS_TO_SEAT then
		PlayerData.recordTightenedBolt(player, BoltValue.payoutCents(player, bolt), BoltValue.isRare(bolt))
		BoltConveyor.advance(conveyor)
		boltTightenedEvent:Fire(player)
	end
end

local function beltSpeed(): number
	return UpgradeEffects.beltSpeed(PlayerData.highestUpgradeLevel(ShopCatalog.COMPUTER_ITEM_ID))
end

local function onPlayerRemoving(player: Player)
	turnBudgets[player] = nil
end

function BoltStation.start()
	local world = BoltStationWorld.resolve()
	slotPosition = world.boltSlot.WorldPosition
	conveyor = BoltConveyor.new(world, { beltSpeed = beltSpeed, isPowered = CrankGenerator.isPowered })
	RemoteThrottle.connect(Remotes.TightenBolt, TIGHTEN_REQUESTS_PER_SECOND, onTightenRequested)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return BoltStation
