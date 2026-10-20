local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PhoneConfig = require(Shared:WaitForChild("PhoneConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AimTarget = require(script.Parent:WaitForChild("AimTarget"))
local InteractionPrompt = require(script.Parent:WaitForChild("InteractionPrompt"))
local PrimaryAction = require(script.Parent:WaitForChild("PrimaryAction"))

local RENDER_STEP_NAME = "PhoneInteraction"
local ANSWER_PROMPT: InteractionPrompt.Content = {
	title = "Telefone",
	description = "AlguÃ©m estÃ¡ ligando.",
	action = "Click to answer",
}

local PhoneInteraction = {}

local focusedPhone: Instance? = nil

local function isRinging(phone: Instance): boolean
	return typeof(phone:GetAttribute(PhoneConfig.RINGING_CALL_ATTRIBUTE)) == "string"
end

local function focus(phone: Instance?)
	if phone == focusedPhone then
		return
	end
	if focusedPhone then
		InteractionPrompt.hide(focusedPhone)
	end
	focusedPhone = phone
	if phone then
		InteractionPrompt.show(phone, ANSWER_PROMPT)
	end
end

local function onRenderStep()
	local phone = AimTarget.find(PhoneConfig.PHONE_TAG)
	focus(if phone and isRinging(phone) then phone else nil)
end

local function onPrimaryAction()
	if focusedPhone then
		Remotes.AnswerPhone:FireServer()
	end
end

function PhoneInteraction.start()
	PrimaryAction.triggered:Connect(onPrimaryAction)
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

return PhoneInteraction
