local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))
local ToolCatalog = require(Shared:WaitForChild("ToolCatalog"))

local ASSETS_FOLDER_NAME = "Assets"
local RENDER_STEP_NAME = "ToolViewmodel"
local VIEWMODEL_SCALE = 0.25
local MIN_SCALE_CHANGE = 1e-3
local EQUIP_DURATION = 0.35
local EQUIP_DROP = 1.4
local SWING_DURATION = 0.3
local MIN_SWING_DURATION = 0.08
local SWING_ANGLE = math.rad(30)
local SWING_PUSH = 0.2
local BREATH_FREQUENCY = 1.4
local BREATH_AMPLITUDE = 0.025
local BOB_FREQUENCY = 8.5
local BOB_AMPLITUDE = 0.07
local BOB_VERTICAL_FREQUENCY_RATIO = 2
local BOB_VERTICAL_AMPLITUDE_RATIO = 0.5
local BOB_RESPONSIVENESS = 8
local MIN_WALK_SPEED = 1
local SWAY_STRENGTH = 0.015
local MAX_SWAY = math.rad(4)
local SWAY_RESPONSIVENESS = 14
local MIN_DELTA_TIME = 1 / 240

export type Action = (hold: CFrame, holdScale: number, elapsed: number) -> (CFrame?, number?)

type ToolGrip = {
	gripPosition: Vector3,
	headDirection: Vector3,
	faceDirection: Vector3,
	gripCenter: Vector3,
}

type ToolPose = {
	template: Model,
	holdOffset: CFrame,
	gripPivot: CFrame,
}

local TOOL_GRIPS: { [string]: ToolGrip } = {
	[ShopCatalog.WRENCH_ITEM_ID] = {
		gripPosition = Vector3.new(1.75, -1.5, -2.1),
		headDirection = Vector3.new(-0.35, 0.6, -0.72),
		faceDirection = Vector3.new(0.3, 0.3, 0.9),
		gripCenter = Vector3.new(1.36, 0, 0),
	},
	[ShopCatalog.CROWBAR_ITEM_ID] = {
		gripPosition = Vector3.new(1.85, -1.5, -2.15),
		headDirection = Vector3.new(-0.36, 0.55, -0.75),
		faceDirection = Vector3.new(0.2, 0.4, -0.9),
		gripCenter = Vector3.new(1.62, 0.053, 0),
	},
	[ShopCatalog.HAMMER_ITEM_ID] = {
		gripPosition = Vector3.new(1.9, -2.3, -2.2),
		headDirection = Vector3.new(0.05, 0.9, -0.4),
		faceDirection = Vector3.new(-0.98, -0.05, -0.2),
		gripCenter = Vector3.new(1.15, 0, 0),
	},
}

local ToolViewmodel = {}

local player = Players.LocalPlayer
local assets = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME)
local poses: { [string]: ToolPose } = {}
local viewmodel: Model? = nil
local viewmodelToolId: string? = nil
local appliedScale = VIEWMODEL_SCALE
local equippedAt = 0
local swingStartedAt = -math.huge
local swingDuration = SWING_DURATION
local action: Action? = nil
local actionStartedAt = 0
local bobPhase = 0
local bobWeight = 0
local sway = Vector2.zero
local lastCameraRotation = CFrame.identity

local function buildPose(itemId: string, grip: ToolGrip): ToolPose
	local lengthAxis = -grip.headDirection.Unit
	local faceAxis = (grip.faceDirection - lengthAxis * grip.faceDirection:Dot(lengthAxis)).Unit
	local widthAxis = faceAxis:Cross(lengthAxis)
	local rotation = CFrame.fromMatrix(Vector3.zero, lengthAxis, widthAxis, faceAxis)
	local gripCenter = grip.gripCenter * VIEWMODEL_SCALE
	return {
		template = assets:WaitForChild(ToolCatalog.viewmodelName(itemId)) :: Model,
		holdOffset = CFrame.new(grip.gripPosition * VIEWMODEL_SCALE) * rotation * CFrame.new(-gripCenter),
		gripPivot = CFrame.new(gripCenter),
	}
end

for itemId, grip in TOOL_GRIPS do
	poses[itemId] = buildPose(itemId, grip)
end

local function livingHumanoid(): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function isCaptured(): boolean
	return player:GetAttribute(PlayerAttributes.CAPTURED) == true
end

local function equippedToolId(): string?
	local itemId = player:GetAttribute(PlayerAttributes.EQUIPPED_TOOL)
	if typeof(itemId) ~= "string" or not poses[itemId] then
		return nil
	end
	return if player:GetAttribute(PlayerAttributes.ownedItem(itemId)) == true then itemId else nil
end

