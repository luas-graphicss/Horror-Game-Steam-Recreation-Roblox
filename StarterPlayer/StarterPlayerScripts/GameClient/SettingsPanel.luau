local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameSettings = require(Shared:WaitForChild("GameSettings"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SettingsApplier = require(script.Parent:WaitForChild("SettingsApplier"))

local ROWS_NAME = "Rows"
local LABEL_NAME = "Label"
local VALUE_NAME = "Value"
local SLIDER_NAME = "Slider"
local RAIL_NAME = "Rail"
local FILL_NAME = "Fill"
local KNOB_NAME = "Knob"

local SettingsPanel = {}

local player = Players.LocalPlayer

local function isPointerPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function bindRow(row: Instance, name: string)
	local definition = GameSettings.DEFINITIONS[name]
	local label = row:WaitForChild(LABEL_NAME) :: TextLabel
	local valueLabel = row:WaitForChild(VALUE_NAME) :: TextLabel
	local slider = row:WaitForChild(SLIDER_NAME) :: Frame
	local fill = slider:WaitForChild(RAIL_NAME):WaitForChild(FILL_NAME) :: Frame
	local knob = slider:WaitForChild(KNOB_NAME) :: Frame
	local dragInput: InputObject? = nil
	local value = GameSettings.read(player, name)
	label.Text = definition.label

	local function render()
		local share = (value - definition.min) / (definition.max - definition.min)
		fill.Size = UDim2.fromScale(share, 1)
		knob.Position = UDim2.fromScale(share, 0.5)
		valueLabel.Text = GameSettings.format(name, value)
	end

	local function slideTo(screenX: number)
		local share = math.clamp((screenX - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
		value = GameSettings.sanitize(name, definition.min + share * (definition.max - definition.min)) or value
		render()
		SettingsApplier.apply(name, value)
	end

	slider.InputBegan:Connect(function(input: InputObject)
		if isPointerPress(input) then
			dragInput = input
			slideTo(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragInput and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
			slideTo(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if dragInput and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragInput = nil
			Remotes.ChangeSetting:FireServer(name, value)
		end
	end)
	player:GetAttributeChangedSignal(definition.attribute):Connect(function()
		if not dragInput then
			value = GameSettings.read(player, name)
			render()
		end
	end)
	render()
end

function SettingsPanel.bind(panel: Instance)
	local rows = panel:WaitForChild(ROWS_NAME)
	for _, name in GameSettings.ORDER do
		bindRow(rows:WaitForChild(name), name)
	end
end

return SettingsPanel
