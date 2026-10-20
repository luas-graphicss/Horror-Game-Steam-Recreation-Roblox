local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GrabConfig = require(Shared:WaitForChild("GrabConfig"))

local RENDER_STEP_NAME = "GrabCarry"
local GRIP_NAME = "GrabGrip"
local CARRY_ACCELERATION = 900
local CARRY_RESPONSIVENESS = 30
local MAX_CARRY_SPEED = 55
local WALL_CLEARANCE = 0.75

type Carry = {
	body: Instance,
	grip: Attachment,
	align: AlignPosition,
	holdDistance: number,
}

local GrabCarry = {}

local player = Players.LocalPlayer
local carry: Carry? = nil
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude

local function movingMass(body: Instance): number
	local mass = 0
	for _, part in body:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored and not part.Massless then
			mass += part:GetMass()
		end
	end
	return mass
end

local function holdPoint(camera: Camera, current: Carry): Vector3
	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local ignored: { Instance } = { camera, current.body }
	if player.Character then
		table.insert(ignored, player.Character)
	end
	castParams.FilterDescendantsInstances = ignored
	local hit = Workspace:Raycast(origin, look * current.holdDistance, castParams)
	return if hit then hit.Position - look * WALL_CLEARANCE else origin + look * current.holdDistance
end

local function onRenderStep()
	local current = carry
	if current then
		current.align.Position = holdPoint(Workspace.CurrentCamera, current)
	end
end

function GrabCarry.stop()
	local current = carry
	if not current then
		return
	end
	carry = nil
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	current.align:Destroy()
	current.grip:Destroy()
end

function GrabCarry.begin(body: Instance, part: BasePart, localGrabPoint: Vector3)
	GrabCarry.stop()
	local grip = Instance.new("Attachment")
	grip.Name = GRIP_NAME
	grip.Position = localGrabPoint
	grip.Parent = part
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = grip
	align.MaxForce = movingMass(body) * CARRY_ACCELERATION
	align.MaxVelocity = MAX_CARRY_SPEED
	align.Responsiveness = CARRY_RESPONSIVENESS
	align.Position = grip.WorldPosition
	align.Parent = part
	local grabDistance = (grip.WorldPosition - Workspace.CurrentCamera.CFrame.Position).Magnitude
	carry = {
		body = body,
		grip = grip,
		align = align,
		holdDistance = math.clamp(grabDistance, GrabConfig.MIN_HOLD_DISTANCE, GrabConfig.MAX_HOLD_DISTANCE),
	}
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

function GrabCarry.carriedBody(): Instance?
	return if carry then carry.body else nil
end

return GrabCarry
