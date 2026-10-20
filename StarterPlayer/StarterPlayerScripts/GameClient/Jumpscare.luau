local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CaptureConfig = require(Shared:WaitForChild("CaptureConfig"))
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local WallEyeConfig = require(Shared:WaitForChild("WallEyeConfig"))
local WallEyeWorld = require(Shared:WaitForChild("WallEyeWorld"))

local PLAYER_GUI_NAME = "PlayerGui"
local OVERLAY_NAME = "CaptureOverlay"
local BLACKOUT_NAME = "Blackout"
local SCREAM_NAME = "JumpscareScream"
local GRADE_NAME = "JumpscareGrade"
local FLASH_NAME = "JumpscareFlash"
local RENDER_STEP_NAME = "Jumpscare"
local HUMANOID_NAME = "Humanoid"
local GAMEPLAY_GUI_NAMES = { "HUD", "ResourceHud" }
local LUNGE_DURATION = 0.16
local LUNGE_START_DISTANCE = 3.6
local CLOSE_DISTANCE = 2.3
local SHAKE_FREQUENCY = 24
local SHAKE_ANGLE = math.rad(4)
local SHAKE_OFFSET = 0.12
local SHAKE_NOISE_SEED = 0.37
local FADE_IN_DURATION = 0.9
local FLASH_COLOR = Color3.fromRGB(255, 214, 196)
local FLASH_BRIGHTNESS = 2.5
local FLASH_RANGE = 8
local GRADE_BRIGHTNESS = -0.12
local GRADE_CONTRAST = 0.45
local GRADE_SATURATION = -0.35
local GRADE_TINT = Color3.fromRGB(255, 200, 190)
local MIN_VIEW_OFFSET = 1e-3

local Jumpscare = {}

local player = Players.LocalPlayer
local capturingSclera: BasePart
local overlay: ScreenGui
local blackout: Frame
local scream: Sound
local screamVolume: number
local grade: ColorCorrectionEffect
local flashAnchor: Attachment
local flash: PointLight
local startedAt = 0
local viewDirection = Vector3.zAxis
local pendingFadeOut: thread? = nil

local function isCaptured(): boolean
	return player:GetAttribute(PlayerAttributes.CAPTURED) == true
end

local function setGameplayGuiEnabled(enabled: boolean)
	local playerGui = player:FindFirstChild(PLAYER_GUI_NAME)
	if not playerGui then
		return
	end
	for _, name in GAMEPLAY_GUI_NAMES do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") then
			gui.Enabled = enabled
		end
	end
end

local function followCharacter(character: Model?)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and character == player.Character then
		Workspace.CurrentCamera.CameraSubject = humanoid
	end
end

local function onCharacterAdded(character: Model)
	character:WaitForChild(HUMANOID_NAME)
	followCharacter(character)
end

local function shakeNoise(time: number, axis: number): number
	return math.noise(time, axis + SHAKE_NOISE_SEED)
end

local function shakeOffset(now: number): CFrame
	local time = now * SHAKE_FREQUENCY
	local position = Vector3.new(shakeNoise(time, 1), shakeNoise(time, 2), 0) * SHAKE_OFFSET
	return CFrame.new(position)
		* CFrame.Angles(shakeNoise(time, 3) * SHAKE_ANGLE, shakeNoise(time, 4) * SHAKE_ANGLE, shakeNoise(time, 5) * SHAKE_ANGLE)
end

