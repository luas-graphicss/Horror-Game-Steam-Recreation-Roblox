local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local GrabConfig = require(ReplicatedStorage.Shared.GrabConfig)
local WallEyeConfig = require(ReplicatedStorage.Shared.WallEyeConfig)
local WallEyeWorld = require(ReplicatedStorage.Shared.WallEyeWorld)

local PREFAB_NAME = "LooseEye"
local CONTAINER_NAME = "LooseEyes"

local LooseEyes = {}

local prefab = ServerStorage:WaitForChild(PREFAB_NAME) :: Model
local container = Workspace:WaitForChild(CONTAINER_NAME)

local function weldVisuals(eye: Model, collider: BasePart)
	for _, part in eye:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = collider
		weld.Part1 = part
		weld.Parent = part
	end
end

local function bodyOffset(source: WallEyeWorld.EyeParts): CFrame
	return source.eye:GetPivot():ToObjectSpace(source.sclera.CFrame)
end

local function createBody(source: WallEyeWorld.EyeParts, eyeCFrame: CFrame, holderUserId: number): BasePart
	local body = prefab:Clone()
	local collider = body.PrimaryPart :: BasePart
	local eye = source.eye:Clone()
	eye:PivotTo(eyeCFrame)
	body:PivotTo(eyeCFrame * bodyOffset(source))
	weldVisuals(eye, collider)
	eye.Parent = body
	body:SetAttribute(GrabConfig.LAST_HOLDER_ATTRIBUTE, holderUserId)
	body.Parent = container
	collider:SetNetworkOwner(nil)
	return collider
end

function LooseEyes.spawn(source: WallEyeWorld.EyeParts, eyeCFrame: CFrame, velocity: Vector3, spin: Vector3, plucker: Player)
	local collider = createBody(source, eyeCFrame, plucker.UserId)
	collider.AssemblyLinearVelocity = velocity
	collider.AssemblyAngularVelocity = spin
end

function LooseEyes.pivots(): { CFrame }
	local pivots = {}
	for _, body in container:GetChildren() do
		if body:IsA("Model") then
			table.insert(pivots, body:GetPivot())
		end
	end
	return pivots
end

function LooseEyes.restore(pivots: { CFrame }, holder: Player)
	local template = CollectionService:GetTagged(WallEyeConfig.TAG)[1]
	if #pivots == 0 or not template then
		return
	end
	local source = WallEyeWorld.resolveEye(template)
	local toEye = bodyOffset(source):Inverse()
	for _, pivot in pivots do
		createBody(source, pivot * toEye, holder.UserId)
	end
end

return LooseEyes
