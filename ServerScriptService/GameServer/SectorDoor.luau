local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SectorDoorConfig = require(ReplicatedStorage.Shared.SectorDoorConfig)
local SectorDoorWorld = require(ReplicatedStorage.Shared.SectorDoorWorld)
local PlayerData = require(script.Parent.PlayerData)
local PlayerReach = require(script.Parent.PlayerReach)
local RemoteThrottle = require(script.Parent.RemoteThrottle)

local OPEN_RANGE = 16
local OPEN_REQUESTS_PER_SECOND = 2
local RESTORED_OPEN_AGE = 3600

local SectorDoor = {}

local world: SectorDoorWorld.Instances

local function isInState(state: string): boolean
	return world.door:GetAttribute(SectorDoorConfig.STATE_ATTRIBUTE) == state
end

local function settleLeavesOpen()
	for _, leaf in world.leaves do
		leaf.part.CFrame *= CFrame.new(leaf.slideDirection * SectorDoorConfig.LEAF_SLIDE_DISTANCE)
	end
end

local function open()
	world.door:SetAttribute(SectorDoorConfig.OPENED_AT_ATTRIBUTE, Workspace:GetServerTimeNow())
	world.door:SetAttribute(SectorDoorConfig.STATE_ATTRIBUTE, SectorDoorConfig.OPEN_STATE)
	task.delay(SectorDoorConfig.OPENING_DURATION, settleLeavesOpen)
end

local function onOpenRequested(player: Player)
	if not isInState(SectorDoorConfig.UNLOCKED_STATE) then
		return
	end
	if not PlayerReach.isWithin(player, world.leafGroup:GetPivot().Position, OPEN_RANGE) then
		return
	end
	if not PlayerData.trySpend(player, SectorDoorConfig.PRICE_CENTS) then
		return
	end
	open()
end

function SectorDoor.unlock()
	if isInState(SectorDoorConfig.LOCKED_STATE) then
		world.door:SetAttribute(SectorDoorConfig.STATE_ATTRIBUTE, SectorDoorConfig.UNLOCKED_STATE)
	end
end

function SectorDoor.state(): string
	return world.door:GetAttribute(SectorDoorConfig.STATE_ATTRIBUTE) :: string
end

function SectorDoor.restore(state: string)
	if state == SectorDoorConfig.UNLOCKED_STATE then
		SectorDoor.unlock()
	elseif state == SectorDoorConfig.OPEN_STATE and not isInState(SectorDoorConfig.OPEN_STATE) then
		world.door:SetAttribute(SectorDoorConfig.OPENED_AT_ATTRIBUTE, Workspace:GetServerTimeNow() - RESTORED_OPEN_AGE)
		world.door:SetAttribute(SectorDoorConfig.STATE_ATTRIBUTE, SectorDoorConfig.OPEN_STATE)
		settleLeavesOpen()
	end
end

function SectorDoor.start()
	world = SectorDoorWorld.resolve()
	world.door:SetAttribute(SectorDoorConfig.STATE_ATTRIBUTE, SectorDoorConfig.LOCKED_STATE)
	RemoteThrottle.connect(Remotes.OpenSectorDoor, OPEN_REQUESTS_PER_SECOND, onOpenRequested)
end

return SectorDoor
