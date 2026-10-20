local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local TrombyConfig = require(Shared:WaitForChild("TrombyConfig"))
local AimTarget = require(script.Parent:WaitForChild("AimTarget"))
local InteractionPrompt = require(script.Parent:WaitForChild("InteractionPrompt"))
local PrimaryAction = require(script.Parent:WaitForChild("PrimaryAction"))

local RENDER_STEP_NAME = "TrombyInteraction"
local TALK_PROMPT: InteractionPrompt.Content = {
	title = "Tromby",
	description = "Seu assistente.",
	action = "Click to talk",
}

local TrombyInteraction = {}

local focusedTromby: Instance? = nil

local function isAvailable(tromby: Instance): boolean
	return tromby:GetAttribute(TrombyConfig.LISTENER_ATTRIBUTE) == nil
end

local function focus(tromby: Instance?)
	if tromby == focusedTromby then
		return
	end
	if focusedTromby then
		InteractionPrompt.hide(focusedTromby)
	end
	focusedTromby = tromby
	if tromby then
		InteractionPrompt.show(tromby, TALK_PROMPT)
	end
end

local function onRenderStep()
	local tromby = AimTarget.find(TrombyConfig.TAG)
	focus(if tromby and isAvailable(tromby) then tromby else nil)
end

local function onPrimaryAction()
	if focusedTromby then
		Remotes.TalkToTromby:FireServer()
	end
end

function TrombyInteraction.start()
	PrimaryAction.triggered:Connect(onPrimaryAction)
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

return TrombyInteraction