local function unequip()
	if viewmodel then
		viewmodel:Destroy()
		viewmodel = nil
	end
	viewmodelToolId = nil
	action = nil
end

local function equip(camera: Camera, itemId: string): Model
	unequip()
	local model = poses[itemId].template:Clone()
	model:ScaleTo(VIEWMODEL_SCALE)
	model.Parent = camera
	viewmodel = model
	viewmodelToolId = itemId
	appliedScale = VIEWMODEL_SCALE
	equippedAt = os.clock()
	lastCameraRotation = camera.CFrame.Rotation
	return model
end

local function updateSway(camera: Camera, deltaTime: number)
	local pitchDelta, yawDelta = lastCameraRotation:ToObjectSpace(camera.CFrame.Rotation):ToOrientation()
	lastCameraRotation = camera.CFrame.Rotation
	local strength = SWAY_STRENGTH / math.max(deltaTime, MIN_DELTA_TIME)
	local target = Vector2.new(
		math.clamp(-yawDelta * strength, -MAX_SWAY, MAX_SWAY),
		math.clamp(-pitchDelta * strength, -MAX_SWAY, MAX_SWAY)
	)
	sway = sway:Lerp(target, math.min(deltaTime * SWAY_RESPONSIVENESS, 1))
end

local function updateBob(humanoid: Humanoid, deltaTime: number)
	local rootPart = humanoid.RootPart
	local velocity = if rootPart then rootPart.AssemblyLinearVelocity else Vector3.zero
	local walkRatio = math.clamp(Vector3.new(velocity.X, 0, velocity.Z).Magnitude / math.max(humanoid.WalkSpeed, MIN_WALK_SPEED), 0, 1)
	bobWeight += (walkRatio - bobWeight) * math.min(deltaTime * BOB_RESPONSIVENESS, 1)
	bobPhase += deltaTime * BOB_FREQUENCY * bobWeight
end

local function holdCFrame(camera: Camera, pose: ToolPose, now: number): CFrame
	local equipProgress = TweenService:GetValue(math.min((now - equippedAt) / EQUIP_DURATION, 1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local swing = math.sin(math.clamp((now - swingStartedAt) / swingDuration, 0, 1) * math.pi)
	local breath = math.sin(now * BREATH_FREQUENCY) * BREATH_AMPLITUDE
	local bob = Vector3.new(
		math.sin(bobPhase) * BOB_AMPLITUDE,
		math.sin(bobPhase * BOB_VERTICAL_FREQUENCY_RATIO) * BOB_AMPLITUDE * BOB_VERTICAL_AMPLITUDE_RATIO,
		0
	) * bobWeight
	local offset = (bob + Vector3.new(0, breath - (1 - equipProgress) * EQUIP_DROP, -swing * SWING_PUSH)) * VIEWMODEL_SCALE
	return camera.CFrame
		* CFrame.new(offset)
		* CFrame.Angles(sway.Y, sway.X, 0)
		* pose.holdOffset
		* pose.gripPivot
		* CFrame.Angles(0, 0, swing * SWING_ANGLE)
		* pose.gripPivot:Inverse()
end

local function resolveFrame(hold: CFrame, now: number): (CFrame, number)
	local currentAction = action
	if currentAction then
		local cframe, scale = currentAction(hold, VIEWMODEL_SCALE, now - actionStartedAt)
		if cframe and scale then
			return cframe, scale
		end
		action = nil
	end
	return hold, VIEWMODEL_SCALE
end

local function applyScale(model: Model, scale: number)
	if math.abs(scale - appliedScale) >= MIN_SCALE_CHANGE then
		model:ScaleTo(scale)
		appliedScale = scale
	end
end

local function onRenderStep(deltaTime: number)
	local camera = Workspace.CurrentCamera
	local humanoid = livingHumanoid()
	local itemId = equippedToolId()
	if not humanoid or not itemId or isCaptured() then
		unequip()
		return
	end
	local model = if viewmodel and viewmodelToolId == itemId then viewmodel else equip(camera, itemId)
	updateSway(camera, deltaTime)
	updateBob(humanoid, deltaTime)
	local now = os.clock()
	local cframe, scale = resolveFrame(holdCFrame(camera, poses[itemId], now), now)
	applyScale(model, scale)
	model:PivotTo(cframe)
end

function ToolViewmodel.playSwing(turnInterval: number)
	swingStartedAt = os.clock()
	swingDuration = math.clamp(turnInterval, MIN_SWING_DURATION, SWING_DURATION)
end

function ToolViewmodel.playAction(newAction: Action)
	action = newAction
	actionStartedAt = os.clock()
end

function ToolViewmodel.isActing(): boolean
	return action ~= nil
end

function ToolViewmodel.start()
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 2, onRenderStep)
end

return ToolViewmodel
