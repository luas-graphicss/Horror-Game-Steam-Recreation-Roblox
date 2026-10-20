local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EndingConfig = require(ReplicatedStorage.Shared.EndingConfig)
local PhoneCalls = require(ReplicatedStorage.Shared.PhoneCalls)
local SectorDoorConfig = require(ReplicatedStorage.Shared.SectorDoorConfig)
local TrombyWatcherOfferings = require(ReplicatedStorage.Shared.TrombyWatcherOfferings)
local BoltStation = require(script.Parent.BoltStation)
local CrankGenerator = require(script.Parent.CrankGenerator)
local Debt = require(script.Parent.Debt)
local Ending = require(script.Parent.Ending)
local Phone = require(script.Parent.Phone)
local PlayerData = require(script.Parent.PlayerData)
local SectorDoor = require(script.Parent.SectorDoor)
local Tromby = require(script.Parent.Tromby)
local TrombyWatcher = require(script.Parent.TrombyWatcher)
local WallEye = require(script.Parent.WallEye)
local WallEyeSpawner = require(script.Parent.WallEyeSpawner)

local SECONDS_PER_MINUTE = 60
local CRANK_SESSIONS_BEFORE_WARNING = 2
local RARE_BOLTS_BEFORE_PRAISE = 2
local CONTRIBUTIONS_BEFORE_NOTICE = 2
local EXPLANATION_DELAY_AFTER_SIGHTING = 11
local GRATITUDE_SETTLE_DELAY = 2
local MIN_PRODUCTIVITY_CALL_DELAY = 10 * SECONDS_PER_MINUTE
local MAX_PRODUCTIVITY_CALL_DELAY = 12 * SECONDS_PER_MINUTE
local MIN_BLOOD_CALL_DELAY = 15 * SECONDS_PER_MINUTE
local MAX_BLOOD_CALL_DELAY = 18 * SECONDS_PER_MINUTE

export type Snapshot = {
	rung: { string },
	heard: { string },
	pending: { [string]: number },
	crankSessions: number,
}

local Storyline = {}

local random = Random.new()
local rung: { [string]: boolean } = {}
local heard: { [string]: boolean } = {}
local dueAt: { [string]: number } = {}
local delaysBeforeShift: { [string]: number } = {}
local crankSessions = 0
local hasBegun = false

local function ring(callId: string)
	rung[callId] = true
	dueAt[callId] = nil
	if hasBegun then
		Phone.ring(callId)
	end
end

local function ringOnce(callId: string)
	if not rung[callId] then
		ring(callId)
	end
end

local function schedule(callId: string, delay: number)
	if rung[callId] or dueAt[callId] then
		return
	end
	if not hasBegun then
		delaysBeforeShift[callId] = delay
		return
	end
	local due = os.clock() + delay
	dueAt[callId] = due
	task.delay(delay, function()
		if dueAt[callId] == due then
			ring(callId)
		end
	end)
end

local function ringWarningWhenDue()
	if heard[PhoneCalls.INTRO] and crankSessions >= CRANK_SESSIONS_BEFORE_WARNING then
		ringOnce(PhoneCalls.WARNING)
	end
end

local function onCrankingStopped()
	crankSessions += 1
	ringWarningWhenDue()
end

local function ringSectorTwoWhenAffordable(player: Player)
	if heard[PhoneCalls.BLOOD] and PlayerData.balanceCents(player) >= SectorDoorConfig.PRICE_CENTS then
		ringOnce(PhoneCalls.SECTOR_TWO)
	end
end

local function onBoltTightened(player: Player)
	if PlayerData.rareBoltsTightened(player) >= RARE_BOLTS_BEFORE_PRAISE then
		ringOnce(PhoneCalls.PRAISE)
	end
	ringSectorTwoWhenAffordable(player)
end

local function gratitudeDuration(contributions: number): number
	local offering = TrombyWatcherOfferings.at(contributions - 1)
	local total = GRATITUDE_SETTLE_DELAY
	if offering then
		for _, line in offering.conversation.gratitude do
			total += PhoneCalls.lineDuration(line)
		end
	end
	return total
end

