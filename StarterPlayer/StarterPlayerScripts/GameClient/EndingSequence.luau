local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EndingConfig = require(Shared:WaitForChild("EndingConfig"))
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local CallNarration = require(script.Parent:WaitForChild("CallNarration"))
local MasterVolume = require(script.Parent:WaitForChild("MasterVolume"))
local PlayerControls = require(script.Parent:WaitForChild("PlayerControls"))
local ViewportFit = require(script.Parent:WaitForChild("ViewportFit"))

local PLAYER_GUI_NAME = "PlayerGui"
local GUI_NAME = "EndingScreen"
local BLACKOUT_NAME = "Blackout"
local CONTENT_NAME = "Content"
local TITLE_NAME = "Title"
local BODY_NAME = "Body"
local FAREWELL_NAME = "Farewell"
local FIT_NAME = "Fit"
local FADE_TO_BLACK_DURATION = 3.5
local BLACK_HOLD = 1.5
local TITLE_FADE_DURATION = 2
local BODY_DELAY = 1.5
local BODY_FADE_DURATION = 2.5
local READING_CHARACTERS_PER_SECOND = 15
local MIN_READING_TIME = 10
local FAREWELL_FADE_DURATION = 1.5
local CLOSING_HOLD = 5

local EndingSequence = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local blackout: Frame
local title: TextLabel
local body: TextLabel
local farewell: TextLabel
local hasStarted = false

local function fade(instance: Instance, goal: { [string]: number }, duration: number): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), goal)
	tween:Play()
	return tween
end

local function readingTime(text: string): number
	return math.max((utf8.len(text) or #text) / READING_CHARACTERS_PER_SECOND, MIN_READING_TIME)
end

local function play(screen: EndingConfig.Screen)
	CallNarration.awaitIdle()
	PlayerControls.setEnabled(false)
	title.Text = screen.title
	body.Text = screen.body
	farewell.Text = EndingConfig.FAREWELL
	blackout.BackgroundTransparency = 1
	for _, label in { title, body, farewell } do
		label.TextTransparency = 1
	end
	gui.Enabled = true
	MasterVolume.fadeOut(FADE_TO_BLACK_DURATION)
	fade(blackout, { BackgroundTransparency = 0 }, FADE_TO_BLACK_DURATION).Completed:Wait()
	task.wait(BLACK_HOLD)
	fade(title, { TextTransparency = 0 }, TITLE_FADE_DURATION)
	task.wait(BODY_DELAY)
	fade(body, { TextTransparency = 0 }, BODY_FADE_DURATION)
	task.wait(BODY_FADE_DURATION + readingTime(screen.body))
	fade(farewell, { TextTransparency = 0 }, FAREWELL_FADE_DURATION)
	task.wait(FAREWELL_FADE_DURATION + CLOSING_HOLD)
	player:Kick(EndingConfig.KICK_MESSAGE)
end

local function onEndingChanged()
	local endingId = player:GetAttribute(PlayerAttributes.ENDING)
	local screen = if typeof(endingId) == "string" then EndingConfig.SCREENS[endingId] else nil
	if screen and not hasStarted then
		hasStarted = true
		task.spawn(play, screen)
	end
end

function EndingSequence.start()
	gui = player:WaitForChild(PLAYER_GUI_NAME):WaitForChild(GUI_NAME) :: ScreenGui
	blackout = gui:WaitForChild(BLACKOUT_NAME) :: Frame
	local content = gui:WaitForChild(CONTENT_NAME)
	title = content:WaitForChild(TITLE_NAME) :: TextLabel
	body = content:WaitForChild(BODY_NAME) :: TextLabel
	farewell = content:WaitForChild(FAREWELL_NAME) :: TextLabel
	ViewportFit.bind({ content:WaitForChild(FIT_NAME) :: UIScale })
	gui.Enabled = false
	player:GetAttributeChangedSignal(PlayerAttributes.ENDING):Connect(onEndingChanged)
	onEndingChanged()
end

return EndingSequence
