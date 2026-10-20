local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WallEyeConfig = require(ReplicatedStorage.Shared.WallEyeConfig)

local MAP_NAME = "MetalBox"
local SHELL_NAME = "Shell"
local WALLS_NAME = "Walls"
local TRIM_NAME = "Trim"
local SOCKET_NAME = "Socket"
local MIN_HEIGHT_ABOVE_FLOOR = 7
local MAX_HEIGHT_ABOVE_FLOOR = 13.5
local NEST_HALF_WIDTH = 4.5
local NEST_HALF_HEIGHT = 4.5
local NEST_DEPTH = 3
local OBSTACLE_CLEARANCE = 1
local SURFACE_GAP = 0.05
local WALL_PROBE_DISTANCE = 1
local MIN_EYE_SPACING = 10
local MAX_WALL_NORMAL_TILT = 0.1
local MAX_ATTEMPTS = 40

type WallFace = {
	wall: BasePart,
	center: Vector3,
	normal: Vector3,
	along: Vector3,
	halfLength: number,
	bottom: number,
	top: number,
}

type SpawnArea = {
	face: WallFace,
	lowest: number,
	highest: number,
	halfSpan: number,
}

local WallEyeSpawnSpot = {}

local function extentAlong(part: BasePart, direction: Vector3): number
	local cframe, half = part.CFrame, part.Size / 2
	return math.abs(cframe.RightVector:Dot(direction)) * half.X
		+ math.abs(cframe.UpVector:Dot(direction)) * half.Y
		+ math.abs(cframe.LookVector:Dot(direction)) * half.Z
end

local function thinnestAxis(part: BasePart): (Vector3, number)
	local size = part.Size
	if size.X <= size.Y and size.X <= size.Z then
		return part.CFrame.RightVector, size.X
	elseif size.Y <= size.Z then
		return part.CFrame.UpVector, size.Y
	end
	return part.CFrame.LookVector, size.Z
end

local function faceOf(wall: BasePart, roomCenter: Vector3): WallFace?
	local axis, thickness = thinnestAxis(wall)
	local normal = if axis:Dot(roomCenter - wall.Position) >= 0 then axis else -axis
	if math.abs(normal.Y) > MAX_WALL_NORMAL_TILT then
		return nil
	end
	local along = Vector3.yAxis:Cross(normal).Unit
	local halfHeight = extentAlong(wall, Vector3.yAxis)
	return {
		wall = wall,
		center = wall.Position + normal * (thickness / 2),
		normal = normal,
		along = along,
		halfLength = extentAlong(wall, along),
		bottom = wall.Position.Y - halfHeight,
		top = wall.Position.Y + halfHeight,
	}
end

local function collectFaces(walls: Instance, roomCenter: Vector3): { WallFace }
	local faces = {}
	for _, wall in walls:GetChildren() do
		local face = if wall:IsA("BasePart") then faceOf(wall, roomCenter) else nil
		if face then
			table.insert(faces, face)
		end
	end
	return faces
end

local function collectAreas(faces: { WallFace }): ({ SpawnArea }, number)
	local floorHeight = math.huge
	for _, face in faces do
		floorHeight = math.min(floorHeight, face.bottom)
	end
	local areas = {}
	local totalSpan = 0
	for _, face in faces do
		local lowest = math.max(floorHeight + MIN_HEIGHT_ABOVE_FLOOR, face.bottom + NEST_HALF_HEIGHT)
		local highest = math.min(floorHeight + MAX_HEIGHT_ABOVE_FLOOR, face.top - NEST_HALF_HEIGHT)
		local halfSpan = face.halfLength - NEST_HALF_WIDTH
		if highest >= lowest and halfSpan > 0 then
			table.insert(areas, { face = face, lowest = lowest, highest = highest, halfSpan = halfSpan })
			totalSpan += halfSpan
		end
	end
	return areas, totalSpan
end

local function pickArea(areas: { SpawnArea }, totalSpan: number, random: Random): SpawnArea
	local roll = random:NextNumber(0, totalSpan)
	for _, area in areas do
		roll -= area.halfSpan
		if roll <= 0 then
			return area
		end
	end
	return areas[#areas]
end

local function pointIn(area: SpawnArea, random: Random): Vector3
	local face = area.face
	local onFace = face.center + face.along * random:NextNumber(-area.halfSpan, area.halfSpan)
	return Vector3.new(onFace.X, random:NextNumber(area.lowest, area.highest), onFace.Z)
end

local function isFarFromOtherEyes(position: Vector3): boolean
	for _, eye in CollectionService:GetTagged(WallEyeConfig.TAG) do
		local socket = eye:FindFirstChild(SOCKET_NAME)
		if socket and socket:IsA("BasePart") and (socket.Position - position).Magnitude < MIN_EYE_SPACING then
			return false
		end
	end
	return true
end

local function isWallBehind(face: WallFace, position: Vector3): boolean
	local probeParams = RaycastParams.new()
	probeParams.FilterType = Enum.RaycastFilterType.Include
	probeParams.FilterDescendantsInstances = { face.wall }
	local origin = position + face.normal * WALL_PROBE_DISTANCE
	return Workspace:Raycast(origin, -face.normal * WALL_PROBE_DISTANCE * 2, probeParams) ~= nil
end

local function isClearOfObstacles(face: WallFace, position: Vector3, overlapParams: OverlapParams): boolean
	local depth = NEST_DEPTH + OBSTACLE_CLEARANCE
	local center = position + face.normal * (SURFACE_GAP + depth / 2)
	local size = Vector3.new((NEST_HALF_WIDTH + OBSTACLE_CLEARANCE) * 2, (NEST_HALF_HEIGHT + OBSTACLE_CLEARANCE) * 2, depth)
	local box = CFrame.lookAt(center, center + face.normal, Vector3.yAxis)
	return #Workspace:GetPartBoundsInBox(box, size, overlapParams) == 0
end

function WallEyeSpawnSpot.find(random: Random): CFrame?
	local shell = Workspace:WaitForChild(MAP_NAME):WaitForChild(SHELL_NAME)
	local walls = shell:WaitForChild(WALLS_NAME)
	local areas, totalSpan = collectAreas(collectFaces(walls, shell:GetBoundingBox().Position))
	if #areas == 0 then
		return nil
	end
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { walls, shell:WaitForChild(TRIM_NAME) }
	overlapParams.RespectCanCollide = false
	for _ = 1, MAX_ATTEMPTS do
		local area = pickArea(areas, totalSpan, random)
		local position = pointIn(area, random)
		if isFarFromOtherEyes(position) and isWallBehind(area.face, position) and isClearOfObstacles(area.face, position, overlapParams) then
			return CFrame.lookAt(position, position + area.face.normal, Vector3.yAxis)
		end
	end
	return nil
end

return WallEyeSpawnSpot
