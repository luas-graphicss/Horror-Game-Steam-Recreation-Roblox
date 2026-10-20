local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local TrombyWatcherConfig = require(Shared:WaitForChild("TrombyWatcherConfig"))
local TrombyWatcherOfferings = require(Shared:WaitForChild("TrombyWatcherOfferings"))
local AimTarget = require(script.Parent:WaitForChild("AimTarget"))
local InteractionPrompt = require(script.Parent:WaitForChild("InteractionPrompt"))
local PrimaryAction = require(script.Parent:WaitForChild("PrimaryAction"))

local RENDER_STEP_NAME = "TrombyWatcherInteraction"
local TITLE = "Falar com Clip"
local TITLE_COLOR = Color3.fromRGB(176, 104, 232)
local REQUIREMENT_FORMAT = "Requer %d biomassa (carne)"

local TrombyWatcherInteraction = {}

local player = Players.LocalPlayer
local focusedWatcher: Instance? = nil

local function meatStock(): number
	local meat = player:GetAttribute(PlayerAttributes.MEAT)
	return if typeof(meat) == "number" then meat else 0
end

local function currentOffering(watcher: Instance): TrombyWatcherOfferings.Offering?
	local contributions = watcher:GetAttribute(TrombyWatcherConfig.CONTRIBUTIONS_ATTRIBUTE)
	return TrombyWatcherOfferings.at(if typeof(contributions) == "number" then contributions else 0)
end

local function canTalk(offering: TrombyWatcherOfferings.Offering): boolean
	return meatStock() >= offering.biomassCost
end

local function promptFor(watcher: Instance): InteractionPrompt.Content?
	local offering = currentOffering(watcher)
	if not offering then
		return nil
	end
	return {
		title = TITLE,
		titleColor = TITLE_COLOR,
		action = string.format(REQUIREMENT_FORMAT, offering.biomassCost),
		isActionUnavailable = meatStock() < offering.biomassCost,
		isActionReady = canTalk(offering),
	}
end

local function refreshPrompt()
	local watcher = focusedWatcher
	if not watcher then
		return
	end
	local prompt = promptFor(watcher)
	if prompt then
		InteractionPrompt.show(watcher, prompt)
	else
		InteractionPrompt.hide(watcher)
	end
end

local function isAvailable(watcher: Instance): boolean
	return watcher:GetAttribute(TrombyWatcherConfig.LISTENER_ATTRIBUTE) == nil
end

local function focus(watcher: Instance?)
	if watcher == focusedWatcher then
		return
	end
	if focusedWatcher then
		InteractionPrompt.hide(focusedWatcher)
	end
	focusedWatcher = watcher
	refreshPrompt()
end

local function onRenderStep()
	local watcher = AimTarget.find(TrombyWatcherConfig.TAG)
	focus(if watcher and isAvailable(watcher) then watcher else nil)
end

local function onPrimaryAction()
	local offering = if focusedWatcher then currentOffering(focusedWatcher) else nil
	if offering and canTalk(offering) then
		Remotes.TalkToTrombyWatcher:FireServer()
	end
end

function TrombyWatcherInteraction.start()
	player:GetAttributeChangedSignal(PlayerAttributes.MEAT):Connect(refreshPrompt)
	PrimaryAction.triggered:Connect(onPrimaryAction)
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

return TrombyWatcherInteraction
