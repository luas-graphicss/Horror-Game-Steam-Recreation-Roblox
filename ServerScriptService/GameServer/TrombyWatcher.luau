local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TrombyWatcherConfig = require(ReplicatedStorage.Shared.TrombyWatcherConfig)
local TrombyWatcherOfferings = require(ReplicatedStorage.Shared.TrombyWatcherOfferings)
local PlayerData = require(script.Parent.PlayerData)
local PlayerReach = require(script.Parent.PlayerReach)
local RemoteThrottle = require(script.Parent.RemoteThrottle)

local TALK_REQUESTS_PER_SECOND = 2

export type Snapshot = {
	contributions: number,
	hasDeparted: boolean,
}

local contributedEvent = Instance.new("BindableEvent")
local departedEvent = Instance.new("BindableEvent")

local TrombyWatcher = {
	contributed = contributedEvent.Event,
	departed = departedEvent.Event,
}

local watcher: Model
local listener: Player? = nil
local hasDeparted = false

local function contributions(): number
	local count = watcher:GetAttribute(TrombyWatcherConfig.CONTRIBUTIONS_ATTRIBUTE)
	return if typeof(count) == "number" then count else 0
end

local function setListener(player: Player?)
	listener = player
	watcher:SetAttribute(TrombyWatcherConfig.LISTENER_ATTRIBUTE, if player then player.UserId else nil)
end

local function canTalk(player: Player): boolean
	local offering = TrombyWatcherOfferings.at(contributions())
	return not hasDeparted
		and offering ~= nil
		and PlayerData.meat(player) >= offering.biomassCost
		and PlayerReach.isWithin(player, watcher:GetPivot().Position, TrombyWatcherConfig.TALK_RANGE)
end

local function onTalkRequested(player: Player)
	if not listener and canTalk(player) then
		setListener(player)
	end
end

local function onAnswered(player: Player, accepted: unknown)
	if player ~= listener or typeof(accepted) ~= "boolean" then
		return
	end
	local offering = TrombyWatcherOfferings.at(contributions())
	local hasContributed = accepted and offering ~= nil and PlayerData.trySpendMeat(player, offering.biomassCost)
	if hasContributed then
		watcher:SetAttribute(TrombyWatcherConfig.CONTRIBUTIONS_ATTRIBUTE, contributions() + 1)
	end
	setListener(nil)
	if hasContributed then
		contributedEvent:Fire(contributions())
	end
end

local function depart()
	if not hasDeparted then
		hasDeparted = true
		watcher:Destroy()
	end
end

local function onDismissRequested()
	if not hasDeparted and not listener and TrombyWatcherOfferings.isFulfilled(contributions()) then
		depart()
		departedEvent:Fire()
	end
end

local function onPlayerRemoving(player: Player)
	if player == listener then
		setListener(nil)
	end
end

function TrombyWatcher.snapshot(): Snapshot
	return { contributions = contributions(), hasDeparted = hasDeparted }
end

function TrombyWatcher.restore(snapshot: Snapshot)
	local count = math.clamp(math.floor(snapshot.contributions), 0, TrombyWatcherOfferings.count())
	watcher:SetAttribute(TrombyWatcherConfig.CONTRIBUTIONS_ATTRIBUTE, count)
	if snapshot.hasDeparted then
		depart()
	end
end

function TrombyWatcher.start()
	watcher = CollectionService:GetTagged(TrombyWatcherConfig.TAG)[1] :: Model
	RemoteThrottle.connect(Remotes.TalkToTrombyWatcher, TALK_REQUESTS_PER_SECOND, onTalkRequested)
	RemoteThrottle.connect(Remotes.AnswerTrombyWatcher, TALK_REQUESTS_PER_SECOND, onAnswered)
	RemoteThrottle.connect(Remotes.DismissTrombyWatcher, TALK_REQUESTS_PER_SECOND, onDismissRequested)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return TrombyWatcher
