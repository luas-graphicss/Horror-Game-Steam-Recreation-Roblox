local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SectorDoorConfig = require(Shared:WaitForChild("SectorDoorConfig"))

local TAU = 2 * math.pi
local CRACK_TIME = 1.35
local SLIDE_START_TIME = 2.5
local BOUNCE_DURATION = 1.1
local SLAM_TIME = SectorDoorConfig.OPENING_DURATION - BOUNCE_DURATION
local RATTLE_AMPLITUDE = 0.035
local RATTLE_DECAY = 11
local RATTLE_FREQUENCY = 8
local CRACK_WIDTH = 0.12
local CRACK_DECAY = 9
local CRACK_FREQUENCY = 3.2
local BREAKAWAY_SHARE = 0.35
local BOUNCE_AMPLITUDE = 0.16
local BOUNCE_DECAY = 6.5
local BOUNCE_FREQUENCY = 3.4

local SectorDoorMotion = {
	CRACK_TIME = CRACK_TIME,
	SLIDE_START_TIME = SLIDE_START_TIME,
	SLAM_TIME = SLAM_TIME,
}

local slideDuration = SLAM_TIME - SLIDE_START_TIME
local cruiseScale = 1 / (1 - BREAKAWAY_SHARE / 2)

local function dampedWave(time: number, amplitude: number, decay: number, frequency: number): number
	return amplitude * math.exp(-decay * time) * math.sin(TAU * frequency * time)
end

local function travelProgress(progress: number): number
	if progress < BREAKAWAY_SHARE then
		return progress * progress / (2 * BREAKAWAY_SHARE) * cruiseScale
	end
	return (progress - BREAKAWAY_SHARE / 2) * cruiseScale
end

function SectorDoorMotion.slideAt(elapsed: number): number
	local distance = SectorDoorConfig.LEAF_SLIDE_DISTANCE
	if elapsed >= SectorDoorConfig.OPENING_DURATION then
		return distance
	elseif elapsed >= SLAM_TIME then
		return distance - math.abs(dampedWave(elapsed - SLAM_TIME, BOUNCE_AMPLITUDE, BOUNCE_DECAY, BOUNCE_FREQUENCY))
	elseif elapsed >= SLIDE_START_TIME then
		return CRACK_WIDTH + (distance - CRACK_WIDTH) * travelProgress((elapsed - SLIDE_START_TIME) / slideDuration)
	elseif elapsed >= CRACK_TIME then
		local time = elapsed - CRACK_TIME
		return CRACK_WIDTH * (1 - math.exp(-CRACK_DECAY * time) * math.cos(TAU * CRACK_FREQUENCY * time))
	elseif elapsed >= 0 then
		return math.abs(dampedWave(elapsed, RATTLE_AMPLITUDE, RATTLE_DECAY, RATTLE_FREQUENCY))
	end
	return 0
end

function SectorDoorMotion.speedFractionAt(elapsed: number): number
	if elapsed < SLIDE_START_TIME or elapsed >= SLAM_TIME then
		return 0
	end
	return math.min((elapsed - SLIDE_START_TIME) / slideDuration / BREAKAWAY_SHARE, 1)
end

return SectorDoorMotion