local function lungeDistance(now: number): number
	local progress = math.min((now - startedAt) / LUNGE_DURATION, 1)
	local eased = TweenService:GetValue(progress, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	return LUNGE_START_DISTANCE + (CLOSE_DISTANCE - LUNGE_START_DISTANCE) * eased
end

local function nearestSclera(position: Vector3): BasePart?
	local nearest: BasePart? = nil
	local nearestDistance = math.huge
	for _, eye in CollectionService:GetTagged(WallEyeConfig.TAG) do
		local sclera = WallEyeWorld.findSclera(eye)
		local distance = if sclera then (sclera.Position - position).Magnitude else math.huge
		if distance < nearestDistance then
			nearest = sclera
			nearestDistance = distance
		end
	end
	return nearest
end

local function onRenderStep()
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	local eyeCenter = capturingSclera.Position
	local cameraPosition = eyeCenter + viewDirection * lungeDistance(now)
	camera.CFrame = CFrame.lookAt(cameraPosition, eyeCenter) * shakeOffset(now)
	camera.Focus = CFrame.new(eyeCenter)
	flashAnchor.WorldPosition = cameraPosition
end

local function fadeOut()
	pendingFadeOut = nil
	local fadeInfo = TweenInfo.new(CaptureConfig.FADE_OUT_DURATION)
	TweenService:Create(blackout, fadeInfo, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(scream, fadeInfo, { Volume = 0 }):Play()
end

local function beginCapture()
	local camera = Workspace.CurrentCamera
	local sclera = nearestSclera(camera.CFrame.Position)
	if not sclera then
		return
	end
	capturingSclera = sclera
	local towardCamera = camera.CFrame.Position - sclera.Position
	viewDirection = if towardCamera.Magnitude > MIN_VIEW_OFFSET then towardCamera.Unit else -camera.CFrame.LookVector
	startedAt = os.clock()
	camera.CameraType = Enum.CameraType.Scriptable
	setGameplayGuiEnabled(false)
	blackout.BackgroundTransparency = 1
	overlay.Enabled = true
	grade.Enabled = true
	flash.Enabled = true
	scream.Volume = screamVolume
	scream:Play()
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 2, onRenderStep)
	pendingFadeOut = task.delay(CaptureConfig.JUMPSCARE_DURATION, fadeOut)
end

local function hideOverlayWhenFaded(playbackState: Enum.PlaybackState)
	if playbackState == Enum.PlaybackState.Completed then
		overlay.Enabled = false
	end
end

local function endCapture()
	if pendingFadeOut then
		task.cancel(pendingFadeOut)
		pendingFadeOut = nil
	end
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
	scream:Stop()
	grade.Enabled = false
	flash.Enabled = false
	followCharacter(player.Character)
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	setGameplayGuiEnabled(true)
	blackout.BackgroundTransparency = 0
	local fadeIn = TweenService:Create(blackout, TweenInfo.new(FADE_IN_DURATION), { BackgroundTransparency = 1 })
	fadeIn.Completed:Once(hideOverlayWhenFaded)
	fadeIn:Play()
end

local function onCapturedChanged()
	if isCaptured() then
		beginCapture()
	elseif overlay.Enabled then
		endCapture()
	end
end

local function createGrade(): ColorCorrectionEffect
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = GRADE_NAME
	effect.Brightness = GRADE_BRIGHTNESS
	effect.Contrast = GRADE_CONTRAST
	effect.Saturation = GRADE_SATURATION
	effect.TintColor = GRADE_TINT
	effect.Enabled = false
	effect.Parent = Lighting
	return effect
end

local function createFlash(): (Attachment, PointLight)
	local anchor = Instance.new("Attachment")
	anchor.Name = FLASH_NAME
	local light = Instance.new("PointLight")
	light.Color = FLASH_COLOR
	light.Brightness = FLASH_BRIGHTNESS
	light.Range = FLASH_RANGE
	light.Shadows = false
	light.Enabled = false
	light.Parent = anchor
	anchor.Parent = Workspace.Terrain
	return anchor, light
end

function Jumpscare.start()
	overlay = player:WaitForChild(PLAYER_GUI_NAME):WaitForChild(OVERLAY_NAME) :: ScreenGui
	blackout = overlay:WaitForChild(BLACKOUT_NAME) :: Frame
	scream = SoundService:WaitForChild(SCREAM_NAME) :: Sound
	screamVolume = scream.Volume
	grade = createGrade()
	flashAnchor, flash = createFlash()
	player:GetAttributeChangedSignal(PlayerAttributes.CAPTURED):Connect(onCapturedChanged)
	player.CharacterAdded:Connect(onCharacterAdded)
end

return Jumpscare
