local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PhoneCalls = require(Shared:WaitForChild("PhoneCalls"))
local PhoneConfig = require(Shared:WaitForChild("PhoneConfig"))
local PhoneWorld = require(Shared:WaitForChild("PhoneWorld"))
local SpokenLines = require(script.Parent:WaitForChild("SpokenLines"))
local Subtitles = require(script.Parent:WaitForChild("Subtitles"))

local VOICE: SpokenLines.VoiceSettings = {
	name = "CallNarration",
	voiceId = "1001",
	pitch = -5,
	speed = 0.85,
	volume = 1,
	lowGain = 4,
	highGain = -5,
	reverbDecay = 1.8,
	reverbWetLevel = -14,
}
local LINE_GAP = 0.35
local CLOSING_HOLD = 1.5

local idleEvent = Instance.new("BindableEvent")

local CallNarration = {}

local world: PhoneWorld.Instances
local voice: SpokenLines.Voice
local speechByCall: { [string]: SpokenLines.Speech } = {}
local narratingCallId: string? = nil

local function speechFor(callId: string): SpokenLines.Speech
	local speech = speechByCall[callId]
	if not speech then
		speech = SpokenLines.prepare(voice, PhoneCalls.SCRIPTS[callId])
		speechByCall[callId] = speech
	end
	return speech
end

local function narrate(callId: string)
	narratingCallId = callId
	local speech = speechFor(callId)
	for index, line in PhoneCalls.SCRIPTS[callId] do
		local cue = SpokenLines.cue(speech, index)
		SpokenLines.play(cue)
		Subtitles.show(line, SpokenLines.duration(cue))
		SpokenLines.awaitFinish(cue)
		task.wait(LINE_GAP)
	end
	task.wait(CLOSING_HOLD)
	speechByCall[callId] = nil
	SpokenLines.release(speech)
	if narratingCallId == callId then
		narratingCallId = nil
		Subtitles.hide()
		idleEvent:Fire()
	end
end

local function callIdFrom(attribute: string): string?
	local callId = world.box:GetAttribute(attribute)
	if typeof(callId) == "string" and PhoneCalls.SCRIPTS[callId] then
		return callId
	end
	return nil
end

local function onRingingCallChanged()
	local callId = callIdFrom(PhoneConfig.RINGING_CALL_ATTRIBUTE)
	if callId then
		speechFor(callId)
	end
end

local function onActiveCallChanged()
	local callId = callIdFrom(PhoneConfig.ACTIVE_CALL_ATTRIBUTE)
	if callId then
		task.spawn(narrate, callId)
	end
end

function CallNarration.awaitIdle()
	while narratingCallId do
		idleEvent.Event:Wait()
	end
end

function CallNarration.start()
	world = PhoneWorld.resolve()
	voice = SpokenLines.createVoice(VOICE)
	world.box:GetAttributeChangedSignal(PhoneConfig.RINGING_CALL_ATTRIBUTE):Connect(onRingingCallChanged)
	world.box:GetAttributeChangedSignal(PhoneConfig.ACTIVE_CALL_ATTRIBUTE):Connect(onActiveCallChanged)
	onRingingCallChanged()
end

return CallNarration
