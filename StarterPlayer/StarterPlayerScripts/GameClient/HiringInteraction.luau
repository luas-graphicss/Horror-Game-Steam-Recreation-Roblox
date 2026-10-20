local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HiringConfig = require(Shared:WaitForChild("HiringConfig"))
local Money = require(Shared:WaitForChild("Money"))
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AimTarget = require(script.Parent:WaitForChild("AimTarget"))
local HiringDialogue = require(script.Parent:WaitForChild("HiringDialogue"))
local InteractionPrompt = require(script.Parent:WaitForChild("InteractionPrompt"))
local PrimaryAction = require(script.Parent:WaitForChild("PrimaryAction"))

local RENDER_STEP_NAME = "HiringInteraction"
local TERMINAL_TITLE = "Computador Moderno"
local LOCKED_DESCRIPTION = "Libera a contrataÃ§Ã£o de funcionÃ¡rios."
local UNLOCKED_DESCRIPTION = "Contrate funcionÃ¡rios para as esteiras."
local UNLOCK_TEXT_FORMAT = "Unlock: %sR$"
local HIRE_TEXT = "Click to hire"
local DIALOGUE_RANGE = 13

local HiringInteraction = {}

local player = Players.LocalPlayer
local focusedTerminal: Instance? = nil
local dialogueTerminal: PVInstance? = nil

local function balanceCents(): number
	local balance = player:GetAttribute(PlayerAttributes.BALANCE_CENTS)
	return if typeof(balance) == "number" then balance else 0
end

local function hasUnlocked(): boolean
	return player:GetAttribute(PlayerAttributes.HIRING_UNLOCKED) == true
end

local function offer(): InteractionPrompt.Content
	if hasUnlocked() then
		return { title = TERMINAL_TITLE, description = UNLOCKED_DESCRIPTION, action = HIRE_TEXT }
	end
	return {
		title = TERMINAL_TITLE,
		description = LOCKED_DESCRIPTION,
		action = string.format(UNLOCK_TEXT_FORMAT, Money.format(HiringConfig.UNLOCK_PRICE_CENTS)),
		isActionUnavailable = balanceCents() < HiringConfig.UNLOCK_PRICE_CENTS,
	}
end

local function focus(terminal: Instance?)
	if terminal == focusedTerminal then
		return
	end
	if focusedTerminal then
		InteractionPrompt.hide(focusedTerminal)
	end
	focusedTerminal = terminal
	if terminal then
		InteractionPrompt.show(terminal, offer())
	end
end

local function refreshPrompt()
	if focusedTerminal then
		InteractionPrompt.show(focusedTerminal, offer())
	end
end

local function isWithinDialogueRange(terminal: PVInstance): boolean
	local character = player.Character
	local rootPart = character and character.PrimaryPart
	return rootPart ~= nil and (rootPart.Position - terminal:GetPivot().Position).Magnitude <= DIALOGUE_RANGE
end

local function onRenderStep()
	if dialogueTerminal and HiringDialogue.isOpen() and not isWithinDialogueRange(dialogueTerminal) then
		HiringDialogue.close()
	end
	focus(if HiringDialogue.isOpen() then nil else AimTarget.find(HiringConfig.TERMINAL_TAG))
end

local function onPrimaryAction()
	local terminal = focusedTerminal
	if not terminal or not terminal:IsA("PVInstance") then
		return
	end
	if hasUnlocked() then
		dialogueTerminal = terminal
		HiringDialogue.open()
	else
		Remotes.UnlockHiring:FireServer()
	end
end

function HiringInteraction.start()
	player:GetAttributeChangedSignal(PlayerAttributes.BALANCE_CENTS):Connect(refreshPrompt)
	player:GetAttributeChangedSignal(PlayerAttributes.HIRING_UNLOCKED):Connect(refreshPrompt)
	PrimaryAction.triggered:Connect(onPrimaryAction)
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

return HiringInteraction
