local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameSettings = require(Shared:WaitForChild("GameSettings"))
local MasterVolume = require(script.Parent:WaitForChild("MasterVolume"))

local SettingsApplier = {}

local player = Players.LocalPlayer
local fieldOfView = GameSettings.DEFINITIONS[GameSettings.FIELD_OF_VIEW].default

local function applyFieldOfView()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = fieldOfView
	end
end

function SettingsApplier.apply(name: string, value: number)
	if name == GameSettings.VOLUME then
		MasterVolume.set(value)
	elseif name == GameSettings.SENSITIVITY then
		UserInputService.MouseDeltaSensitivity = value
	elseif name == GameSettings.FIELD_OF_VIEW then
		fieldOfView = value
		applyFieldOfView()
	end
end

local function follow(name: string)
	local function applyStored()
		SettingsApplier.apply(name, GameSettings.read(player, name))
	end
	player:GetAttributeChangedSignal(GameSettings.DEFINITIONS[name].attribute):Connect(applyStored)
	applyStored()
end

function SettingsApplier.start()
	for _, name in GameSettings.ORDER do
		follow(name)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyFieldOfView)
end

return SettingsApplier
