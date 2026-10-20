local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TrombyConfig = require(ReplicatedStorage.Shared.TrombyConfig)
local PlayerReach = require(script.Parent.PlayerReach)
local RemoteThrottle = require(script.Parent.RemoteThrottle)

local MODEL_NAME = "Tromby"
local TALK_RANGE = 14
local TALK_REQUESTS_PER_SECOND = 2

local Tromby = {}

local model: Model
local listener: Player? = nil
local hasVanished = false

local function isPresent(): boolean
	return model.Parent == Workspace
end

local function vanish()
	hasVanished = true
	listener = nil
	model:Destroy()
end

local function onTalkRequested(player: Player)
	if not isPresent() or listener or not PlayerReach.isWithin(player, model:GetPivot().Position, TALK_RANGE) then
		return
	end
	listener = player
	model:SetAttribute(TrombyConfig.LISTENER_ATTRIBUTE, player.UserId)
end

local function onDismissRequested(player: Player)
	if isPresent() and player == listener then
		vanish()
	end
end

local function onPlayerRemoving(player: Player)
	if not isPresent() or player ~= listener then
		return
	end
	listener = nil
	model:SetAttribute(TrombyConfig.LISTENER_ATTRIBUTE, nil)
end

function Tromby.appear()
	if model.Parent == ServerStorage then
		model.Parent = Workspace
	end
end

function Tromby.hasVanished(): boolean
	return hasVanished
end

function Tromby.restore(vanished: boolean)
	if vanished and not hasVanished then
		vanish()
	end
end

function Tromby.start()
	model = ServerStorage:WaitForChild(MODEL_NAME) :: Model
	RemoteThrottle.connect(Remotes.TalkToTromby, TALK_REQUESTS_PER_SECOND, onTalkRequested)
	RemoteThrottle.connect(Remotes.DismissTromby, TALK_REQUESTS_PER_SECOND, onDismissRequested)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return Tromby