local function onWatcherContributed(contributions: number)
	if contributions == CONTRIBUTIONS_BEFORE_NOTICE then
		schedule(PhoneCalls.WATCHER_NOTICE, gratitudeDuration(contributions))
	end
end

local function onWatcherDeparted()
	ringOnce(PhoneCalls.WATCHER_FINALE)
end

local function onDebtSettled()
	ringOnce(PhoneCalls.DEBT_PAID)
end

local function applyAftermath(callId: string)
	if callId == PhoneCalls.WARNING then
		WallEye.awaken()
		WallEyeSpawner.begin()
	elseif callId == PhoneCalls.EXPLANATION then
		Tromby.appear()
	elseif callId == PhoneCalls.SECTOR_TWO then
		SectorDoor.unlock()
	end
end

local function onCallEnded(callId: string)
	heard[callId] = true
	applyAftermath(callId)
	if callId == PhoneCalls.INTRO then
		ringWarningWhenDue()
	elseif callId == PhoneCalls.EXPLANATION then
		schedule(PhoneCalls.PRODUCTIVITY, random:NextNumber(MIN_PRODUCTIVITY_CALL_DELAY, MAX_PRODUCTIVITY_CALL_DELAY))
	elseif callId == PhoneCalls.PRODUCTIVITY then
		schedule(PhoneCalls.BLOOD, random:NextNumber(MIN_BLOOD_CALL_DELAY, MAX_BLOOD_CALL_DELAY))
	elseif callId == PhoneCalls.BLOOD then
		for _, player in Players:GetPlayers() do
			ringSectorTwoWhenAffordable(player)
		end
	elseif callId == PhoneCalls.WATCHER_FINALE then
		Ending.conclude(EndingConfig.CLIP)
	elseif callId == PhoneCalls.DEBT_PAID then
		Ending.conclude(EndingConfig.DEBT)
	end
end

local function onEyeFirstSeen()
	schedule(PhoneCalls.EXPLANATION, EXPLANATION_DELAY_AFTER_SIGHTING)
end

local function keysOf(set: { [string]: boolean }): { string }
	local keys = {}
	for key in set do
		table.insert(keys, key)
	end
	return keys
end

local function knownCalls(callIds: { string }): { [string]: boolean }
	local set = {}
	for _, callId in callIds do
		if PhoneCalls.SCRIPTS[callId] then
			set[callId] = true
		end
	end
	return set
end

function Storyline.snapshot(): Snapshot
	local pending = table.clone(delaysBeforeShift)
	local now = os.clock()
	for callId, due in dueAt do
		pending[callId] = math.max(due - now, 0)
	end
	return {
		rung = keysOf(rung),
		heard = keysOf(heard),
		pending = pending,
		crankSessions = crankSessions,
	}
end

function Storyline.restore(snapshot: Snapshot)
	rung = knownCalls(snapshot.rung)
	heard = knownCalls(snapshot.heard)
	crankSessions = snapshot.crankSessions
	for callId, delay in snapshot.pending do
		if PhoneCalls.SCRIPTS[callId] and not rung[callId] then
			delaysBeforeShift[callId] = delay
		end
	end
	for _, callId in PhoneCalls.ORDER do
		if heard[callId] then
			applyAftermath(callId)
		end
	end
end

function Storyline.begin()
	if hasBegun then
		return
	end
	hasBegun = true
	for _, callId in PhoneCalls.ORDER do
		if rung[callId] and not heard[callId] then
			Phone.ring(callId)
		end
	end
	for callId, delay in delaysBeforeShift do
		schedule(callId, delay)
	end
	table.clear(delaysBeforeShift)
	ringOnce(PhoneCalls.INTRO)
	ringWarningWhenDue()
	for _, player in Players:GetPlayers() do
		ringSectorTwoWhenAffordable(player)
	end
end

function Storyline.start()
	CrankGenerator.crankingStopped:Connect(onCrankingStopped)
	BoltStation.boltTightened:Connect(onBoltTightened)
	Phone.callEnded:Connect(onCallEnded)
	WallEye.firstSeen:Connect(onEyeFirstSeen)
	TrombyWatcher.contributed:Connect(onWatcherContributed)
	TrombyWatcher.departed:Connect(onWatcherDeparted)
	Debt.settled:Connect(onDebtSettled)
end

return Storyline
