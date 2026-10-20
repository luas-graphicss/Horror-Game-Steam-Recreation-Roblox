local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local REMOVE_STEP_NAME = "CameraTremorRemove"
local APPLY_STEP_NAME = "CameraTremorApply"
local PITCH_AXIS = 1
local YAW_AXIS = 2
local ROLL_AXIS = 3
local NOISE_SEED = 0.61
local ROLL_SHARE = 0.4
local STILL_TURN_SPEED = math.rad(12)
local STILL_MOVE_SPEED = 0.8
local SETTLE_RATE = 1.2
local DISTURB_RATE = 10
local TREMOR_LAYERS = {
	{ frequency = 0.55, angle = math.rad(0.7) },
	{ frequency = 4.5, angle = math.rad(0.12) },
}
local SHAKE_NOISE_LAYER = #TREMOR_LAYERS + 1
local SHAKE_FREQUENCY = 16
local SHAKE_MAX_ANGLE = math.rad(3)
local SHAKE_DECAY_RATE = 1.6

local CameraTremor = {}

local appliedTremor = CFrame.identity
local previousView: CFrame? = nil
local intensity = 0
local trauma = 0

local function isPlayerControlled(camera: Camera): boolean
	return camera.CameraType == Enum.CameraType.Custom
end

local function removeTremor()
	local camera = Workspace.CurrentCamera
	if isPlayerControlled(camera) then
		camera.CFrame *= appliedTremor:Inverse()
	end
	appliedTremor = CFrame.identity
end

local function isViewStill(view: CFrame, dt: number): boolean
	local previous = previousView
	previousView = view
	if not previous or dt <= 0 then
		return false
	end
	local turned = math.acos(math.clamp(previous.LookVector:Dot(view.LookVector), -1, 1))
	local moved = (view.Position - previous.Position).Magnitude
	return turned / dt < STILL_TURN_SPEED and moved / dt < STILL_MOVE_SPEED
end

local function noise(time: number, axis: number, layer: number): number
	return math.noise(time, axis + NOISE_SEED, layer)
end

local function tremorAt(now: number, strength: number): CFrame
	local pitch, yaw, roll = 0, 0, 0
	for layer, settings in TREMOR_LAYERS do
		local time = now * settings.frequency
		pitch += noise(time, PITCH_AXIS, layer) * settings.angle
		yaw += noise(time, YAW_AXIS, layer) * settings.angle
		roll += noise(time, ROLL_AXIS, layer) * settings.angle * ROLL_SHARE
	end
	return CFrame.Angles(pitch * strength, yaw * strength, roll * strength)
end

local function shakeAt(now: number): CFrame
	local angle = trauma * trauma * SHAKE_MAX_ANGLE
	local time = now * SHAKE_FREQUENCY
	return CFrame.Angles(
		noise(time, PITCH_AXIS, SHAKE_NOISE_LAYER) * angle,
		noise(time, YAW_AXIS, SHAKE_NOISE_LAYER) * angle,
		noise(time, ROLL_AXIS, SHAKE_NOISE_LAYER) * angle * ROLL_SHARE
	)
end

local function applyTremor(dt: number)
	trauma = math.max(trauma - SHAKE_DECAY_RATE * dt, 0)
	local camera = Workspace.CurrentCamera
	if not isPlayerControlled(camera) then
		previousView = nil
		intensity = 0
		return
	end
	local view = camera.CFrame
	local isStill = isViewStill(view, dt)
	local target = if isStill then 1 else 0
	local rate = if isStill then SETTLE_RATE else DISTURB_RATE
	intensity += (target - intensity) * (1 - math.exp(-rate * dt))
	local now = os.clock()
	appliedTremor = tremorAt(now, intensity) * shakeAt(now)
	camera.CFrame = view * appliedTremor
end

function CameraTremor.shake(strength: number)
	trauma = math.max(trauma, math.clamp(strength, 0, 1))
end

function CameraTremor.start()
	RunService:BindToRenderStep(REMOVE_STEP_NAME, Enum.RenderPriority.Camera.Value - 1, removeTremor)
	RunService:BindToRenderStep(APPLY_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, applyTremor)
end

return CameraTremor
