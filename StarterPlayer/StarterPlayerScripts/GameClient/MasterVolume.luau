local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SpokenLines = require(script.Parent:WaitForChild("SpokenLines"))

local GROUP_NAME = "MasterVolume"
local PLAYER_GUI_NAME = "PlayerGui"

local MasterVolume = {}

local group = Instance.new("SoundGroup")
group.Name = GROUP_NAME
group.Parent = SoundService

local fadeTween: Tween? = nil

local function adopt(instance: Instance)
	if instance:IsA("Sound") and not instance.SoundGroup then
		instance.SoundGroup = group
	end
end

local function adoptWithin(root: Instance)
	root.DescendantAdded:Connect(adopt)
	for _, descendant in root:GetDescendants() do
		adopt(descendant)
	end
end

local function cancelFade()
	if fadeTween then
		fadeTween:Cancel()
		fadeTween = nil
	end
end

function MasterVolume.set(level: number)
	cancelFade()
	group.Volume = level
	SpokenLines.setVolume(level)
end

function MasterVolume.fadeOut(duration: number)
	cancelFade()
	local tween = TweenService:Create(group, TweenInfo.new(duration, Enum.EasingStyle.Sine), { Volume = 0 })
	fadeTween = tween
	tween:Play()
end

function MasterVolume.start()
	adoptWithin(Workspace)
	adoptWithin(SoundService)
	adoptWithin(ReplicatedStorage)
	adoptWithin(Players.LocalPlayer:WaitForChild(PLAYER_GUI_NAME))
end

return MasterVolume
