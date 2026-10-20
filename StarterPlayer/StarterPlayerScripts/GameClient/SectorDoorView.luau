local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SectorDoorConfig = require(Shared:WaitForChild("SectorDoorConfig"))
local SectorDoorWorld = require(Shared:WaitForChild("SectorDoorWorld"))
local CameraTremor = require(script.Parent:WaitForChild("CameraTremor"))
local SectorDoorMotion = require(script.Parent:WaitForChild("SectorDoorMotion"))

local VENT_NAME = "SealVent"
local DUST_SOURCE_NAME = "HeaderDust"
local ALARM_SOURCE_NAME = "ExitSign"
local REVEAL_SOURCE_NAME = "RevealSource"
local SPARK_POINT_NAME = "SparkPoint"
local SPARKS_NAME = "Sparks"
local STEAM_NAME = "Steam"
local DUST_NAME = "Dust"
local DUST_PUFF_NAME = "DustPuff"
local ALARM_LIGHT_NAME = "AlarmLight"
local REVEAL_LIGHT_NAME = "RevealLight"
local LATCH_SOUND_NAME = "LatchSound"
local PRESSURE_SOUND_NAME = "PressureSound"
local HISS_SOUND_NAME = "HissSound"
local MOTOR_SOUND_NAME = "MotorSound"
local TRACK_SOUND_NAME = "TrackSound"
local RUMBLE_SOUND_NAME = "RumbleSound"
local SLAM_SOUND_NAME = "SlamSound"
local ALARM_SOUND_NAME = "AlarmSound"
local DRONE_SOUND_NAME = "DroneSound"

local TAU = 2 * math.pi
local LATCH_TIME = 0
local ALARM_TIME = 0.2
local ALARM_FADE_START = SectorDoorMotion.SLAM_TIME + 0.6
local ALARM_FADE_DURATION = 2
local SEQUENCE_END = ALARM_FADE_START + ALARM_FADE_DURATION
local CUE_GRACE = 0.6
local LATE_JOIN_MARGIN = 0.5
local STEAM_BURST = 45
local STEAM_DECAY_TIME = 0.9
local STEAM_SLIDE_SHARE = 0.15
local LATCH_PUFFS = 6
local SLAM_PUFFS = 14
local SLAM_GRIT = 40
local SLAM_SPARKS = 18
local SPARK_SPEED_THRESHOLD = 0.3
local DRIVE_ATTACK_RATE = 8
local DRIVE_RELEASE_RATE = 5
local SILENT_DRIVE = 0.01
local TRACK_MIN_PITCH = 0.85
local TRACK_PITCH_RANGE = 0.25
local ALARM_MIN_REFERENCE = 40
local ALARM_FLOOR = 0.25
local ALARM_GAIN = 2
local ALARM_ATTACK_RATE = 30
local ALARM_RELEASE_RATE = 9
local REVEAL_CURVE = 0.7
local REVEAL_REST_SHARE = 0.65
local REVEAL_SETTLE_TIME = 1.6
local BREATH_DEPTH = 0.18
local BREATH_PERIOD = 5.5
local SHAKE_RANGE = 46
local LATCH_SHAKE = 0.35
local VENT_SHAKE = 0.45
local SLIDE_SHAKE = 0.3
local SLAM_SHAKE = 0.8

type Sounds = {
	latch: Sound,
	pressure: Sound,
	hiss: Sound,
	motor: Sound,
	track: Sound,
	rumble: Sound,
	slam: Sound,
	alarm: Sound,
	drone: Sound,
}

type Effects = {
	steam: ParticleEmitter,
	dust: ParticleEmitter,
	dustPuff: ParticleEmitter,
	sparks: { ParticleEmitter },
	alarmLight: PointLight,
	revealLight: SpotLight,
	sounds: Sounds,
}

type Cue = {
	time: number,
	play: () -> (),
}

local SectorDoorView = {}

