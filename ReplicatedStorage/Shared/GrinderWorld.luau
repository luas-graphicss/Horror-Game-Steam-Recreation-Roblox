local Workspace = game:GetService("Workspace")

local MAP_NAME = "MetalBox"
local SECTOR_NAME = "SectorTwo"
local PROPS_NAME = "Props"
local GRINDER_NAME = "Grinder"
local INTAKE_NAME = "Intake"
local SPOUT_HOLDER_NAME = "ChuteSteel"
local SPOUT_NAME = "GoreSpout"
local POOL_NAME = "GorePool"
local POOL_SURFACE_NAME = "PoolSurface"
local POOL_IMAGE_NAME = "BloodPool"

local GrinderWorld = {}

function GrinderWorld.resolve(): Model
	local props = Workspace:WaitForChild(MAP_NAME):WaitForChild(SECTOR_NAME):WaitForChild(PROPS_NAME)
	return props:WaitForChild(GRINDER_NAME) :: Model
end

function GrinderWorld.intake(grinder: Model): BasePart
	return grinder:WaitForChild(INTAKE_NAME) :: BasePart
end

function GrinderWorld.findIntake(grinder: Model): BasePart?
	local intake = grinder:FindFirstChild(INTAKE_NAME)
	return if intake and intake:IsA("BasePart") then intake else nil
end

function GrinderWorld.findSpout(grinder: Model): Attachment?
	local holder = grinder:FindFirstChild(SPOUT_HOLDER_NAME)
	local spout = holder and holder:FindFirstChild(SPOUT_NAME)
	return if spout and spout:IsA("Attachment") then spout else nil
end

function GrinderWorld.findPoolImage(grinder: Model): ImageLabel?
	local pool = grinder:FindFirstChild(POOL_NAME)
	local surface = pool and pool:FindFirstChild(POOL_SURFACE_NAME)
	local image = surface and surface:FindFirstChild(POOL_IMAGE_NAME)
	return if image and image:IsA("ImageLabel") then image else nil
end

return GrinderWorld
