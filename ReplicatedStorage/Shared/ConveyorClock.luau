local Workspace = game:GetService("Workspace")

local BoltStationConfig = require(script.Parent.BoltStationConfig)

local ConveyorClock = {}

local function readNumber(belt: Instance, attribute: string): number?
	local value = belt:GetAttribute(attribute)
	return if typeof(value) == "number" then value else nil
end

local function offsetOf(belt: Instance): number
	return readNumber(belt, BoltStationConfig.CLOCK_OFFSET_ATTRIBUTE) or 0
end

function ConveyorClock.isPaused(belt: Instance): boolean
	return readNumber(belt, BoltStationConfig.CLOCK_PAUSED_AT_ATTRIBUTE) ~= nil
end

function ConveyorClock.now(belt: Instance): number
	local reference = readNumber(belt, BoltStationConfig.CLOCK_PAUSED_AT_ATTRIBUTE) or Workspace:GetServerTimeNow()
	return reference - offsetOf(belt)
end

function ConveyorClock.pause(belt: Instance)
	if not ConveyorClock.isPaused(belt) then
		belt:SetAttribute(BoltStationConfig.CLOCK_PAUSED_AT_ATTRIBUTE, Workspace:GetServerTimeNow())
	end
end

function ConveyorClock.resume(belt: Instance)
	local pausedAt = readNumber(belt, BoltStationConfig.CLOCK_PAUSED_AT_ATTRIBUTE)
	if pausedAt then
		belt:SetAttribute(BoltStationConfig.CLOCK_OFFSET_ATTRIBUTE, offsetOf(belt) + Workspace:GetServerTimeNow() - pausedAt)
		belt:SetAttribute(BoltStationConfig.CLOCK_PAUSED_AT_ATTRIBUTE, nil)
	end
end

return ConveyorClock
