local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoltStationConfig = require(Shared:WaitForChild("BoltStationConfig"))
local BoltStationWorld = require(Shared:WaitForChild("BoltStationWorld"))
local ConveyorClock = require(Shared:WaitForChild("ConveyorClock"))
local HeartLineConfig = require(Shared:WaitForChild("HeartLineConfig"))
local HeartLineRoutes = require(Shared:WaitForChild("HeartLineRoutes"))
local ProductionLineConfig = require(Shared:WaitForChild("ProductionLineConfig"))

local SPLASH_POINT_NAME = "SplashPoint"
local POOL_SURFACE_NAME = "PoolSurface"
local POOL_IMAGE_NAME = "BloodPool"
local LAND_SOUND_NAME = "LandSound"
local DROP_SOUND_NAME = "DropSound"
local STRIKE_SOUND_NAME = "StrikeSound"
local BURST_SOUND_NAME = "BurstSound"
local MIN_STRIKE_PITCH = 0.9
local MAX_STRIKE_PITCH = 1.1
local HIT_PARTICLES: { [string]: number } = { BloodGush = 5, BloodSpray = 10, GoreChunks = 2, BloodMist = 2 }
local POP_PARTICLES: { [string]: number } = { BloodGush = 12, BloodSpray = 22, GoreChunks = 7, BloodMist = 4 }
local POP_PULSES = 3
local POP_PULSE_INTERVAL = 0.08
local HEIGHT_LOSS_PER_HIT = 0.14
local WIDTH_GAIN_PER_HIT = 0.06
local IMPACT_HEIGHT_LOSS = 0.12
local SQUASH_RECOVERY_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POOL_SPREAD_INFO = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POOL_START_SCALE = 0.3
local FULL_POOL_SCALE = 1

type LineView = {
	model: Instance,
	world: BoltStationWorld.Instances,
	heart: BasePart,
	heartSize: Vector3,
	heartOffset: CFrame,
	restPose: CFrame,
	splashPoint: Attachment,
	pool: BasePart,
	poolRest: CFrame,
	poolSurface: SurfaceGui,
	poolImage: ImageLabel,
	landSound: Sound,
	dropSound: Sound,
	strikeSound: Sound,
	burstSound: Sound,
	shownHits: number,
	shownPoppedAt: number?,
	lastCycleElapsed: number?,
	squashTween: Tween?,
	connections: { RBXScriptConnection },
}

local HeartLineView = {}

local random = Random.new()
local lineViews: { [Instance]: LineView } = {}
local areaConnections: { [Instance]: RBXScriptConnection } = {}

local function readNumber(instance: Instance, attribute: string): number?
	local value = instance:GetAttribute(attribute)
	return if typeof(value) == "number" then value else nil
end

local function emit(line: LineView, counts: { [string]: number })
	for emitterName, count in counts do
		local emitter = line.splashPoint:FindFirstChild(emitterName)
		if emitter and emitter:IsA("ParticleEmitter") then
			emitter:Emit(count)
		end
	end
end

local function gush(line: LineView)
	for _ = 1, POP_PULSES do
		emit(line, POP_PARTICLES)
		task.wait(POP_PULSE_INTERVAL)
	end
end

local function squashedSize(line: LineView, heightLoss: number, widthGain: number): Vector3
	local size = line.heartSize
	return Vector3.new(size.X * (1 + widthGain), size.Y * (1 + widthGain), size.Z * (1 - heightLoss))
end

local function squashedCFrame(line: LineView, size: Vector3): CFrame
	return line.restPose * CFrame.new(0, 0, -(line.heartSize.Z - size.Z) / 2)
end

local function cancelSquash(line: LineView)
	local tween = line.squashTween
	if tween then
		tween:Cancel()
		line.squashTween = nil
	end
end

local function holdSquash(line: LineView, hits: number)
	local size = squashedSize(line, HEIGHT_LOSS_PER_HIT * hits, WIDTH_GAIN_PER_HIT * hits)
	line.heart.Size = size
	line.heart.CFrame = squashedCFrame(line, size)