local world: SectorDoorWorld.Instances
local effects: Effects
local peakRate: { [ParticleEmitter]: number } = {}
local peakVolume: { [Sound]: number } = {}
local peakBrightness: { [Light]: number } = {}
local closedCFrames: { [BasePart]: CFrame } = {}
local pendingCues: { Cue } = {}
local renderConnection: RBXScriptConnection? = nil
local sequenceStart = 0
local animatesLeaves = false
local isSequenceFinished = false
local drive = 0
local alarmGlow = 0
local alarmReference = ALARM_MIN_REFERENCE

local function resolveEffects(door: Model): Effects
	local vent = door:WaitForChild(VENT_NAME)
	local dustSource = door:WaitForChild(DUST_SOURCE_NAME)
	local alarmSource = door:WaitForChild(ALARM_SOURCE_NAME)
	local revealSource = door:WaitForChild(REVEAL_SOURCE_NAME)
	local sparks = {}
	for _, leaf in world.leaves do
		table.insert(sparks, leaf.part:WaitForChild(SPARK_POINT_NAME):WaitForChild(SPARKS_NAME) :: ParticleEmitter)
	end
	return {
		steam = vent:WaitForChild(STEAM_NAME) :: ParticleEmitter,
		dust = dustSource:WaitForChild(DUST_NAME) :: ParticleEmitter,
		dustPuff = dustSource:WaitForChild(DUST_PUFF_NAME) :: ParticleEmitter,
		sparks = sparks,
		alarmLight = alarmSource:WaitForChild(ALARM_LIGHT_NAME) :: PointLight,
		revealLight = revealSource:WaitForChild(REVEAL_LIGHT_NAME) :: SpotLight,
		sounds = {
			latch = vent:WaitForChild(LATCH_SOUND_NAME) :: Sound,
			pressure = vent:WaitForChild(PRESSURE_SOUND_NAME) :: Sound,
			hiss = vent:WaitForChild(HISS_SOUND_NAME) :: Sound,
			motor = vent:WaitForChild(MOTOR_SOUND_NAME) :: Sound,
			track = vent:WaitForChild(TRACK_SOUND_NAME) :: Sound,
			rumble = vent:WaitForChild(RUMBLE_SOUND_NAME) :: Sound,
			slam = vent:WaitForChild(SLAM_SOUND_NAME) :: Sound,
			alarm = alarmSource:WaitForChild(ALARM_SOUND_NAME) :: Sound,
			drone = revealSource:WaitForChild(DRONE_SOUND_NAME) :: Sound,
		},
	}
end

