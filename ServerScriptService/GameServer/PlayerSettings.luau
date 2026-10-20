local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameSettings = require(ReplicatedStorage.Shared.GameSettings)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteThrottle = require(script.Parent.RemoteThrottle)

local CHANGE_REQUESTS_PER_SECOND = 10

export type Snapshot = { [string]: number }

local PlayerSettings = {}

local function apply(player: Player, name: string, value: unknown)
	local sanitized = GameSettings.sanitize(name, value)
	if sanitized then
		player:SetAttribute(GameSettings.DEFINITIONS[name].attribute, sanitized)
	end
end

local function initialize(player: Player)
	for _, definition in GameSettings.DEFINITIONS do
		player:SetAttribute(definition.attribute, definition.default)
	end
end

local function onChangeRequested(player: Player, name: unknown, value: unknown)
	if typeof(name) == "string" then
		apply(player, name, value)
	end
end

function PlayerSettings.snapshot(player: Player): Snapshot
	local values = {}
	for _, name in GameSettings.ORDER do
		values[name] = GameSettings.read(player, name)
	end
	return values
end

function PlayerSettings.restore(player: Player, snapshot: Snapshot)
	for name, value in snapshot do
		apply(player, name, value)
	end
end

function PlayerSettings.start()
	Players.PlayerAdded:Connect(initialize)
	for _, player in Players:GetPlayers() do
		initialize(player)
	end
	RemoteThrottle.connect(Remotes.ChangeSetting, CHANGE_REQUESTS_PER_SECOND, onChangeRequested)
end

return PlayerSettings
