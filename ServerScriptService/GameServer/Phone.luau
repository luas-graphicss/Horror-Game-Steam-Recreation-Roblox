local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhoneCalls = require(ReplicatedStorage.Shared.PhoneCalls)
local PhoneConfig = require(ReplicatedStorage.Shared.PhoneConfig)
local PhoneWorld = require(ReplicatedStorage.Shared.PhoneWorld)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerReach = require(script.Parent.PlayerReach)
local RemoteThrottle = require(script.Parent.RemoteThrottle)

local ANSWER_RANGE = 14
local ANSWER_REQUESTS_PER_SECOND = 2
local QUEUED_CALL_DELAY = 8

local callEndedEvent = Instance.new("BindableEvent")

local Phone = {
	callEnded = callEndedEvent.Event,
}

local world: PhoneWorld.Instances
local queuedCalls: { string } = {}

local function ringingCall(): string?
	local callId = world.box:GetAttribute(PhoneConfig.RINGING_CALL_ATTRIBUTE)
	return if typeof(callId) == "string" then callId else nil
end

local function isBusy(): boolean
	return ringingCall() ~= nil or world.box:GetAttribute(PhoneConfig.ACTIVE_CALL_ATTRIBUTE) ~= nil
end

local function ringNextQueuedCall()
	if isBusy() or #queuedCalls == 0 then
		return
	end
	world.box:SetAttribute(PhoneConfig.RINGING_CALL_ATTRIBUTE, table.remove(queuedCalls, 1))
end

local function hangUp(callId: string)
	world.box:SetAttribute(PhoneConfig.ACTIVE_CALL_ATTRIBUTE, nil)
	callEndedEvent:Fire(callId)
	task.delay(QUEUED_CALL_DELAY, ringNextQueuedCall)
end

local function onAnswerRequested(player: Player)
	local callId = ringingCall()
	if not callId or not PlayerReach.isWithin(player, world.housing.Position, ANSWER_RANGE) then
		return
	end
	world.box:SetAttribute(PhoneConfig.RINGING_CALL_ATTRIBUTE, nil)
	world.box:SetAttribute(PhoneConfig.ACTIVE_CALL_ATTRIBUTE, callId)
	task.delay(PhoneCalls.duration(callId), hangUp, callId)
end

function Phone.ring(callId: string)
	if isBusy() then
		table.insert(queuedCalls, callId)
		return
	end
	world.box:SetAttribute(PhoneConfig.RINGING_CALL_ATTRIBUTE, callId)
end

function Phone.start()
	world = PhoneWorld.resolve()
	RemoteThrottle.connect(Remotes.AnswerPhone, ANSWER_REQUESTS_PER_SECOND, onAnswerRequested)
end

return Phone
