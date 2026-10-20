local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local SpeechTimeline = require(script.Parent:WaitForChild("SpeechTimeline"))

local MAX_PASSAGE_CHARACTERS = 300
local LOAD_TIMEOUT = 10
local LOAD_POLL_INTERVAL = 0.1
local START_LEAD = 0.04
local FINISH_TAIL = 0.12
local PLAYBACK_GRACE = 0.5
local FALLBACK_CHARACTERS_PER_SECOND = 12

export type VoiceSettings = {
	name: string,
	voiceId: string,
	pitch: number,
	speed: number,
	volume: number,
	lowGain: number,
	highGain: number,
	reverbDecay: number?,
	reverbWetLevel: number?,
}

export type Voice = {
	settings: VoiceSettings,
	rig: Folder,
	input: AudioEqualizer,
}

export type Cue = {
	audio: AudioTextToSpeech?,
	start: number,
	finish: number,
}

type Passage = {
	firstLine: number,
	lines: { string },
	audio: AudioTextToSpeech,
	windows: { SpeechTimeline.Window }?,
	isSettled: boolean,
}

export type Speech = {
	lines: { string },
	passages: { Passage },
}

type Playback = {
	isDone: boolean,
}

local SpokenLines = {}

local playbacks: { [AudioTextToSpeech]: Playback } = {}
local voiceFaders: { AudioFader } = {}
local volumeLevel = 1

local function characterCount(text: string): number
	return utf8.len(text) or #text
end

local function connect(source: Instance, target: Instance)
	local wire = Instance.new("Wire")
	wire.SourceInstance = source
	wire.TargetInstance = target
	wire.Parent = target
end

local function groupIntoPassages(lines: { string }): { { firstLine: number, lines: { string } } }
	local groups = {}
	local currentLength = 0
	for index, line in lines do
		local length = characterCount(line) + 1
		local current = groups[#groups]
		if not current or currentLength + length > MAX_PASSAGE_CHARACTERS then
			current = { firstLine = index, lines = {} }
			table.insert(groups, current)
			currentLength = 0
		end
		table.insert(current.lines, line)
		currentLength += length
	end
	return groups
end

local function createAudio(voice: Voice, text: string): AudioTextToSpeech
	local audio = Instance.new("AudioTextToSpeech")
	audio.Text = text
	audio.VoiceId = voice.settings.voiceId
	audio.Pitch = voice.settings.pitch
	audio.Speed = voice.settings.speed
	audio.Volume = voice.settings.volume
	audio.AutoLocalize = false
	audio.Parent = voice.rig
	connect(audio, voice.input)
	return audio
end

local function settle(passage: Passage)
	local loaded, status = pcall(passage.audio.LoadAsync, passage.audio)
	if loaded and status == Enum.AssetFetchStatus.Success and passage.audio.TimeLength > 0 then
		passage.windows = SpeechTimeline.windows(passage.audio, passage.lines)
	end
	passage.isSettled = true
end

local function settleInOrder(passages: { Passage })
	for _, passage in passages do
		if passage.audio.Parent then
			settle(passage)
		end
	end
end

local function passageOf(speech: Speech, lineIndex: number): Passage
	local owner = speech.passages[1]
	for _, passage in speech.passages do
		if passage.firstLine <= lineIndex then
			owner = passage
		end
	end
	return owner
end

local function finishPlayback(audio: AudioTextToSpeech, playback: Playback)
	if not playback.isDone then
		playback.isDone = true
		audio:Pause()
	end
end

function SpokenLines.createVoice(settings: VoiceSettings): Voice
	local rig = Instance.new("Folder")
	rig.Name = settings.name
	local output = Instance.new("AudioDeviceOutput")
	output.Parent = rig
	local input = Instance.new("AudioEqualizer")
	input.LowGain = settings.lowGain
	input.HighGain = settings.highGain
	input.Parent = rig
	local fader = Instance.new("AudioFader")
	fader.Volume = volumeLevel
	fader.Parent = rig
	connect(input, fader)
	table.insert(voiceFaders, fader)
	if settings.reverbDecay and settings.reverbWetLevel then
		local reverb = Instance.new("AudioReverb")
		reverb.DecayTime = settings.reverbDecay
		reverb.WetLevel = settings.reverbWetLevel
		reverb.Parent = rig
		connect(fader, reverb)
		connect(reverb, output)
	else
		connect(fader, output)
	end
	rig.Parent = SoundService
	return { settings = settings, rig = rig, input = input }
end

function SpokenLines.setVolume(level: number)
	volumeLevel = level
	for _, fader in voiceFaders do
		fader.Volume = level
	end
end

function SpokenLines.prepare(voice: Voice, lines: { string }): Speech
	local passages: { Passage } = {}
	for _, group in groupIntoPassages(lines) do
		table.insert(passages, {
			firstLine = group.firstLine,
			lines = group.lines,
			audio = createAudio(voice, table.concat(group.lines, " ")),
			windows = nil,
			isSettled = false,
		})
	end
	task.spawn(settleInOrder, passages)
	return { lines = lines, passages = passages }
end

function SpokenLines.cue(speech: Speech, lineIndex: number): Cue
	local passage = passageOf(speech, lineIndex)
	local deadline = os.clock() + LOAD_TIMEOUT
	while not passage.isSettled and os.clock() < deadline do
		task.wait(LOAD_POLL_INTERVAL)
	end
	local windows = passage.windows
	if windows then
		local window = windows[lineIndex - passage.firstLine + 1]
		return { audio = passage.audio, start = window.start, finish = window.finish }
	end
	return { audio = nil, start = 0, finish = characterCount(speech.lines[lineIndex]) / FALLBACK_CHARACTERS_PER_SECOND }
end

function SpokenLines.duration(cue: Cue): number
	return cue.finish - cue.start
end

function SpokenLines.stop(cue: Cue)
	local audio = cue.audio
	local playback = if audio then playbacks[audio] else nil
	if audio and playback then
		playbacks[audio] = nil
		finishPlayback(audio, playback)
	end
end

function SpokenLines.play(cue: Cue)
	local audio = cue.audio
	if not audio then
		return
	end
	SpokenLines.stop(cue)
	local playback: Playback = { isDone = false }
	playbacks[audio] = playback
	local startAt = math.max(0, cue.start - START_LEAD)
	local stopAt = math.min(audio.TimeLength, cue.finish + FINISH_TAIL)
	local deadline = os.clock() + stopAt - startAt + PLAYBACK_GRACE
	audio.TimePosition = startAt
	audio:Play()
	task.spawn(function()
		while not playback.isDone and audio.TimePosition < stopAt and os.clock() < deadline do
			RunService.Heartbeat:Wait()
		end
		finishPlayback(audio, playback)
	end)
end

function SpokenLines.awaitFinish(cue: Cue)
	local audio = cue.audio
	if not audio then
		task.wait(SpokenLines.duration(cue))
		return
	end
	local playback = playbacks[audio]
	while playback and not playback.isDone do
		RunService.Heartbeat:Wait()
	end
end

function SpokenLines.release(speech: Speech)
	for _, passage in speech.passages do
		local playback = playbacks[passage.audio]
		if playback then
			playbacks[passage.audio] = nil
			playback.isDone = true
		end
		passage.audio:Destroy()
	end
end

return SpokenLines
