local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GrinderConfig = require(Shared:WaitForChild("GrinderConfig"))
local GrinderWorld = require(Shared:WaitForChild("GrinderWorld"))

local GUSH_PULSES = 5
local PULSE_INTERVAL = 0.16
local PARTICLES_PER_PULSE: { [string]: number } = {
	BloodGush = 16,
	BloodSpray = 28,
	GoreChunks = 9,
	BloodMist = 5,
}
local POOL_SPREAD_DELAY = 0.25
local POOL_SPREAD_DURATION = 2.4
local POOL_SPREAD_INFO = TweenInfo.new(POOL_SPREAD_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POOL_FIRST_SCALE = 0.6
local POOL_SCALE_PER_GRIND = 0.1
local POOL_MAX_SCALE = 1
local GRIND_SOUND_NAME = "GrindSound"
local SPILL_SOUND_NAME = "SpillSound"

local GrinderGoreView = {}

local grinder: Model
local shownGrindCount = 0

local function readGrindCount(): number
	local count = grinder:GetAttribute(GrinderConfig.GRIND_COUNT_ATTRIBUTE)
	return if typeof(count) == "number" then count else 0
end

local function poolSize(grindCount: number): UDim2
	local scale = if grindCount > 0 then math.min(POOL_FIRST_SCALE + POOL_SCALE_PER_GRIND * (grindCount - 1), POOL_MAX_SCALE) else 0
	return UDim2.fromScale(scale, scale)
end

local function playSound(holder: Instance?, soundName: string)
	local sound = if holder then holder:FindFirstChild(soundName) else nil
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

local function gush()
	for _ = 1, GUSH_PULSES do
		local spout = GrinderWorld.findSpout(grinder)
		if not spout then
			return
		end
		for emitterName, count in PARTICLES_PER_PULSE do
			local emitter = spout:FindFirstChild(emitterName)
			if emitter and emitter:IsA("ParticleEmitter") then
				emitter:Emit(count)
			end
		end
		task.wait(PULSE_INTERVAL)
	end
end

local function spreadPool(grindCount: number)
	task.wait(POOL_SPREAD_DELAY)
	local image = GrinderWorld.findPoolImage(grinder)
	if image then
		TweenService:Create(image, POOL_SPREAD_INFO, { Size = poolSize(grindCount) }):Play()
	end
end

local function onGrindCountChanged()
	local grindCount = readGrindCount()
	if grindCount <= shownGrindCount then
		return
	end
	shownGrindCount = grindCount
	playSound(GrinderWorld.findIntake(grinder), GRIND_SOUND_NAME)
	playSound(GrinderWorld.findSpout(grinder), SPILL_SOUND_NAME)
	task.spawn(gush)
	task.spawn(spreadPool, grindCount)
end

local function onDescendantAdded(descendant: Instance)
	if descendant:IsA("ImageLabel") and descendant == GrinderWorld.findPoolImage(grinder) then
		descendant.Size = poolSize(shownGrindCount)
	end
end

function GrinderGoreView.start()
	grinder = GrinderWorld.resolve()
	shownGrindCount = readGrindCount()
	grinder:GetAttributeChangedSignal(GrinderConfig.GRIND_COUNT_ATTRIBUTE):Connect(onGrindCountChanged)
	grinder.DescendantAdded:Connect(onDescendantAdded)
	local image = GrinderWorld.findPoolImage(grinder)
	if image then
		onDescendantAdded(image)
	end
end

return GrinderGoreView
