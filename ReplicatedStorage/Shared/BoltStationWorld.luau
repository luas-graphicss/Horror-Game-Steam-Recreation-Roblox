local Workspace = game:GetService("Workspace")

local ProductionLineConfig = require(script.Parent.ProductionLineConfig)

local STATION_FOLDER_NAME = "BoltStation"
local MAP_NAME = "MetalBox"
local CONVEYOR_NAME = "Conveyor"
local BELT_NAME = "ConveyorBelt"
local GEARMOTOR_NAME = "ConveyorGearmotor"
local INTAKE_TUBE_NAME = "IntakeTube"
local DISPOSAL_TUBE_NAME = "DisposalTube"
local BOLT_SLOT_NAME = "BoltSlot"
local INTAKE_LANDING_NAME = "IntakeLanding"
local INTAKE_SPAWN_NAME = "IntakeSpawn"
local DISPOSAL_MOUTH_NAME = "DisposalMouth"
local DISPOSAL_DROP_NAME = "DisposalDrop"

export type Instances = {
	boltFolder: Folder,
	belt: BasePart,
	gearmotor: BasePart,
	boltSlot: Attachment,
	intakeLanding: Attachment,
	intakeSpawn: Attachment,
	disposalMouth: Attachment,
	disposalDrop: Attachment,
}

local BoltStationWorld = {}

local function resolveIn(container: Instance, boltFolder: Folder): Instances
	local conveyor = container:WaitForChild(CONVEYOR_NAME)
	local belt = conveyor:WaitForChild(BELT_NAME) :: BasePart
	local intakeTube = container:WaitForChild(INTAKE_TUBE_NAME)
	local disposalTube = container:WaitForChild(DISPOSAL_TUBE_NAME)
	return {
		boltFolder = boltFolder,
		belt = belt,
		gearmotor = conveyor:WaitForChild(GEARMOTOR_NAME) :: BasePart,
		boltSlot = belt:WaitForChild(BOLT_SLOT_NAME) :: Attachment,
		intakeLanding = belt:WaitForChild(INTAKE_LANDING_NAME) :: Attachment,
		intakeSpawn = intakeTube:WaitForChild(INTAKE_SPAWN_NAME) :: Attachment,
		disposalMouth = disposalTube:WaitForChild(DISPOSAL_MOUTH_NAME) :: Attachment,
		disposalDrop = disposalTube:WaitForChild(DISPOSAL_DROP_NAME) :: Attachment,
	}
end

function BoltStationWorld.resolve(): Instances
	return resolveIn(Workspace:WaitForChild(MAP_NAME), Workspace:WaitForChild(STATION_FOLDER_NAME) :: Folder)
end

function BoltStationWorld.fromLine(line: Instance): Instances
	return resolveIn(line, line:WaitForChild(ProductionLineConfig.ITEMS_FOLDER_NAME) :: Folder)
end

return BoltStationWorld
