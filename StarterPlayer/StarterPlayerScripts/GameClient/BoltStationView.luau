local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoltRoutes = require(Shared:WaitForChild("BoltRoutes"))
local BoltStationConfig = require(Shared:WaitForChild("BoltStationConfig"))
local BoltStationWorld = require(Shared:WaitForChild("BoltStationWorld"))
local ConveyorClock = require(Shared:WaitForChild("ConveyorClock"))
local ProductionLineConfig = require(Shared:WaitForChild("ProductionLineConfig"))

local BODY_NAME = "Body"
local NUT_NAME = "Nut"
local SPARKS_NAME = "Sparks"
local TIGHTEN_SOUND_NAME = "TightenSound"
local SEAT_SOUND_NAME = "SeatSound"
local TOPPLE_SOUND_NAME = "ToppleSound"
local LAND_SOUND_NAME = "LandSound"
local DROP_SOUND_NAME = "DropSound"
local UNIT_THREAD_PITCH = 0.1397
local THREAD_PITCH = UNIT_THREAD_PITCH * BoltStationConfig.BOLT_SCALE
local FULL_TURN = 2 * math.pi
local TURN_DURATION = 0.3
local TIGHTEN_SPARK_COUNT = 12
local SEAT_SPARK_COUNT = 26

type LineView = {
	world: BoltStationWorld.Instances,
	landSound: Sound,
	dropSound: Sound,
	boltViews: { [Instance]: BoltView },
}

type BoltView = {
	model: Model,
	line: LineView,
	body: BasePart,
	nut: BasePart,
	nutRestOffset: CFrame,
	turnsFrom: number,
	turnsTo: number,
	turnStartedAt: number,
	isTurning: boolean,
	lastRouteElapsed: number?,
	turnConnection: RBXScriptConnection?,
}

local BoltStationView = {}

local lineViews: { [Instance]: LineView } = {}
local boltViews: { [Instance]: BoltView } = {}
local areaConnections: { [Instance]: RBXScriptConnection } = {}

local function turnsOf(bolt: Instance): number
	local turns = bolt:GetAttribute(BoltStationConfig.TURNS_ATTRIBUTE)
	return if typeof(turns) == "number" then turns else 0
end

local function turnProgress(view: BoltView): number
	return math.clamp((os.clock() - view.turnStartedAt) / TURN_DURATION, 0, 1)
end

