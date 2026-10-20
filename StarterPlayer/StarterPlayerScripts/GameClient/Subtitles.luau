local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local PLAYER_GUI_NAME = "PlayerGui"
local SUBTITLES_NAME = "Subtitles"
local LINE_NAME = "Line"
local HIDE_DURATION = 0.8

local Subtitles = {}

local line: TextLabel? = nil
local strokeTransparency = 1
local activeTween: Tween? = nil

local function play(tween: Tween)
	if activeTween then
		activeTween:Cancel()
	end
	activeTween = tween
	tween:Play()
end

function Subtitles.show(text: string, revealDuration: number)
	if not line then
		return
	end
	line.Text = text
	line.MaxVisibleGraphemes = 0
	line.TextTransparency = 0
	line.TextStrokeTransparency = strokeTransparency
	local graphemeCount = utf8.len(text) or #text
	play(TweenService:Create(line, TweenInfo.new(revealDuration, Enum.EasingStyle.Linear), { MaxVisibleGraphemes = graphemeCount }))
end

function Subtitles.hide()
	if not line then
		return
	end
	play(TweenService:Create(line, TweenInfo.new(HIDE_DURATION), { TextTransparency = 1, TextStrokeTransparency = 1 }))
end

function Subtitles.start()
	local label = Players.LocalPlayer:WaitForChild(PLAYER_GUI_NAME):WaitForChild(SUBTITLES_NAME):WaitForChild(LINE_NAME) :: TextLabel
	strokeTransparency = label.TextStrokeTransparency
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	line = label
end

return Subtitles
