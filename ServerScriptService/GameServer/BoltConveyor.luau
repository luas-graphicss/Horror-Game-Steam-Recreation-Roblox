local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoltRoutes = require(ReplicatedStorage.Shared.BoltRoutes)
local BoltStationConfig = require(ReplicatedStorage.Shared.BoltStationConfig)
local BoltStationWorld = require(ReplicatedStorage.Shared.BoltStationWorld)
local ConveyorClock = require(ReplicatedStorage.Shared.ConveyorClock)
local BoltValue = require(script.Parent.BoltValue)

local SEAT_PAUSE = 0.6

type Cycle = {
	finishedBolt: Model,
	beltStartsAt: number,
	routes: BoltRoutes.Routes,
	incomingBolt: Model?,
}

export type Settings = {
	beltSpeed: () -> number,
	isPowered: () -> boolean,
}

export type Conveyor = {
	world: BoltStationWorld.Instances,
	settings: Settings,
	boltTemplate: Model,
	restingBolt: Model?,
	cycle: Cycle?,
	retiringBolts: { [Model]: number },
	isActive: boolean,
}

local BoltConveyor = {}

local conveyors: { Conveyor } = {}
local heartbeatConnection: RBXScriptConnection? = nil

local function upgradedRoutes(conveyor: Conveyor): BoltRoutes.Routes
	return BoltRoutes.fromWorld(conveyor.world, conveyor.settings.beltSpeed())
end

local function spawnIncomingBolt(conveyor: Conveyor, routes: BoltRoutes.Routes, routeStartedAt: number): Model
	local bolt = conveyor.boltTemplate:Clone()
	bolt:SetAttribute(BoltStationConfig.TURNS_ATTRIBUTE, 0)
	bolt:SetAttribute(BoltStationConfig.RARE_ATTRIBUTE, BoltValue.rollRare())
	bolt:SetAttribute(BoltStationConfig.ROUTE_STARTED_AT_ATTRIBUTE, routeStartedAt)
	bolt:SetAttribute(BoltStationConfig.ROUTE_ATTRIBUTE, BoltStationConfig.INCOMING_ROUTE)
	bolt:PivotTo(routes.spawnPose)
	bolt.Parent = conveyor.world.boltFolder
	return bolt
end

local function sendOut(conveyor: Conveyor, bolt: Model, routes: BoltRoutes.Routes, routeStartedAt: number)
	bolt:SetAttribute(BoltStationConfig.ROUTE_STARTED_AT_ATTRIBUTE, routeStartedAt)
	bolt:SetAttribute(BoltStationConfig.ROUTE_ATTRIBUTE, BoltStationConfig.OUTGOING_ROUTE)
	conveyor.retiringBolts[bolt] = routeStartedAt + routes.outgoingDuration
end

local function settleAtSlot(conveyor: Conveyor, bolt: Model, routes: BoltRoutes.Routes)
	bolt:SetAttribute(BoltStationConfig.ROUTE_ATTRIBUTE, nil)
	bolt:SetAttribute(BoltStationConfig.ROUTE_STARTED_AT_ATTRIBUTE, nil)
	bolt:PivotTo(routes.slotPose)
	conveyor.restingBolt = bolt
end

local function startBelt(conveyor: Conveyor, activeCycle: Cycle)
	conveyor.world.belt:SetAttribute(BoltStationConfig.BELT_SPEED_ATTRIBUTE, activeCycle.routes.beltSpeed)
	activeCycle.incomingBolt = spawnIncomingBolt(conveyor, activeCycle.routes, activeCycle.beltStartsAt)
	sendOut(conveyor, activeCycle.finishedBolt, activeCycle.routes, activeCycle.beltStartsAt)
end

local function retireDroppedBolts(conveyor: Conveyor, now: number)
	for bolt, retiresAt in conveyor.retiringBolts do
		if now >= retiresAt then
			conveyor.retiringBolts[bolt] = nil
			bolt:Destroy()
		end
	end
end

local function advanceCycle(conveyor: Conveyor, activeCycle: Cycle, now: number)
	local incomingBolt = activeCycle.incomingBolt
	if not incomingBolt then
		if now >= activeCycle.beltStartsAt then
			startBelt(conveyor, activeCycle)
		end
	elseif now >= activeCycle.beltStartsAt + activeCycle.routes.beltDuration then
		conveyor.cycle = nil
		settleAtSlot(conveyor, incomingBolt, activeCycle.routes)
	end