local function capturePeaks()
	local emitters = { effects.steam, effects.dust }
	table.move(effects.sparks, 1, #effects.sparks, #emitters + 1, emitters)
	for _, emitter in emitters do
		peakRate[emitter] = emitter.Rate
	end
	for _, sound in effects.sounds do
		peakVolume[sound] = sound.Volume
	end
	for _, light in { effects.alarmLight, effects.revealLight } :: { Light } do
		peakBrightness[light] = light.Brightness
	end
end

local function preloadSounds()
	local sounds = {}
	for _, sound in effects.sounds do
		table.insert(sounds, sound)
	end
	ContentProvider:PreloadAsync(sounds)
end

local function setRate(emitter: ParticleEmitter, share: number)
	emitter.Rate = peakRate[emitter] * share
end

local function setVolume(sound: Sound, share: number)
	sound.Volume = peakVolume[sound] * share
end

local function setBrightness(light: Light, share: number)
	light.Brightness = peakBrightness[light] * share
end

local function setPlaying(sound: Sound, shouldPlay: boolean)
	if shouldPlay and not sound.IsPlaying then
		sound:Play()
	elseif not shouldPlay and sound.IsPlaying then
		sound:Stop()
	end
end

local function shake(strength: number)
	local distance = (Workspace.CurrentCamera.CFrame.Position - world.leafGroup:GetPivot().Position).Magnitude
	CameraTremor.shake(strength * (1 - math.clamp(distance / SHAKE_RANGE, 0, 1)))
end

local function poseLeaves(slide: number)
	for _, leaf in world.leaves do
		leaf.part.CFrame = closedCFrames[leaf.part] * CFrame.new(leaf.slideDirection * slide)
	end
end

local function onLatch()
	effects.sounds.latch:Play()
	effects.dustPuff:Emit(LATCH_PUFFS)
	shake(LATCH_SHAKE)
end

local function onAlarm()
	effects.sounds.alarm:Play()
end

local function onVent()
	effects.sounds.pressure:Play()
	effects.sounds.hiss:Play()
	effects.steam:Emit(STEAM_BURST)
	shake(VENT_SHAKE)
end

local function onSlideStart()
	effects.sounds.motor:Play()
end

local function onSlam()
	effects.sounds.slam:Play()
	effects.dustPuff:Emit(SLAM_PUFFS)
	effects.dust:Emit(SLAM_GRIT)
	for _, sparks in effects.sparks do
		sparks:Emit(SLAM_SPARKS)
	end
	shake(SLAM_SHAKE)
end

local CUES: { Cue } = {
	{ time = LATCH_TIME, play = onLatch },
	{ time = ALARM_TIME, play = onAlarm },
	{ time = SectorDoorMotion.CRACK_TIME, play = onVent },
	{ time = SectorDoorMotion.SLIDE_START_TIME, play = onSlideStart },
	{ time = SectorDoorMotion.SLAM_TIME, play = onSlam },
}

local function firePendingCues(elapsed: number)
	while pendingCues[1] and pendingCues[1].time <= elapsed do
		table.remove(pendingCues, 1).play()
	end
end

local function updateParticles(elapsed: number, speed: number)
	local isVenting = elapsed >= SectorDoorMotion.CRACK_TIME and elapsed < SectorDoorMotion.SLAM_TIME
	effects.steam.Enabled = isVenting
	if isVenting then
		local ventShare = math.exp(-(elapsed - SectorDoorMotion.CRACK_TIME) / STEAM_DECAY_TIME)
		setRate(effects.steam, ventShare + STEAM_SLIDE_SHARE * speed)
	end
	effects.dust.Enabled = speed > 0
	setRate(effects.dust, speed)
	local sparkShare = math.max(speed - SPARK_SPEED_THRESHOLD, 0) / (1 - SPARK_SPEED_THRESHOLD)
	for _, sparks in effects.sparks do
		sparks.Enabled = sparkShare > 0
		setRate(sparks, sparkShare)
	end
end

local function updateMachineAudio(elapsed: number, speed: number, dt: number)
	local rate = if speed > drive then DRIVE_ATTACK_RATE else DRIVE_RELEASE_RATE
	drive += (speed - drive) * (1 - math.exp(-rate * dt))
	local hasStarted = elapsed >= SectorDoorMotion.SLIDE_START_TIME
	local isRunning = hasStarted and (elapsed < SectorDoorMotion.SLAM_TIME or drive > SILENT_DRIVE)
	setPlaying(effects.sounds.track, isRunning)
	setPlaying(effects.sounds.rumble, isRunning)
	setVolume(effects.sounds.track, drive)
	setVolume(effects.sounds.rumble, drive)
	effects.sounds.track.PlaybackSpeed = TRACK_MIN_PITCH + TRACK_PITCH_RANGE * drive
end

local function updateAlarm(elapsed: number, dt: number)
	local alarm = effects.sounds.alarm
	local fade = 1 - math.clamp((elapsed - ALARM_FADE_START) / ALARM_FADE_DURATION, 0, 1)
	setVolume(alarm, fade)
	local loudness = alarm.PlaybackLoudness
	alarmReference = math.max(alarmReference, loudness)
	local target = math.clamp((loudness / alarmReference - ALARM_FLOOR) * ALARM_GAIN, 0, 1)
	local rate = if target > alarmGlow then ALARM_ATTACK_RATE else ALARM_RELEASE_RATE
	alarmGlow += (target - alarmGlow) * (1 - math.exp(-rate * dt))
	effects.alarmLight.Enabled = alarm.IsPlaying
	setBrightness(effects.alarmLight, alarmGlow * fade)
end

local function updateReveal(elapsed: number, opening: number)
	local isRevealed = elapsed >= SectorDoorMotion.CRACK_TIME
	effects.revealLight.Enabled = isRevealed
	setPlaying(effects.sounds.drone, isRevealed)
	if not isRevealed then
		return
	end
	setVolume(effects.sounds.drone, opening)
	if elapsed < SectorDoorMotion.SLAM_TIME then
		setBrightness(effects.revealLight, opening ^ REVEAL_CURVE)
		return
	end
	local sinceSlam = elapsed - SectorDoorMotion.SLAM_TIME
	local settle = REVEAL_REST_SHARE + (1 - REVEAL_REST_SHARE) * math.exp(-sinceSlam / REVEAL_SETTLE_TIME)
	local breath = 1 + BREATH_DEPTH * math.sin(TAU * sinceSlam / BREATH_PERIOD)
	setBrightness(effects.revealLight, settle * breath)
end

local function updateSequence(elapsed: number, dt: number)
	firePendingCues(elapsed)
	local slide = SectorDoorMotion.slideAt(elapsed)
	local speed = SectorDoorMotion.speedFractionAt(elapsed)
	if animatesLeaves then
		poseLeaves(slide)
	end
	updateParticles(elapsed, speed)
	updateMachineAudio(elapsed, speed, dt)
	updateAlarm(elapsed, dt)
	updateReveal(elapsed, slide / SectorDoorConfig.LEAF_SLIDE_DISTANCE)
	if speed > 0 then
		shake(SLIDE_SHAKE * speed)
	end
end

local function finishSequence()
	isSequenceFinished = true
	if animatesLeaves then
		poseLeaves(SectorDoorConfig.LEAF_SLIDE_DISTANCE)
	end
	effects.steam.Enabled = false
	effects.dust.Enabled = false
	for _, sparks in effects.sparks do
		sparks.Enabled = false
	end
	effects.sounds.track:Stop()
	effects.sounds.rumble:Stop()
	effects.sounds.alarm:Stop()
	effects.alarmLight.Enabled = false
end

local function onRenderStepped(dt: number)
	local elapsed = os.clock() - sequenceStart
	if elapsed < SEQUENCE_END then
		updateSequence(elapsed, dt)
		return
	end
	if not isSequenceFinished then
		finishSequence()
	end
	updateReveal(elapsed, 1)
end

local function begin(initialElapsed: number)
	sequenceStart = os.clock() - initialElapsed
	animatesLeaves = initialElapsed < SectorDoorConfig.OPENING_DURATION - LATE_JOIN_MARGIN
	isSequenceFinished = initialElapsed >= SEQUENCE_END
	for _, leaf in world.leaves do
		closedCFrames[leaf.part] = leaf.part.CFrame
	end
	for _, cue in CUES do
		if cue.time >= initialElapsed - CUE_GRACE then
			table.insert(pendingCues, cue)
		end
	end
	renderConnection = RunService.RenderStepped:Connect(onRenderStepped)
end

local function openedElapsed(): number?
	if world.door:GetAttribute(SectorDoorConfig.STATE_ATTRIBUTE) ~= SectorDoorConfig.OPEN_STATE then
		return nil
	end
	local openedAt = world.door:GetAttribute(SectorDoorConfig.OPENED_AT_ATTRIBUTE)
	return if typeof(openedAt) == "number" then math.max(Workspace:GetServerTimeNow() - openedAt, 0) else nil
end

local function onStateChanged()
	local elapsed = openedElapsed()
	if elapsed and not renderConnection then
		begin(elapsed)
	end
end

function SectorDoorView.start()
	world = SectorDoorWorld.resolve()
	effects = resolveEffects(world.door)
	capturePeaks()
	task.spawn(preloadSounds)
	world.door:GetAttributeChangedSignal(SectorDoorConfig.STATE_ATTRIBUTE):Connect(onStateChanged)
	onStateChanged()
end

return SectorDoorView
