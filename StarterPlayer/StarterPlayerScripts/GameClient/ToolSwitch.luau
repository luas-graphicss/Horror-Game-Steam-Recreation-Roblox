local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ToolCatalog = require(Shared:WaitForChild("ToolCatalog"))

local ACTION_NAME = "SwitchTool"
local SWITCH_KEY = Enum.KeyCode.Q
local SWITCH_BUTTON = Enum.KeyCode.ButtonY
local MIN_TOOLS_TO_SWITCH = 2

local ToolSwitch = {}

local player = Players.LocalPlayer
local isBound = false

local function owns(itemId: string): boolean
	return player:GetAttribute(PlayerAttributes.ownedItem(itemId)) == true
end

local function equippedTool(): string?
	local itemId = player:GetAttribute(PlayerAttributes.EQUIPPED_TOOL)
	return if typeof(itemId) == "string" then itemId else nil
end

local function onSwitchAction(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local nextTool = ToolCatalog.nextOwned(equippedTool(), owns)
	if nextTool then
		Remotes.EquipTool:FireServer(nextTool)
	end
	return Enum.ContextActionResult.Sink
end

local function refreshBinding()
	local canSwitch = ToolCatalog.ownedCount(owns) >= MIN_TOOLS_TO_SWITCH
	if canSwitch == isBound then
		return
	end
	isBound = canSwitch
	if canSwitch then
		ContextActionService:BindAction(ACTION_NAME, onSwitchAction, false, SWITCH_KEY, SWITCH_BUTTON)
	else
		ContextActionService:UnbindAction(ACTION_NAME)
	end
end

function ToolSwitch.start()
	for _, itemId in ToolCatalog.SWITCH_ORDER do
		player:GetAttributeChangedSignal(PlayerAttributes.ownedItem(itemId)):Connect(refreshBinding)
	end
	refreshBinding()
end

return ToolSwitch
