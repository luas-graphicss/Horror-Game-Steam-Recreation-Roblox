local Workspace = game:GetService("Workspace")

local MAP_NAME = "MetalBox"
local DOOR_NAME = "ExitDoor"
local LEAF_GROUP_NAME = "Leaves"
local LEFT_LEAF_NAME = "DoorLeafLeft"
local RIGHT_LEAF_NAME = "DoorLeafRight"
local LEFT_SLIDE_DIRECTION = -Vector3.xAxis
local RIGHT_SLIDE_DIRECTION = Vector3.xAxis

export type Leaf = {
	part: BasePart,
	slideDirection: Vector3,
}

export type Instances = {
	door: Model,
	leafGroup: Model,
	leaves: { Leaf },
}

local SectorDoorWorld = {}

function SectorDoorWorld.resolve(): Instances
	local door = Workspace:WaitForChild(MAP_NAME):WaitForChild(DOOR_NAME) :: Model
	local leafGroup = door:WaitForChild(LEAF_GROUP_NAME) :: Model
	return {
		door = door,
		leafGroup = leafGroup,
		leaves = {
			{ part = leafGroup:WaitForChild(LEFT_LEAF_NAME) :: BasePart, slideDirection = LEFT_SLIDE_DIRECTION },
			{ part = leafGroup:WaitForChild(RIGHT_LEAF_NAME) :: BasePart, slideDirection = RIGHT_SLIDE_DIRECTION },
		},
	}
end

return SectorDoorWorld
