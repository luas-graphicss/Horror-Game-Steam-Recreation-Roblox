local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WallEyeConfig = require(Shared:WaitForChild("WallEyeConfig"))
local WallEyeTrail = require(Shared:WaitForChild("WallEyeTrail"))
local WallEyeWorld = require(Shared:WaitForChild("WallEyeWorld"))
local WallEyeCord = require(script.Parent:WaitForChild("WallEyeCord"))

local RENDER_STEP_NAME = "WallEyeView"
local SCREAM_SOUND_NAME = "ScreamSound"
local POSITION_SMOOTH_TIME = 0.12
local GAZE_RESPONSIVENESS = 14
local NEST_PROXIMITY = 0.6
local NEST_GAZE_LIMIT = math.rad(38)
local STALK_GAZE_LIMIT = math.rad(75)
local STALK_LOOKUP_DISTANCE = 0.5
local PUPIL_RESPONSIVENESS = 3
local PUPIL_MIN_RESIZE = 0.003
local HIPPUS_DEPTH = 0.04
local HIPPUS_SPEED = 0.7
local BREATH_RESPONSIVENESS = 1.5
local LOBE_SWELL = 0.08
local LOBE_SPREAD = 0.035
local RIM_PULSE = 0.03
local RIM_PUCKER = 0.22
local RIM_PUCKER_LIFT = 0.06
local PUCKER_DISTANCE = 3.5
local PUCKER_RESPONSIVENESS = 4
local HIDDEN_TRANSPARENCY = 1
local FULL_CIRCLE = 2 * math.pi

local PUPIL_DILATION = {
	[WallEyeConfig.RESTING_STATE] = 1.15,
	[WallEyeConfig.HUNTING_STATE] = 1.6,
	[WallEyeConfig.RETREATING_STATE] = 1,
}
local BREATH_PERIOD = {
	[WallEyeConfig.RESTING_STATE] = 4.2,
	[WallEyeConfig.HUNTING_STATE] = 2.1,
	[WallEyeConfig.RETREATING_STATE] = 1.6,
}
local SACCADE_PROFILES = {
	[WallEyeConfig.RESTING_STATE] = { minInterval = 0.6, maxInterval = 2.2, maxAngle = math.rad(2.5) },
	[WallEyeConfig.HUNTING_STATE] = { minInterval = 1.8, maxInterval = 3.5, maxAngle = math.rad(0.6) },
	[WallEyeConfig.RETREATING_STATE] = { minInterval = 0.12, maxInterval = 0.45, maxAngle = math.rad(4.5) },
}

type NestBone = {
	bone: Bone,
	radial: Vector3,
	phase: number,
}

type EyeView = {
	world: WallEyeWorld.Instances,
	state: string,
	restPoint: Vector3,
	mouthPoint: Vector3,
	socketNormal: Vector3,
	targetPosition: Vector3,
	displayPosition: Vector3,
	displacement: Vector3,
	gaze: Vector3,
	saccadeOffset: CFrame,
	nextSaccadeAt: number,
	eyeParts: { BasePart },
	eyeOffsets: { CFrame },
	eyeTargets: { CFrame },
	pupilBaseSize: Vector3,
	pupilScale: number,
	appliedPupilScale: number,
	trail: { Vector3 },
	trailDirty: boolean,
	cordBones: { Bone },
	cordSolver: WallEyeCord.Solver,
	lobeBones: { NestBone },
	rimBones: { NestBone },
	breathPeriod: number,
	breathPhase: number,
	pucker: number,
	isPlucked: boolean,
}

local WallEyeView = {}

local random = Random.new()
local views: { [Instance]: EyeView } = {}
local attributeConnections: { [Instance]: RBXScriptConnection } = {}
local displacementSources: { [Instance]: () -> Vector3? } = {}

