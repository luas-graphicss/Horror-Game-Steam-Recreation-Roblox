local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrombyConfig = require(Shared:WaitForChild("TrombyConfig"))
local DialogueBox = require(script.Parent:WaitForChild("DialogueBox"))
local SpokenLines = require(script.Parent:WaitForChild("SpokenLines"))

local SPEAKER_NAME = "Tromby"
local FINAL_LINE_HOLD = 1.2
local VOICE: SpokenLines.VoiceSettings = {
	name = "TrombyVoice",
	voiceId = "1002",
	pitch = 5,
	speed = 1.08,
	volume = 1,
	lowGain = -10,
	highGain = 3,
}
local LINES = {
	"Eu sou Tromby, seu assistente. Gostaria de alguma ajuda?",
	"Um parafuso enroscado mais rÃ¡pido paga mais alto. EstÃ¡ na pÃ¡gina 40 do seu contrato. Eles nÃ£o te deram a pÃ¡gina 40? VocÃª fez uma pausa de 14 segundos. Mas calma, isso nÃ£o Ã© uma repreensÃ£o, eu estou apenas anotando. Eu anoto tudo.",
	"NÃ£o me disseram o que fazer aqui, sÃ³ para ser Ãºtil. EntÃ£o procurei algo Ãºtil, e nÃ£o parece ser vocÃª.",
	"VocÃª nÃ£o comeu nada desde que chegou aqui. Aqui ninguÃ©m faz isso. Fiquei me perguntando isso por um bom tempo, atÃ© perceber agora.",
	"Agora, nÃ£o olhe para trÃ¡s!",
}

local finishedEvent = Instance.new("BindableEvent")

local TrombyDialogue = {
	finished = finishedEvent.Event,
}

local voice: SpokenLines.Voice
local preparedSpeech: SpokenLines.Speech? = nil
local hasConversed = false

local function speechForConversation(): SpokenLines.Speech
	local speech = preparedSpeech or SpokenLines.prepare(voice, LINES)
	preparedSpeech = nil
	return speech
end

local function converse(tromby: Instance)
	local speech = speechForConversation()
	DialogueBox.open(SPEAKER_NAME)
	for index, line in LINES do
		local isFinalLine = index == #LINES
		local cue = SpokenLines.cue(speech, index)
		SpokenLines.play(cue)
		DialogueBox.say(line, SpokenLines.duration(cue), not isFinalLine)
		if isFinalLine then
			SpokenLines.awaitFinish(cue)
			task.wait(FINAL_LINE_HOLD)
		else
			DialogueBox.awaitContinue()
		end
		SpokenLines.stop(cue)
	end
	DialogueBox.close()
	SpokenLines.release(speech)
	finishedEvent:Fire(tromby)
end

local function onListenerChanged(tromby: Instance)
	if hasConversed or tromby:GetAttribute(TrombyConfig.LISTENER_ATTRIBUTE) ~= Players.LocalPlayer.UserId then
		return
	end
	hasConversed = true
	task.spawn(converse, tromby)
end

local function onTrombyAdded(tromby: Instance)
	if not hasConversed and not preparedSpeech then
		preparedSpeech = SpokenLines.prepare(voice, LINES)
	end
	tromby:GetAttributeChangedSignal(TrombyConfig.LISTENER_ATTRIBUTE):Connect(function()
		onListenerChanged(tromby)
	end)
	onListenerChanged(tromby)
end

function TrombyDialogue.start()
	voice = SpokenLines.createVoice(VOICE)
	CollectionService:GetInstanceAddedSignal(TrombyConfig.TAG):Connect(onTrombyAdded)
	for _, tromby in CollectionService:GetTagged(TrombyConfig.TAG) do
		onTrombyAdded(tromby)
	end
end

return TrombyDialogue
