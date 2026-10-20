local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GAZE_TAG = "GazesAtPlayer"
local MAX_YAW_ATTRIBUTE = "GazeMaxYaw"
local MAX_PITCH_ATTRIBUTE = "GazeMaxPitch"
local TURN_RESPONSIVENESS = 5
local FULL_TURN = 2 * math.pi
local MIN_HORIZONTAL_DISTANCE = 1e-3

type Gazer = {
	instance: PVInstance,
	restPivot: CFrame,
	maxYaw: number,
	maxPitch: number,
	yaw: number,
	pitch: number,
}

local PlayerGaze = {}

local gazers: { [Instance]: Gazer } = {}

local function limitOf(instance: Instance, attribute: string): number
	local degrees = instance:GetAttribute(attribute)
	return math.rad(if typeof(degrees) == "number" then degrees else 0)
end

local function bind(instance: Instance)
	if not instance:IsA("PVInstance") or gazers[instance] then
		return
	end
	gazers[instance] = {
		instance = instance,
		restPivot = instance:GetPivot(),
		maxYaw = limitOf(instance, MAX_YAW_ATTRIBUTE),
		maxPitch = limitOf(instance, MAX_PITCH_ATTRIBUTE),
		yaw = 0,
		pitch = 0,
	}
end

local function unbind(instance: Instance)
	gazers[instance] = nil
end

local function wrapAngle(angle: number): number
	return (angle + math.pi) % FULL_TURN - math.pi
end

local function desiredAngles(gazer: Gazer, target: Vector3): (number, number)
	local offset = gazer.restPivot:PointToObjectSpace(target)
	local horizontalDistance = math.max(Vector2.new(offset.X, offset.Z).Magnitude, MIN_HORIZONTAL_DISTANCE)
	local yaw = math.clamp(math.atan2(-offset.X, -offset.Z), -gazer.maxYaw, gazer.maxYaw)
	local pitch = math.clamp(math.atan2(offset.Y, horizontalDistance), -gazer.maxPitch, gazer.maxPitch)
	return yaw, pitch
end

local function onRenderStepped(deltaTime: number)
	local target = Workspace.CurrentCamera.CFrame.Position
	local blend = 1 - math.exp(-TURN_RESPONSIVENESS * deltaTime)
	for _, gazer in gazers do
		local yaw, pitch = desiredAngles(gazer, target)
		gazer.yaw = wrapAngle(gazer.yaw + wrapAngle(yaw - gazer.yaw) * blend)
		gazer.pitch += (pitch - gazer.pitch) * blend
		gazer.instance:PivotTo(gazer.restPivot * CFrame.Angles(0, gazer.yaw, 0) * CFrame.Angles(gazer.pitch, 0, 0))
	end
end

function PlayerGaze.start()
	CollectionService:GetInstanceAddedSignal(GAZE_TAG):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(GAZE_TAG):Connect(unbind)
	for _, instance in CollectionService:GetTagged(GAZE_TAG) do
		bind(instance)
	end
	RunService.RenderStepped:Connect(onRenderStepped)
end

return PlayerGaze
