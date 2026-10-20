local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Money = require(Shared:WaitForChild("Money"))
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SectorDoorConfig = require(Shared:WaitForChild("SectorDoorConfig"))
local SectorDoorWorld = require(Shared:WaitForChild("SectorDoorWorld"))
local AimTarget = require(script.Parent:WaitForChild("AimTarget"))
local InteractionPrompt = require(script.Parent:WaitForChild("InteractionPrompt"))
local PrimaryAction = require(script.Parent:WaitForChild("PrimaryAction"))

local RENDER_STEP_NAME = "SectorDoorInteraction"
local OPEN_TEXT_FORMAT = "Open: %sR$"

local SectorDoorInteraction = {}

local player = Players.LocalPlayer
local world: SectorDoorWorld.Instances
local isFocused = false

local function balanceCents(): number
	local balance = player:GetAttribute(PlayerAttributes.BALANCE_CENTS)
	return if typeof(balance) == "number" then balance else 0
end

local function isForSale(): boolean
	return world.door:GetAttribute(SectorDoorConfig.STATE_ATTRIBUTE) == SectorDoorConfig.UNLOCKED_STATE
end

local function offer(): InteractionPrompt.Content
	return {
		action = string.format(OPEN_TEXT_FORMAT, Money.format(SectorDoorConfig.PRICE_CENTS)),
		isActionUnavailable = balanceCents() < SectorDoorConfig.PRICE_CENTS,
	}
end

local function setFocused(focused: boolean)
	if focused == isFocused then
		return
	end
	isFocused = focused
	if focused then
		InteractionPrompt.show(world.leafGroup, offer())
	else
		InteractionPrompt.hide(world.leafGroup)
	end
end

local function refreshPrompt()
	if isFocused then
		InteractionPrompt.show(world.leafGroup, offer())
	end
end

local function onRenderStep()
	setFocused(isForSale() and AimTarget.find(SectorDoorConfig.DOOR_TAG) ~= nil)
end

local function onPrimaryAction()
	if isFocused then
		Remotes.OpenSectorDoor:FireServer()
	end
end

function SectorDoorInteraction.start()
	world = SectorDoorWorld.resolve()
	player:GetAttributeChangedSignal(PlayerAttributes.BALANCE_CENTS):Connect(refreshPrompt)
	PrimaryAction.triggered:Connect(onPrimaryAction)
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

return SectorDoorInteraction
