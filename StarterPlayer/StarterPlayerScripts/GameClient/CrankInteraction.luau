local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrankCharge = require(Shared:WaitForChild("CrankCharge"))
local CrankGeneratorConfig = require(Shared:WaitForChild("CrankGeneratorConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AimTarget = require(script.Parent:WaitForChild("AimTarget"))
local InteractionPrompt = require(script.Parent:WaitForChild("InteractionPrompt"))
local PrimaryAction = require(script.Parent:WaitForChild("PrimaryAction"))

local RENDER_STEP_NAME = "CrankInteraction"
local PROMPT_TITLE = "Manivela"
local PROMPT_DESCRIPTION = "Gira o gerador que acende a lÃ¢mpada."
local TURN_PROMPT: InteractionPrompt.Content = {
	title = PROMPT_TITLE,
	description = PROMPT_DESCRIPTION,
	action = "Hold to turn",
}
local FULL_PROMPT: InteractionPrompt.Content = {
	title = PROMPT_TITLE,
	description = PROMPT_DESCRIPTION,
	action = "Fully charged",
}

local CrankInteraction = {}

local focusedCrank: Instance? = nil
local isRequestingCranking = false

local function canTurn(crank: Instance): boolean
	return CrankCharge.hasRoom(CrankCharge.current(crank))
end

local function requestCranking(wantsCranking: boolean)
	if wantsCranking == isRequestingCranking then
		return
	end
	isRequestingCranking = wantsCranking
	Remotes.SetCranking:FireServer(wantsCranking)
end

local function onRenderStep()
	local crank = AimTarget.find(CrankGeneratorConfig.CRANK_TAG)
	if focusedCrank and focusedCrank ~= crank then
		InteractionPrompt.hide(focusedCrank)
	end
	focusedCrank = crank
	local isTurnable = crank ~= nil and canTurn(crank)
	if crank then
		InteractionPrompt.show(crank, if isTurnable then TURN_PROMPT else FULL_PROMPT)
	end
	requestCranking(isTurnable and PrimaryAction.isHeld())
end

function CrankInteraction.start()
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

return CrankInteraction
