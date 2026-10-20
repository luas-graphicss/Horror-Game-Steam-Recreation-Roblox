local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrankCharge = require(Shared:WaitForChild("CrankCharge"))
local CrankGeneratorConfig = require(Shared:WaitForChild("CrankGeneratorConfig"))
local CrankGeneratorWorld = require(Shared:WaitForChild("CrankGeneratorWorld"))

local CRANK_SOUND_NAME = "CrankSound"
local SPARK_POINT_NAME = "SparkPoint"
local SPARKS_NAME = "Sparks"
local FULL_TURN = 2 * math.pi
local BASE_CRANKING_SPEED = CrankGeneratorConfig.TURNS_PER_SECOND * FULL_TURN
local SPIN_RESPONSIVENESS = 6
local MIN_SPIN_SPEED = 0.01
local SPARKS_PER_TURN = 45
local MIN_SOUND_PLAYBACK_SPEED = 0.7

local CrankView = {}

local world: CrankGeneratorWorld.Instances
local wheelRestPivot: CFrame
local pinionRestPivot: CFrame
local gearRatio: number
local crankSound: Sound
local crankVolume: number
local sparks: ParticleEmitter
local spinSpeed = 0
local wheelAngle = 0
local pinionAngle = 0
local pendingSparks = 0

local function updateSound(spinRatio: number)
	if spinRatio <= 0 then
		if crankSound.IsPlaying then
			crankSound:Stop()
		end
		return
	end
	crankSound.Volume = crankVolume * math.min(spinRatio, 1)
	crankSound.PlaybackSpeed = MIN_SOUND_PLAYBACK_SPEED + (1 - MIN_SOUND_PLAYBACK_SPEED) * spinRatio
	if not crankSound.IsPlaying then
		crankSound:Play()
	end
end

local function emitSparks(turned: number)
	pendingSparks += turned / FULL_TURN * SPARKS_PER_TURN
	local count = math.floor(pendingSparks)
	if count > 0 then
		pendingSparks -= count
		sparks:Emit(count)
	end
end

local function targetSpinSpeed(): number
	return CrankCharge.spinTurnsPerSecond(world.station) * FULL_TURN
end

local function onRenderStepped(dt: number)
	spinSpeed += (targetSpinSpeed() - spinSpeed) * (1 - math.exp(-SPIN_RESPONSIVENESS * dt))
	if spinSpeed < MIN_SPIN_SPEED then
		updateSound(0)
		return
	end
	updateSound(spinSpeed / BASE_CRANKING_SPEED)
	local turned = spinSpeed * dt
	wheelAngle = (wheelAngle + turned) % FULL_TURN
	pinionAngle = (pinionAngle + turned * gearRatio) % FULL_TURN
	world.wheel:PivotTo(wheelRestPivot * CFrame.Angles(0, 0, -wheelAngle))
	world.pinion:PivotTo(pinionRestPivot * CFrame.Angles(0, 0, pinionAngle))
	emitSparks(turned)
end

function CrankView.start()
	world = CrankGeneratorWorld.resolve()
	wheelRestPivot = world.wheel:GetPivot()
	pinionRestPivot = world.pinion:GetPivot()
	gearRatio = world.wheel.Size.X / world.pinion.Size.X
	crankSound = world.wheel:WaitForChild(CRANK_SOUND_NAME) :: Sound
	crankVolume = crankSound.Volume
	sparks = world.mount:WaitForChild(SPARK_POINT_NAME):WaitForChild(SPARKS_NAME) :: ParticleEmitter
	RunService.RenderStepped:Connect(onRenderStepped)
end

return CrankView
