local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local TrombyWatcherConfig = require(Shared:WaitForChild("TrombyWatcherConfig"))
local TrombyWatcherOfferings = require(Shared:WaitForChild("TrombyWatcherOfferings"))
local DialogueBox = require(script.Parent:WaitForChild("DialogueBox"))
local SpokenLines = require(script.Parent:WaitForChild("SpokenLines"))

local SPEAKER_NAME = "Clip"
local ACCEPT_FORMAT = "Aceitar e dar %d biomassa"
local REFUSE_TEXT = "Recusar"
local ACCEPT_CHOICE = 1
local GRATITUDE_HOLD = 1.2
local VERDICT_TIMEOUT = 5
local VOICE: SpokenLines.VoiceSettings = {
	name = "TrombyWatcherVoice",
	voiceId = "1002",
	pitch = -3,
	speed = 0.92,
	volume = 1,
	lowGain = 3,
	highGain = -3,
	reverbDecay = 1.6,
	reverbWetLevel = -12,
}

type PreparedSpeech = {
	contributions: number,
	lines: SpokenLines.Speech,
	gratitude: SpokenLines.Speech,
}

local finishedEvent = Instance.new("BindableEvent")

local TrombyWatcherDialogue = {
	finished = finishedEvent.Event,
}

local player = Players.LocalPlayer
local voice: SpokenLines.Voice
local prepared: PreparedSpeech? = nil
local isConversing = false
local listenerConnections: { [Instance]: RBXScriptConnection } = {}

local function contributionsOf(watcher: Instance): number
	local count = watcher:GetAttribute(TrombyWatcherConfig.CONTRIBUTIONS_ATTRIBUTE)
	return if typeof(count) == "number" then count else 0
end

local function isListening(watcher: Instance): boolean
	return watcher:GetAttribute(TrombyWatcherConfig.LISTENER_ATTRIBUTE) == player.UserId
end

local function release(speech: PreparedSpeech)
	SpokenLines.release(speech.lines)
	SpokenLines.release(speech.gratitude)
end

local function prepareAhead(contributions: number)
	if prepared and prepared.contributions == contributions then
		return
	end
	if prepared then
		release(prepared)
		prepared = nil
	end
	local offering = TrombyWatcherOfferings.at(contributions)
	if offering then
		prepared = {
			contributions = contributions,
			lines = SpokenLines.prepare(voice, offering.conversation.lines),
			gratitude = SpokenLines.prepare(voice, offering.conversation.gratitude),
		}
	end
end

local function takeSpeech(contributions: number): PreparedSpeech?
	prepareAhead(contributions)
	local speech = prepared
	prepared = nil
	return speech
end

local function askForBiomass(conversation: TrombyWatcherOfferings.Conversation, biomassCost: number, speech: SpokenLines.Speech): boolean
	local accepted = false
	for index, line in conversation.lines do
		local isFinalLine = index == #conversation.lines
		local cue = SpokenLines.cue(speech, index)
		SpokenLines.play(cue)
		DialogueBox.say(line, SpokenLines.duration(cue), not isFinalLine)
		if isFinalLine then
			accepted = DialogueBox.choose({ string.format(ACCEPT_FORMAT, biomassCost), REFUSE_TEXT }) == ACCEPT_CHOICE
		else
			DialogueBox.awaitContinue()
		end
		SpokenLines.stop(cue)
	end
	return accepted
end

local function awaitVerdict(watcher: Instance, contributionsBefore: number): boolean
	local deadline = os.clock() + VERDICT_TIMEOUT
	while isListening(watcher) and os.clock() < deadline do
		task.wait()
	end
	return contributionsOf(watcher) > contributionsBefore
end

local function thank(gratitude: { string }, speech: SpokenLines.Speech)
	for index, line in gratitude do
		local isFinalLine = index == #gratitude
		local cue = SpokenLines.cue(speech, index)
		SpokenLines.play(cue)
		DialogueBox.say(line, SpokenLines.duration(cue), not isFinalLine)
		if isFinalLine then
			SpokenLines.awaitFinish(cue)
			task.wait(GRATITUDE_HOLD)
		else
			DialogueBox.awaitContinue()
		end
		SpokenLines.stop(cue)
	end
end

local function converse(watcher: Instance)
	local contributionsBefore = contributionsOf(watcher)
	local offering = TrombyWatcherOfferings.at(contributionsBefore)
	local speech = takeSpeech(contributionsBefore)
	if not offering or not speech then
		Remotes.AnswerTrombyWatcher:FireServer(false)
		return
	end
	DialogueBox.open(SPEAKER_NAME)
	local accepted = askForBiomass(offering.conversation, offering.biomassCost, speech.lines)
	Remotes.AnswerTrombyWatcher:FireServer(accepted)
	if accepted and awaitVerdict(watcher, contributionsBefore) then
		thank(offering.conversation.gratitude, speech.gratitude)
	end
	DialogueBox.close()
	release(speech)
	prepareAhead(contributionsOf(watcher))
end

local function runConversation(watcher: Instance)
	isConversing = true
	converse(watcher)
	isConversing = false
	finishedEvent:Fire(watcher)
end

local function onListenerChanged(watcher: Instance)
	if not isConversing and isListening(watcher) then
		task.spawn(runConversation, watcher)
	end
end

local function bind(watcher: Instance)
	if listenerConnections[watcher] then
		return
	end
	listenerConnections[watcher] = watcher:GetAttributeChangedSignal(TrombyWatcherConfig.LISTENER_ATTRIBUTE):Connect(function()
		onListenerChanged(watcher)
	end)
	prepareAhead(contributionsOf(watcher))
	onListenerChanged(watcher)
end

local function unbind(watcher: Instance)
	local connection = listenerConnections[watcher]
	if connection then
		connection:Disconnect()
		listenerConnections[watcher] = nil
	end
end

function TrombyWatcherDialogue.isConversing(): boolean
	return isConversing
end

function TrombyWatcherDialogue.start()
	voice = SpokenLines.createVoice(VOICE)
	CollectionService:GetInstanceAddedSignal(TrombyWatcherConfig.TAG):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(TrombyWatcherConfig.TAG):Connect(unbind)
	for _, watcher in CollectionService:GetTagged(TrombyWatcherConfig.TAG) do
		bind(watcher)
	end
end

return TrombyWatcherDialogue
