local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EyePryConfig = require(Shared:WaitForChild("EyePryConfig"))
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))
local WallEyeConfig = require(Shared:WaitForChild("WallEyeConfig"))
local WallEyeWorld = require(Shared:WaitForChild("WallEyeWorld"))
local CrowbarPry = require(script.Parent:WaitForChild("CrowbarPry"))
local PrimaryAction = require(script.Parent:WaitForChild("PrimaryAction"))
local ToolViewmodel = require(script.Parent:WaitForChild("ToolViewmodel"))
local WallEyeView = require(script.Parent:WaitForChild("WallEyeView"))

local SIGHT_TOLERANCE = 0.1

local EyePryInteraction = {}

local player = Players.LocalPlayer

local function canPry(): boolean
	return player:GetAttribute(PlayerAttributes.EQUIPPED_TOOL) == ShopCatalog.CROWBAR_ITEM_ID
		and player:GetAttribute(PlayerAttributes.CAPTURED) ~= true
		and not ToolViewmodel.isActing()
end

local function isPlucked(model: Instance): boolean
	return model:GetAttribute(WallEyeConfig.PLUCKED_ATTRIBUTE) == true
end

local function isIntact(model: Instance): boolean
	return model:GetAttribute(WallEyeConfig.AWAKE_ATTRIBUTE) == true and not isPlucked(model)
end

local function distanceToSphere(origin: Vector3, direction: Vector3, center: Vector3, radius: number): number?
	local offset = center - origin
	local along = offset:Dot(direction)
	local missSquared = offset:Dot(offset) - along * along
	if along <= 0 or missSquared > radius * radius then
		return nil
	end
	return along - math.sqrt(radius * radius - missSquared)
end

local function isUnobstructed(camera: Camera, distance: number, model: Instance): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored: { Instance } = { camera, model }
	if player.Character then
		table.insert(ignored, player.Character)
	end
	params.FilterDescendantsInstances = ignored
	local reach = math.max(distance - SIGHT_TOLERANCE, 0)
	return Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * reach, params) == nil
end

local function findAimedEye(camera: Camera): (Instance?, BasePart?)
	local origin, direction = camera.CFrame.Position, camera.CFrame.LookVector
	local aimedModel: Instance?, aimedSclera: BasePart? = nil, nil
	local nearestDistance = EyePryConfig.AIM_DISTANCE
	for _, model in CollectionService:GetTagged(WallEyeConfig.TAG) do
		local sclera = if isIntact(model) then WallEyeWorld.findSclera(model) else nil
		local distance = sclera and distanceToSphere(origin, direction, sclera.Position, WallEyeConfig.EYE_RADIUS)
		if distance and distance < nearestDistance and isUnobstructed(camera, distance, model) then
			aimedModel, aimedSclera, nearestDistance = model, sclera, distance
		end
	end
	return aimedModel, aimedSclera
end

local function onPrimaryAction()
	if not canPry() then
		return
	end
	local camera = Workspace.CurrentCamera
	local model, sclera = findAimedEye(camera)
	local socket = model and WallEyeWorld.findSocket(model)
	if not model or not sclera or not socket then
		return
	end
	Remotes.PryEye:FireServer(model)
	local pry = CrowbarPry.new(sclera.Position, socket.CFrame.LookVector, camera.CFrame)
	local startedAt = os.clock()
	ToolViewmodel.playAction(function(hold: CFrame, holdScale: number, elapsed: number)
		return CrowbarPry.toolPose(pry, hold, holdScale, elapsed, isPlucked(model))
	end)
	WallEyeView.displaceEye(model, function(): Vector3?
		return CrowbarPry.eyeOffset(pry, os.clock() - startedAt, isPlucked(model))
	end)
end

function EyePryInteraction.start()
	PrimaryAction.triggered:Connect(onPrimaryAction)
end

return EyePryInteraction
