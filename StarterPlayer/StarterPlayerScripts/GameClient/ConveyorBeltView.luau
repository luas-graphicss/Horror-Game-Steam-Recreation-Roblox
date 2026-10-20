local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoltStationConfig = require(Shared:WaitForChild("BoltStationConfig"))
local BoltStationWorld = require(Shared:WaitForChild("BoltStationWorld"))
local ProductionLineConfig = require(Shared:WaitForChild("ProductionLineConfig"))

local CLEATS_NAME = "Cleats"
local MOTOR_SOUND_NAME = "MotorSound"
local MOTOR_FADE_DURATION = 0.5

type Belt = {
	part: BasePart,
	cleats: Texture,
	motorSound: Sound,
	motorVolume: number,
	motorFade: Tween?,
	scrollDirection: number,
	isRunning: boolean,
	runningConnection: RBXScriptConnection?,
}

local ConveyorBeltView = {}

local belts: { [BasePart]: Belt } = {}
local beltPartsByLine: { [Instance]: BasePart } = {}

local function speedOf(belt: Belt): number
	local speed = belt.part:GetAttribute(BoltStationConfig.BELT_SPEED_ATTRIBUTE)
	return if typeof(speed) == "number" then speed else BoltStationConfig.BELT_SPEED
end

local function cancelFade(belt: Belt)
	local fade = belt.motorFade
	if fade then
		fade:Cancel()
		belt.motorFade = nil
	end
end

local function onRunningChanged(belt: Belt)
	belt.isRunning = belt.part:GetAttribute(BoltStationConfig.BELT_RUNNING_ATTRIBUTE) == true
	cancelFade(belt)
	local motorSound = belt.motorSound
	if belt.isRunning then
		motorSound.Volume = belt.motorVolume
		motorSound.TimePosition = 0
		motorSound:Play()
		return
	end
	local fade = TweenService:Create(motorSound, TweenInfo.new(MOTOR_FADE_DURATION), { Volume = 0 })
	fade.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			motorSound:Stop()
		end
	end)
	fade:Play()
	belt.motorFade = fade
end

local function onRenderStepped(deltaTime: number)
	for _, belt in belts do
		if belt.isRunning then
			local cleats = belt.cleats
			cleats.OffsetStudsU = (cleats.OffsetStudsU + belt.scrollDirection * speedOf(belt) * deltaTime) % cleats.StudsPerTileU
		end
	end
end

local function bind(world: BoltStationWorld.Instances)
	local part = world.belt
	local motorSound = world.gearmotor:WaitForChild(MOTOR_SOUND_NAME) :: Sound
	local cleats = part:WaitForChild(CLEATS_NAME) :: Texture
	if belts[part] then
		return
	end
	local travelDirection = (world.boltSlot.WorldPosition - world.intakeLanding.WorldPosition).Unit
	local belt: Belt = {
		part = part,
		cleats = cleats,
		motorSound = motorSound,
		motorVolume = motorSound.Volume,
		motorFade = nil,
		scrollDirection = travelDirection:Dot(part.CFrame.RightVector),
		isRunning = part:GetAttribute(BoltStationConfig.BELT_RUNNING_ATTRIBUTE) == true,
		runningConnection = nil,
	}
	belt.runningConnection = part:GetAttributeChangedSignal(BoltStationConfig.BELT_RUNNING_ATTRIBUTE):Connect(function()
		onRunningChanged(belt)
	end)
	belts[part] = belt
end

local function unbind(part: BasePart)
	local belt = belts[part]
	if not belt then
		return
	end
	belts[part] = nil
	if belt.runningConnection then
		belt.runningConnection:Disconnect()
	end
	cancelFade(belt)
	belt.motorSound:Stop()
end

local function bindLine(line: Instance)
	local world = BoltStationWorld.fromLine(line)
	if beltPartsByLine[line] or not line:IsDescendantOf(Workspace) then
		return
	end
	beltPartsByLine[line] = world.belt
	bind(world)
end

local function unbindLine(line: Instance)
	local part = beltPartsByLine[line]
	if part then
		beltPartsByLine[line] = nil
		unbind(part)
	end
end

function ConveyorBeltView.start()
	CollectionService:GetInstanceAddedSignal(ProductionLineConfig.TAG):Connect(bindLine)
	CollectionService:GetInstanceRemovedSignal(ProductionLineConfig.TAG):Connect(unbindLine)
	for _, line in CollectionService:GetTagged(ProductionLineConfig.TAG) do
		task.spawn(bindLine, line)
	end
	task.spawn(function()
		bind(BoltStationWorld.resolve())
	end)
	RunService.RenderStepped:Connect(onRenderStepped)
end

return ConveyorBeltView