end

local function playHit(line: LineView, hits: number)
	cancelSquash(line)
	local impactSize = squashedSize(line, HEIGHT_LOSS_PER_HIT * hits + IMPACT_HEIGHT_LOSS, WIDTH_GAIN_PER_HIT * hits)
	local settledSize = squashedSize(line, HEIGHT_LOSS_PER_HIT * hits, WIDTH_GAIN_PER_HIT * hits)
	line.heart.Size = impactSize
	line.heart.CFrame = squashedCFrame(line, impactSize)
	local tween = TweenService:Create(line.heart, SQUASH_RECOVERY_INFO, {
		Size = settledSize,
		CFrame = squashedCFrame(line, settledSize),
	})
	line.squashTween = tween
	tween:Play()
	emit(line, HIT_PARTICLES)
	line.strikeSound.PlaybackSpeed = random:NextNumber(MIN_STRIKE_PITCH, MAX_STRIKE_PITCH)
	line.strikeSound:Play()
end

local function playPop(line: LineView)
	cancelSquash(line)
	line.heart.Size = line.heartSize
	line.pool.CFrame = line.poolRest
	line.poolImage.Size = UDim2.fromScale(POOL_START_SCALE, POOL_START_SCALE)
	line.poolSurface.Enabled = true
	TweenService:Create(line.poolImage, POOL_SPREAD_INFO, { Size = UDim2.fromScale(FULL_POOL_SCALE, FULL_POOL_SCALE) }):Play()
	line.burstSound:Play()
	task.spawn(gush, line)
end

local function onHitsChanged(line: LineView)
	local hits = readNumber(line.heart, HeartLineConfig.HITS_ATTRIBUTE) or 0
	if hits > line.shownHits then
		playHit(line, hits)
	end
	line.shownHits = hits
end

local function onPoppedAtChanged(line: LineView)
	local poppedAt = readNumber(line.model, HeartLineConfig.POPPED_AT_ATTRIBUTE)
	if poppedAt and poppedAt ~= line.shownPoppedAt then
		line.shownPoppedAt = poppedAt
		playPop(line)
	end
end

local function crossed(previous: number?, current: number, moment: number): boolean
	return previous ~= nil and previous < moment and current >= moment
end

local function finishCycle(line: LineView)
	line.lastCycleElapsed = nil
	line.pool.CFrame = line.poolRest
	line.poolSurface.Enabled = false
end

local function stepLine(line: LineView)
	local startedAt = readNumber(line.model, HeartLineConfig.CYCLE_STARTED_AT_ATTRIBUTE)
	if not startedAt then
		if line.lastCycleElapsed then
			finishCycle(line)
		end
		return
	end
	local beltSpeed = readNumber(line.world.belt, BoltStationConfig.BELT_SPEED_ATTRIBUTE) or BoltStationConfig.BELT_SPEED
	local routes = HeartLineRoutes.fromWorld(line.world, line.heartOffset, line.poolRest, beltSpeed)
	local elapsed = ConveyorClock.now(line.world.belt) - startedAt
	local previous = line.lastCycleElapsed
	line.lastCycleElapsed = elapsed
	line.heart.CFrame = routes.heartPoseAt(elapsed)
	local poolPose, poolScale = routes.poolPoseAt(elapsed)
	line.pool.CFrame = poolPose
	if elapsed >= routes.poolSlideDuration then
		line.poolImage.Size = UDim2.fromScale(poolScale, poolScale)
	end
	line.poolSurface.Enabled = elapsed < routes.poolDropEndTime
	if crossed(previous, elapsed, routes.poolSlideDuration) then
		line.dropSound:Play()
	end
	if crossed(previous, elapsed, routes.heartLandingTime) then
		line.landSound:Play()
	end
end

local function onRenderStepped()
	for _, line in lineViews do
		stepLine(line)
	end