end

local function followPower(conveyor: Conveyor)
	if conveyor.settings.isPowered() then
		ConveyorClock.resume(conveyor.world.belt)
	elseif conveyor.cycle then
		ConveyorClock.pause(conveyor.world.belt)
	end
end

local function setBeltRunning(conveyor: Conveyor, isRunning: boolean)
	local belt = conveyor.world.belt
	if belt:GetAttribute(BoltStationConfig.BELT_RUNNING_ATTRIBUTE) ~= isRunning then
		belt:SetAttribute(BoltStationConfig.BELT_RUNNING_ATTRIBUTE, isRunning)
	end
end

local function isCarrying(conveyor: Conveyor): boolean
	local activeCycle = conveyor.cycle
	return activeCycle ~= nil and activeCycle.incomingBolt ~= nil
end

local function step(conveyor: Conveyor)
	followPower(conveyor)
	local now = ConveyorClock.now(conveyor.world.belt)
	retireDroppedBolts(conveyor, now)
	local activeCycle = conveyor.cycle
	if activeCycle then
		advanceCycle(conveyor, activeCycle, now)
	end
	setBeltRunning(conveyor, isCarrying(conveyor) and not ConveyorClock.isPaused(conveyor.world.belt))
end

local function onHeartbeat()
	for _, conveyor in conveyors do
		if conveyor.isActive then
			step(conveyor)
		end
	end
end

local function clearBolts(conveyor: Conveyor)
	local activeCycle = conveyor.cycle
	if activeCycle then
		activeCycle.finishedBolt:Destroy()
		if activeCycle.incomingBolt then
			activeCycle.incomingBolt:Destroy()
		end
	end
	for bolt in conveyor.retiringBolts do
		bolt:Destroy()
	end
	if conveyor.restingBolt then
		conveyor.restingBolt:Destroy()
	end
	conveyor.cycle = nil
	conveyor.restingBolt = nil
	table.clear(conveyor.retiringBolts)
end

local function initialBolt(folder: Folder): Model?
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:HasTag(BoltStationConfig.BOLT_TAG) then
			return child
		end
	end
	return nil
end

function BoltConveyor.restingBolt(conveyor: Conveyor): Model?
	return conveyor.restingBolt
end

function BoltConveyor.advance(conveyor: Conveyor)
	local finishedBolt = conveyor.restingBolt
	if not finishedBolt then
		return
	end
	conveyor.restingBolt = nil
	conveyor.cycle = {
		finishedBolt = finishedBolt,
		beltStartsAt = ConveyorClock.now(conveyor.world.belt) + SEAT_PAUSE,
		routes = upgradedRoutes(conveyor),
		incomingBolt = nil,
	}
end

function BoltConveyor.activate(conveyor: Conveyor)
	if conveyor.isActive then
		return
	end
	conveyor.isActive = true
	local bolt = conveyor.boltTemplate:Clone()
	bolt:PivotTo(upgradedRoutes(conveyor).slotPose)
	bolt.Parent = conveyor.world.boltFolder
	conveyor.restingBolt = bolt
end

function BoltConveyor.deactivate(conveyor: Conveyor)
	if not conveyor.isActive then
		return
	end
	conveyor.isActive = false
	clearBolts(conveyor)
	setBeltRunning(conveyor, false)
end

function BoltConveyor.new(world: BoltStationWorld.Instances, settings: Settings): Conveyor
	local firstBolt = initialBolt(world.boltFolder) :: Model
	firstBolt:ScaleTo(BoltStationConfig.BOLT_SCALE)
	firstBolt:SetAttribute(BoltStationConfig.TURNS_ATTRIBUTE, 0)
	local conveyor: Conveyor = {
		world = world,
		settings = settings,
		boltTemplate = firstBolt:Clone(),
		restingBolt = firstBolt,
		cycle = nil,
		retiringBolts = {},
		isActive = true,
	}
	world.belt:SetAttribute(BoltStationConfig.BELT_SPEED_ATTRIBUTE, BoltStationConfig.BELT_SPEED)
	setBeltRunning(conveyor, false)
	table.insert(conveyors, conveyor)
	if not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)
	end
	return conveyor
end

return BoltConveyor
