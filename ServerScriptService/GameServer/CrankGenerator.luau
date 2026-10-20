local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CrankCharge = require(ReplicatedStorage.Shared.CrankCharge)
local CrankGeneratorConfig = require(ReplicatedStorage.Shared.CrankGeneratorConfig)
local CrankGeneratorWorld = require(ReplicatedStorage.Shared.CrankGeneratorWorld)
local PlayerAttributes = require(ReplicatedStorage.Shared.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local UpgradeEffects = require(ReplicatedStorage.Shared.UpgradeEffects)
local PlayerData = require(script.Parent.PlayerData)
local PlayerReach = require(script.Parent.PlayerReach)
local RemoteThrottle = require(script.Parent.RemoteThrottle)
local WorkActivity = require(script.Parent.WorkActivity)

local TURN_RANGE = 14
local RESTART_COOLDOWN = 0.2
local CRANKING_REQUESTS_PER_SECOND = 8
local CHARGE_UPGRADE_ITEM_IDS = {
	ShopCatalog.BATTERY_ITEM_ID,
	ShopCatalog.CRANK_ITEM_ID,
	ShopCatalog.GEAR_ITEM_ID,
	ShopCatalog.INERTIA_ITEM_ID,
}

local crankingStoppedEvent = Instance.new("BindableEvent")

local CrankGenerator = {
	crankingStopped = crankingStoppedEvent.Event,
}

local world: CrankGeneratorWorld.Instances
local cranker: Player? = nil
local lastStartedAt = -math.huge

local function crankRatesOf(player: Player): CrankCharge.CrankRates
	return {
		turnsPerSecond = UpgradeEffects.crankTurnsPerSecond(PlayerData.upgradeLevel(player, ShopCatalog.CRANK_ITEM_ID)),
		energyPerTurn = UpgradeEffects.energyPerTurn(PlayerData.upgradeLevel(player, ShopCatalog.GEAR_ITEM_ID)),
		inertiaDuration = UpgradeEffects.inertiaDuration(PlayerData.upgradeLevel(player, ShopCatalog.INERTIA_ITEM_ID)),
	}
end

local function rebaseCharge(leavingPlayer: Player?)
	local batteryLevel = PlayerData.highestUpgradeLevel(ShopCatalog.BATTERY_ITEM_ID, leavingPlayer)
	local fullDrainDuration = UpgradeEffects.fullDrainDuration(batteryLevel)
	if cranker then
		CrankCharge.crank(world.station, crankRatesOf(cranker), fullDrainDuration)
	else
		CrankCharge.release(world.station, fullDrainDuration)
	end
end

local function canCrank(player: Player): boolean
	return PlayerReach.isWithin(player, world.wheel.Position, TURN_RANGE)
		and CrankCharge.hasRoom(CrankCharge.current(world.station))
end

local function setCranker(player: Player?)
	local hasStopped = cranker ~= nil and player == nil
	cranker = player
	rebaseCharge(nil)
	if hasStopped then
		crankingStoppedEvent:Fire()
	end
end

local function onCrankingRequested(player: Player, wantsCranking: unknown)
	if wantsCranking == false and cranker == player then
		setCranker(nil)
	elseif wantsCranking == true and cranker == nil and os.clock() - lastStartedAt >= RESTART_COOLDOWN and canCrank(player) then
		lastStartedAt = os.clock()
		setCranker(player)
	end
end

local function onHeartbeat()
	if not cranker then
		return
	end
	if canCrank(cranker) then
		WorkActivity.record(cranker)
	else
		setCranker(nil)
	end
end

local function onPlayerAdded(player: Player)
	for _, itemId in CHARGE_UPGRADE_ITEM_IDS do
		player:GetAttributeChangedSignal(PlayerAttributes.upgradeLevel(itemId)):Connect(function()
			rebaseCharge(nil)
		end)
	end
end

local function onPlayerRemoving(player: Player)
	if cranker == player then
		setCranker(nil)
	end
	rebaseCharge(player)
end

function CrankGenerator.isPowered(): boolean
	return CrankCharge.isPowered(CrankCharge.current(world.station))
end

function CrankGenerator.charge(): number
	return CrankCharge.current(world.station)
end

function CrankGenerator.restore(charge: number)
	world.station:SetAttribute(CrankGeneratorConfig.CHARGE_ATTRIBUTE, math.clamp(charge, 0, CrankGeneratorConfig.MAX_CHARGE))
	world.station:SetAttribute(CrankGeneratorConfig.CHARGED_AT_ATTRIBUTE, Workspace:GetServerTimeNow())
	world.station:SetAttribute(CrankGeneratorConfig.COAST_DURATION_ATTRIBUTE, 0)
	rebaseCharge(nil)
end

function CrankGenerator.start()
	world = CrankGeneratorWorld.resolve()
	rebaseCharge(nil)
	RemoteThrottle.connect(Remotes.SetCranking, CRANKING_REQUESTS_PER_SECOND, onCrankingRequested)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return CrankGenerator
