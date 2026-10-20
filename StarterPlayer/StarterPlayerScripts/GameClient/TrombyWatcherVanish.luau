local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local TrombyWatcherConfig = require(Shared:WaitForChild("TrombyWatcherConfig"))
local TrombyWatcherOfferings = require(Shared:WaitForChild("TrombyWatcherOfferings"))
local TrombyWatcherDialogue = require(script.Parent:WaitForChild("TrombyWatcherDialogue"))
local VanishWhenUnseen = require(script.Parent:WaitForChild("VanishWhenUnseen"))

local TrombyWatcherVanish = {}

local contributionConnections: { [Instance]: RBXScriptConnection } = {}
local departing: { [Instance]: boolean } = {}

local function isFulfilled(watcher: Instance): boolean
	local contributions = watcher:GetAttribute(TrombyWatcherConfig.CONTRIBUTIONS_ATTRIBUTE)
	return TrombyWatcherOfferings.isFulfilled(if typeof(contributions) == "number" then contributions else 0)
end

local function dismiss()
	Remotes.DismissTrombyWatcher:FireServer()
end

local function departOnceUnseen(watcher: Instance)
	if departing[watcher] or not watcher:IsA("Model") or not isFulfilled(watcher) or TrombyWatcherDialogue.isConversing() then
		return
	end
	departing[watcher] = true
	VanishWhenUnseen.watch(watcher, dismiss)
end

local function bind(watcher: Instance)
	if contributionConnections[watcher] then
		return
	end
	contributionConnections[watcher] = watcher:GetAttributeChangedSignal(TrombyWatcherConfig.CONTRIBUTIONS_ATTRIBUTE):Connect(function()
		departOnceUnseen(watcher)
	end)
	departOnceUnseen(watcher)
end

local function unbind(watcher: Instance)
	local connection = contributionConnections[watcher]
	if connection then
		connection:Disconnect()
	end
	contributionConnections[watcher] = nil
	departing[watcher] = nil
end

function TrombyWatcherVanish.start()
	TrombyWatcherDialogue.finished:Connect(departOnceUnseen)
	CollectionService:GetInstanceAddedSignal(TrombyWatcherConfig.TAG):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(TrombyWatcherConfig.TAG):Connect(unbind)
	for _, watcher in CollectionService:GetTagged(TrombyWatcherConfig.TAG) do
		bind(watcher)
	end
end

return TrombyWatcherVanish