local function visualTurns(view: BoltView): number
	local eased = TweenService:GetValue(turnProgress(view), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	return view.turnsFrom + (view.turnsTo - view.turnsFrom) * eased
end

local function placeNut(view: BoltView)
	local turns = visualTurns(view)
	view.nut.CFrame = view.body.CFrame
		* view.nutRestOffset
		* CFrame.new(0, -turns * THREAD_PITCH, 0)
		* CFrame.Angles(0, -turns * FULL_TURN, 0)
end

local function playChildSound(parent: Instance, name: string)
	local sound = parent:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

local function emitSparks(view: BoltView, count: number)
	local sparks = view.nut:FindFirstChild(SPARKS_NAME, true)
	if sparks and sparks:IsA("ParticleEmitter") then
		sparks:Emit(count)
	end
end

local function onTurnsChanged(view: BoltView)
	local turns = turnsOf(view.model)
	if turns <= view.turnsTo then
		return
	end
	view.turnsFrom = visualTurns(view)
	view.turnsTo = turns
	view.turnStartedAt = os.clock()
	view.isTurning = true
	if turns >= BoltStationConfig.TURNS_TO_SEAT then
		playChildSound(view.nut, SEAT_SOUND_NAME)
		emitSparks(view, SEAT_SPARK_COUNT)
	else
		playChildSound(view.nut, TIGHTEN_SOUND_NAME)
		emitSparks(view, TIGHTEN_SPARK_COUNT)
	end
end

local function lineViewContaining(instance: Instance): LineView?
	for _, line in lineViews do
		if instance:IsDescendantOf(line.world.boltFolder) then
			return line
		end
	end
	return nil
end

local function bindBolt(instance: Instance)
	if not instance:IsA("Model") or boltViews[instance] then
		return
	end
	local body = instance:WaitForChild(BODY_NAME) :: BasePart
	local nut = instance:WaitForChild(NUT_NAME) :: BasePart
	local line = lineViewContaining(instance)
	if boltViews[instance] or not line then
		return
	end
	local turns = turnsOf(instance)
	local view: BoltView = {
		model = instance,
		line = line,
		body = body,
		nut = nut,
		nutRestOffset = body.CFrame:ToObjectSpace(nut.CFrame),
		turnsFrom = turns,
		turnsTo = turns,
		turnStartedAt = 0,
		isTurning = false,
		lastRouteElapsed = nil,
		turnConnection = nil,
	}
	view.turnConnection = instance:GetAttributeChangedSignal(BoltStationConfig.TURNS_ATTRIBUTE):Connect(function()
		onTurnsChanged(view)
	end)
	boltViews[instance] = view
	line.boltViews[instance] = view
	placeNut(view)
end

local function unbindBolt(instance: Instance)
	local view = boltViews[instance]
	if not view then
		return
	end
	boltViews[instance] = nil
	view.line.boltViews[instance] = nil
	if view.turnConnection then
		view.turnConnection:Disconnect()
	end
end

local function crossed(previous: number?, current: number, moment: number): boolean
	return previous ~= nil and previous < moment and current >= moment
end

local function currentRoutes(line: LineView): BoltRoutes.Routes
	local beltSpeed = line.world.belt:GetAttribute(BoltStationConfig.BELT_SPEED_ATTRIBUTE)
	local speed = if typeof(beltSpeed) == "number" then beltSpeed else BoltStationConfig.BELT_SPEED
	return BoltRoutes.fromWorld(line.world, speed)
end

local function playRouteCues(view: BoltView, routes: BoltRoutes.Routes, route: string, elapsed: number)
	local previous = view.lastRouteElapsed
	view.lastRouteElapsed = elapsed
	if route == BoltStationConfig.INCOMING_ROUTE then
		if crossed(previous, elapsed, routes.landingTime) then
			view.line.landSound:Play()
		end
		return
	end
	if crossed(previous, elapsed, routes.toppleImpactTime) then
		playChildSound(view.body, TOPPLE_SOUND_NAME)
	end
	if crossed(previous, elapsed, routes.dropStartTime) then
		view.line.dropSound:Play()
	end
end

local function updateBolt(view: BoltView, routes: BoltRoutes.Routes, conveyorTime: number)
	local route = view.model:GetAttribute(BoltStationConfig.ROUTE_ATTRIBUTE)
	local startedAt = view.model:GetAttribute(BoltStationConfig.ROUTE_STARTED_AT_ATTRIBUTE)
	if typeof(route) == "string" and typeof(startedAt) == "number" then
		local elapsed = conveyorTime - startedAt
		view.model:PivotTo(routes.poseAt(route, elapsed))
		playRouteCues(view, routes, route, elapsed)
	else
		view.lastRouteElapsed = nil
	end
	if view.isTurning then
		placeNut(view)
		view.isTurning = turnProgress(view) < 1
	end
end

local function stepLine(line: LineView)
	local routes = currentRoutes(line)
	local conveyorTime = ConveyorClock.now(line.world.belt)
	for _, view in line.boltViews do
		updateBolt(view, routes, conveyorTime)
	end
end

local function onRenderStepped()
	for _, line in lineViews do
		stepLine(line)
	end
end

local function addLine(container: Instance, world: BoltStationWorld.Instances)
	local line: LineView = {
		world = world,
		landSound = world.intakeLanding:WaitForChild(LAND_SOUND_NAME) :: Sound,
		dropSound = world.disposalDrop:WaitForChild(DROP_SOUND_NAME) :: Sound,
		boltViews = {},
	}
	if lineViews[container] then
		return
	end
	lineViews[container] = line
	for _, bolt in CollectionService:GetTagged(BoltStationConfig.BOLT_TAG) do
		if bolt:IsDescendantOf(world.boltFolder) then
			task.spawn(bindBolt, bolt)
		end
	end
end

local function removeLine(container: Instance)
	local line = lineViews[container]
	if not line then
		return
	end
	lineViews[container] = nil
	for bolt in line.boltViews do
		unbindBolt(bolt)
	end
end

local function makesBolts(container: Instance): boolean
	return container:GetAttribute(ProductionLineConfig.WORK_AREA_ATTRIBUTE) == ProductionLineConfig.BOLT_AREA
end

local function followArea(container: Instance)
	if not makesBolts(container) then
		removeLine(container)
		return
	end
	local world = BoltStationWorld.fromLine(container)
	if makesBolts(container) then
		addLine(container, world)
	end
end

local function watchLine(container: Instance)
	if areaConnections[container] then
		return
	end
	areaConnections[container] = container:GetAttributeChangedSignal(ProductionLineConfig.WORK_AREA_ATTRIBUTE):Connect(function()
		followArea(container)
	end)
	followArea(container)
end

local function unwatchLine(container: Instance)
	local connection = areaConnections[container]
	if connection then
		connection:Disconnect()
		areaConnections[container] = nil
	end
	removeLine(container)
end

function BoltStationView.start()
	CollectionService:GetInstanceAddedSignal(BoltStationConfig.BOLT_TAG):Connect(bindBolt)
	CollectionService:GetInstanceRemovedSignal(BoltStationConfig.BOLT_TAG):Connect(unbindBolt)
	CollectionService:GetInstanceAddedSignal(ProductionLineConfig.TAG):Connect(watchLine)
	CollectionService:GetInstanceRemovedSignal(ProductionLineConfig.TAG):Connect(unwatchLine)
	for _, container in CollectionService:GetTagged(ProductionLineConfig.TAG) do
		task.spawn(watchLine, container)
	end
	RunService.RenderStepped:Connect(onRenderStepped)
	local stationWorld = BoltStationWorld.resolve()
	addLine(stationWorld.boltFolder, stationWorld)
end

return BoltStationView