local function smoothing(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

local function rotateToward(from: Vector3, to: Vector3, angle: number): Vector3
	local axis = from:Cross(to)
	if axis.Magnitude < 1e-6 then
		axis = from:Cross(Vector3.yAxis)
		if axis.Magnitude < 1e-6 then
			axis = from:Cross(Vector3.xAxis)
		end
	end
	return CFrame.fromAxisAngle(axis.Unit, angle):VectorToWorldSpace(from).Unit
end

local function angleBetween(a: Vector3, b: Vector3): number
	return math.acos(math.clamp(a:Dot(b), -1, 1))
end

local function clampDirection(direction: Vector3, axis: Vector3, maxAngle: number): Vector3
	if angleBetween(direction, axis) <= maxAngle then
		return direction
	end
	return rotateToward(axis, direction, maxAngle)
end

local function slerpDirection(from: Vector3, to: Vector3, alpha: number): Vector3
	local angle = angleBetween(from, to)
	if angle < 1e-4 then
		return to
	end
	return rotateToward(from, to, angle * alpha)
end

local function upHintFor(direction: Vector3): Vector3
	return if math.abs(direction.Y) > 0.98 then Vector3.zAxis else Vector3.yAxis
end

local function readVector(view: EyeView, name: string, fallback: Vector3): Vector3
	local value = view.world.model:GetAttribute(name)
	return if typeof(value) == "Vector3" then value else fallback
end

local function concealPluckedEye(view: EyeView): boolean
	if view.isPlucked or view.world.model:GetAttribute(WallEyeConfig.PLUCKED_ATTRIBUTE) ~= true then
		return false
	end
	view.isPlucked = true
	for _, part in view.eyeParts do
		part.Transparency = HIDDEN_TRANSPARENCY
	end
	return true
end

local function scream(view: EyeView)
	local sound = view.world.socket:FindFirstChild(SCREAM_SOUND_NAME)
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

local function onAttributeChanged(view: EyeView, name: string)
	if name == WallEyeConfig.EYE_POSITION_ATTRIBUTE then
		view.targetPosition = readVector(view, name, view.restPoint)
	elseif name == WallEyeConfig.STATE_ATTRIBUTE then
		local value = view.world.model:GetAttribute(name)
		view.state = if typeof(value) == "string" and PUPIL_DILATION[value] then value else WallEyeConfig.RESTING_STATE
		view.nextSaccadeAt = 0
	elseif name == WallEyeConfig.PLUCKED_ATTRIBUTE then
		if concealPluckedEye(view) then
			scream(view)
		end
	elseif WallEyeTrail.isTrailAttribute(name) then
		view.trailDirty = true
	end
end

local function stalkDirection(view: EyeView, eyePosition: Vector3): Vector3
	local trail = view.trail
	for index = #trail, 1, -1 do
		local offset = trail[index] - eyePosition
		if offset.Magnitude > STALK_LOOKUP_DISTANCE then
			return offset.Unit
		end
	end
	local toMouth = view.mouthPoint - eyePosition
	return if toMouth.Magnitude > 1e-3 then toMouth.Unit else -view.socketNormal
end

local function updateSaccade(view: EyeView, now: number)
	if now < view.nextSaccadeAt then
		return
	end
	local profile = SACCADE_PROFILES[view.state]
	local angle = random:NextNumber(0, profile.maxAngle)
	local direction = random:NextNumber(0, FULL_CIRCLE)
	view.saccadeOffset = CFrame.Angles(math.sin(direction) * angle, math.cos(direction) * angle, 0)
	view.nextSaccadeAt = now + random:NextNumber(profile.minInterval, profile.maxInterval)
end

local function updateGaze(view: EyeView, eyePosition: Vector3, dt: number, camera: Camera)
	local toCamera = camera.CFrame.Position - eyePosition
	local desired = if toCamera.Magnitude > 1e-3 then toCamera.Unit else view.socketNormal
	desired = (CFrame.lookAt(Vector3.zero, desired, upHintFor(desired)) * view.saccadeOffset).LookVector
	if (eyePosition - view.restPoint).Magnitude < NEST_PROXIMITY then
		desired = clampDirection(desired, view.socketNormal, NEST_GAZE_LIMIT)
	else
		desired = clampDirection(desired, -stalkDirection(view, eyePosition), STALK_GAZE_LIMIT)
	end
	view.gaze = slerpDirection(view.gaze, desired, smoothing(GAZE_RESPONSIVENESS, dt))
end

local function placeEye(view: EyeView, eyeCFrame: CFrame)
	for index, offset in view.eyeOffsets do
		view.eyeTargets[index] = eyeCFrame * offset
	end
	Workspace:BulkMoveTo(view.eyeParts, view.eyeTargets, Enum.BulkMoveMode.FireCFrameChanged)
end

local function updatePupil(view: EyeView, dt: number, now: number)
	local hippus = 1 + HIPPUS_DEPTH * math.noise(now * HIPPUS_SPEED, 7.3)
	view.pupilScale += (PUPIL_DILATION[view.state] * hippus - view.pupilScale) * smoothing(PUPIL_RESPONSIVENESS, dt)
	if math.abs(view.pupilScale - view.appliedPupilScale) < PUPIL_MIN_RESIZE then
		return
	end
	view.appliedPupilScale = view.pupilScale
	local baseSize = view.pupilBaseSize
	view.world.pupil.Size = Vector3.new(baseSize.X * view.pupilScale, baseSize.Y * view.pupilScale, baseSize.Z)
end

local function placeCord(view: EyeView, eyeCFrame: CFrame, now: number)
	local frames = WallEyeCord.solve(view.cordSolver, eyeCFrame, view.trail, now)
	local rootInverse = view.world.cordRoot.CFrame:Inverse()
	for index, bone in view.cordBones do
		bone.CFrame = rootInverse * frames[index]
	end
end

local function animateNest(view: EyeView, eyePosition: Vector3, dt: number)
	view.breathPeriod += (BREATH_PERIOD[view.state] - view.breathPeriod) * smoothing(BREATH_RESPONSIVENESS, dt)
	view.breathPhase = (view.breathPhase + dt * FULL_CIRCLE / view.breathPeriod) % FULL_CIRCLE
	local eyeAway = (eyePosition - view.restPoint).Magnitude > PUCKER_DISTANCE
	view.pucker += ((if eyeAway then 1 else 0) - view.pucker) * smoothing(PUCKER_RESPONSIVENESS, dt)
	for _, lobe in view.lobeBones do
		local wave = math.sin(view.breathPhase + lobe.phase)
		lobe.bone.Transform = CFrame.new(lobe.radial * (LOBE_SPREAD * wave) - Vector3.zAxis * (LOBE_SWELL * wave))
	end
	for _, rim in view.rimBones do
		local wave = math.sin(view.breathPhase * 1.3 + rim.phase)
		local radial = RIM_PULSE * wave - RIM_PUCKER * view.pucker
		local lift = RIM_PULSE * 0.8 * wave + RIM_PUCKER_LIFT * view.pucker
		rim.bone.Transform = CFrame.new(rim.radial * radial - Vector3.zAxis * lift)
	end
end

local function updateDisplacement(view: EyeView)
	local model = view.world.model
	local source = displacementSources[model]
	if not source then
		return
	end
	local displacement = source()
	if displacement then
		view.displacement = displacement
		return
	end
	displacementSources[model] = nil
	view.displayPosition += view.displacement
	view.displacement = Vector3.zero
end

local function renderEye(view: EyeView, dt: number, now: number, camera: Camera)
	if view.trailDirty then
		view.trailDirty = false
		view.trail = WallEyeTrail.read(view.world.model)
	end
	view.displayPosition = view.displayPosition:Lerp(view.targetPosition, 1 - math.exp(-dt / POSITION_SMOOTH_TIME))
	updateDisplacement(view)
	local eyePosition = view.displayPosition + view.displacement
	updateSaccade(view, now)
	updateGaze(view, eyePosition, dt, camera)
	local eyeCFrame = CFrame.lookAt(eyePosition, eyePosition + view.gaze, upHintFor(view.gaze))
	if not view.isPlucked then
		placeEye(view, eyeCFrame)
		updatePupil(view, dt, now)
	end
	placeCord(view, eyeCFrame, now)
	animateNest(view, eyePosition, dt)
end

local function onRenderStep(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	for _, view in views do
		renderEye(view, dt, now, camera)
	end
end

local function collectEyeParts(world: WallEyeWorld.Instances): ({ BasePart }, { CFrame })
	local pivot = world.eye:GetPivot()
	local parts, offsets = {}, {}
	for _, part in { world.sclera, world.iris, world.cornea, world.pupil, world.muscles } do
		table.insert(parts, part)
		table.insert(offsets, pivot:ToObjectSpace(part.CFrame))
	end
	return parts, offsets
end

local function collectCordBones(world: WallEyeWorld.Instances): { Bone }
	local bones = {}
	for _, child in world.cordRoot:GetChildren() do
		if child:IsA("Bone") then
			table.insert(bones, child)
		end
	end
	table.sort(bones, function(a: Bone, b: Bone)
		return a.Name < b.Name
	end)
	return bones
end

local function collectNestBones(world: WallEyeWorld.Instances): ({ NestBone }, { NestBone })
	local lobes, rims = {}, {}
	local center = world.nestRoot.CFrame:PointToObjectSpace(world.socket.Position)
	for _, child in world.nestRoot:GetChildren() do
		if not child:IsA("Bone") then
			continue
		end
		local offset = child.CFrame.Position - center
		local flat = Vector3.new(offset.X, offset.Y, 0)
		local radial = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero
		local angle = math.atan2(flat.Y, flat.X)
		if string.find(child.Name, "^Lobe") then
			table.insert(lobes, { bone = child, radial = radial, phase = angle })
		elseif string.find(child.Name, "^Rim") then
			table.insert(rims, { bone = child, radial = radial, phase = angle * 2 })
		end
	end
	return lobes, rims
end

local function createView(model: Model): EyeView
	local world = WallEyeWorld.resolve(model)
	local restPoint = world.eyeRest.WorldPosition
	local mouthPoint = world.cordMouth.WorldPosition
	local socketNormal = world.socket.CFrame.LookVector
	local eyeParts, eyeOffsets = collectEyeParts(world)
	local cordBones = collectCordBones(world)
	local lobeBones, rimBones = collectNestBones(world)
	local view: EyeView = {
		world = world,
		state = WallEyeConfig.RESTING_STATE,
		restPoint = restPoint,
		mouthPoint = mouthPoint,
		socketNormal = socketNormal,
		targetPosition = restPoint,
		displayPosition = restPoint,
		displacement = Vector3.zero,
		gaze = socketNormal,
		saccadeOffset = CFrame.identity,
		nextSaccadeAt = 0,
		eyeParts = eyeParts,
		eyeOffsets = eyeOffsets,
		eyeTargets = {},
		pupilBaseSize = world.pupil.Size,
		pupilScale = 1,
		appliedPupilScale = 1,
		trail = {},
		trailDirty = true,
		cordBones = cordBones,
		cordSolver = WallEyeCord.new({
			eyeRadius = WallEyeConfig.EYE_RADIUS,
			mouthPoint = mouthPoint,
			sinkPoint = world.cordSink.WorldPosition,
		}, #cordBones, WallEyeConfig.CORD_LENGTH),
		lobeBones = lobeBones,
		rimBones = rimBones,
		breathPeriod = BREATH_PERIOD[WallEyeConfig.RESTING_STATE],
		breathPhase = 0,
		pucker = 0,
		isPlucked = false,
	}
	view.targetPosition = readVector(view, WallEyeConfig.EYE_POSITION_ATTRIBUTE, restPoint)
	view.displayPosition = view.targetPosition
	onAttributeChanged(view, WallEyeConfig.STATE_ATTRIBUTE)
	concealPluckedEye(view)
	return view
end

local function bindEye(instance: Instance)
	if not instance:IsA("Model") or views[instance] then
		return
	end
	local view = createView(instance)
	if views[instance] or not instance:IsDescendantOf(Workspace) then
		return
	end
	views[instance] = view
	attributeConnections[instance] = instance.AttributeChanged:Connect(function(name: string)
		onAttributeChanged(view, name)
	end)
end

local function unbindEye(instance: Instance)
	local connection = attributeConnections[instance]
	if connection then
		connection:Disconnect()
	end
	attributeConnections[instance] = nil
	displacementSources[instance] = nil
	views[instance] = nil
end

function WallEyeView.displaceEye(model: Instance, source: () -> Vector3?)
	displacementSources[model] = source
end

function WallEyeView.start()
	CollectionService:GetInstanceAddedSignal(WallEyeConfig.TAG):Connect(bindEye)
	CollectionService:GetInstanceRemovedSignal(WallEyeConfig.TAG):Connect(unbindEye)
	for _, model in CollectionService:GetTagged(WallEyeConfig.TAG) do
		task.spawn(bindEye, model)
	end
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

return WallEyeView