end

local function makesHearts(model: Instance): boolean
	return model:GetAttribute(ProductionLineConfig.WORK_AREA_ATTRIBUTE) == ProductionLineConfig.HEART_AREA
end

local function addLine(model: Instance)
	local world = BoltStationWorld.fromLine(model)
	local heart = world.boltFolder:WaitForChild(HeartLineConfig.HEART_NAME) :: BasePart
	local pool = model:WaitForChild(HeartLineConfig.POOL_NAME) :: BasePart
	local poolSurface = pool:WaitForChild(POOL_SURFACE_NAME) :: SurfaceGui
	local heartOffset = heart:GetAttribute(HeartLineConfig.REST_OFFSET_ATTRIBUTE) :: CFrame
	local splashPoint = world.belt:WaitForChild(SPLASH_POINT_NAME) :: Attachment
	local line: LineView = {
		model = model,
		world = world,
		heart = heart,
		heartSize = heart.Size,
		heartOffset = heartOffset,
		restPose = world.boltSlot.WorldCFrame * heartOffset,
		splashPoint = splashPoint,
		pool = pool,
		poolRest = pool.CFrame,
		poolSurface = poolSurface,
		poolImage = poolSurface:WaitForChild(POOL_IMAGE_NAME) :: ImageLabel,
		landSound = world.intakeLanding:WaitForChild(LAND_SOUND_NAME) :: Sound,
		dropSound = world.disposalDrop:WaitForChild(DROP_SOUND_NAME) :: Sound,
		strikeSound = splashPoint:WaitForChild(STRIKE_SOUND_NAME) :: Sound,
		burstSound = splashPoint:WaitForChild(BURST_SOUND_NAME) :: Sound,
		shownHits = readNumber(heart, HeartLineConfig.HITS_ATTRIBUTE) or 0,
		shownPoppedAt = readNumber(model, HeartLineConfig.POPPED_AT_ATTRIBUTE),
		lastCycleElapsed = nil,
		squashTween = nil,
		connections = {},
	}
	if lineViews[model] or not makesHearts(model) then
		return
	end
	lineViews[model] = line
	if line.shownHits > 0 then
		holdSquash(line, line.shownHits)
	end
	table.insert(line.connections, heart:GetAttributeChangedSignal(HeartLineConfig.HITS_ATTRIBUTE):Connect(function()
		onHitsChanged(line)
	end))
	table.insert(line.connections, model:GetAttributeChangedSignal(HeartLineConfig.POPPED_AT_ATTRIBUTE):Connect(function()
		onPoppedAtChanged(line)
	end))
end

local function removeLine(model: Instance)
	local line = lineViews[model]
	if not line then
		return
	end
	lineViews[model] = nil
	cancelSquash(line)
	finishCycle(line)
	for _, connection in line.connections do
		connection:Disconnect()
	end
end

local function followArea(model: Instance)
	if makesHearts(model) then
		addLine(model)
	else
		removeLine(model)
	end
end

local function watchLine(model: Instance)
	if areaConnections[model] then
		return
	end
	areaConnections[model] = model:GetAttributeChangedSignal(ProductionLineConfig.WORK_AREA_ATTRIBUTE):Connect(function()
		followArea(model)
	end)
	followArea(model)
end

local function unwatchLine(model: Instance)
	local connection = areaConnections[model]
	if connection then
		connection:Disconnect()
		areaConnections[model] = nil
	end
	removeLine(model)
end

function HeartLineView.start()
	CollectionService:GetInstanceAddedSignal(ProductionLineConfig.TAG):Connect(watchLine)
	CollectionService:GetInstanceRemovedSignal(ProductionLineConfig.TAG):Connect(unwatchLine)
	for _, model in CollectionService:GetTagged(ProductionLineConfig.TAG) do
		task.spawn(watchLine, model)
	end
	RunService.RenderStepped:Connect(onRenderStepped)
end

return HeartLineView
