local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SectorDoorConfig = require(ReplicatedStorage.Shared.SectorDoorConfig)
local SectorDoorWorld = require(ReplicatedStorage.Shared.SectorDoorWorld)

local MAP_NAME = "MetalBox"
local SECTOR_NAME = "SectorTwo"
local SHELL_NAME = "Shell"

local SectorAccess = {}

local door = SectorDoorWorld.resolve().door
local shell = Workspace:WaitForChild(MAP_NAME):WaitForChild(SECTOR_NAME):WaitForChild(SHELL_NAME) :: Model
local sectorCFrame, sectorSize = shell:GetBoundingBox()

local function isBehindDoor(position: Vector3): boolean
	local offset = sectorCFrame:PointToObjectSpace(position)
	local halfSize = sectorSize / 2
	return math.abs(offset.X) <= halfSize.X and math.abs(offset.Y) <= halfSize.Y and math.abs(offset.Z) <= halfSize.Z
end

local function isDoorOpen(): boolean
	return door:GetAttribute(SectorDoorConfig.STATE_ATTRIBUTE) == SectorDoorConfig.OPEN_STATE
end

function SectorAccess.isReachable(position: Vector3): boolean
	return isDoorOpen() or not isBehindDoor(position)
end

return SectorAccess
