local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WallEyeConfig = require(ReplicatedStorage.Shared.WallEyeConfig)
local WallEyeWorld = require(ReplicatedStorage.Shared.WallEyeWorld)
local WallEye = require(script.Parent.WallEye)
local WallEyeSpawnSpot = require(script.Parent.WallEyeSpawnSpot)

local SECONDS_PER_MINUTE = 60
local MIN_SPAWN_INTERVAL = 12 * SECONDS_PER_MINUTE
local MAX_SPAWN_INTERVAL = 25 * SECONDS_PER_MINUTE
local SAME_EYE_DISTANCE = 0.5

export type EyeRecord = {
	pivot: CFrame,
	isPlucked: boolean,
}

local WallEyeSpawner = {}

local random = Random.new()
local hasBegun = false

local function findTemplate(): Model?
	local template = CollectionService:GetTagged(WallEyeConfig.TAG)[1]
	return if template and template:IsA("Model") then template else nil
end

local function cloneEye(template: Model, pivot: CFrame): Model
	local eye = template:Clone()
	for attribute in eye:GetAttributes() do
		eye:SetAttribute(attribute, nil)
	end
	eye:PivotTo(pivot)
	WallEyeWorld.resolve(eye).roamVolume.CFrame = WallEyeWorld.resolve(template).roamVolume.CFrame
	eye.Parent = template.Parent
	return eye
end

local function spawnEye()
	local template = findTemplate()
	local socketCFrame = WallEyeSpawnSpot.find(random)
	if not template or not socketCFrame then
		return
	end
	local socketToPivot = WallEyeWorld.resolve(template).socket.CFrame:ToObjectSpace(template:GetPivot())
	cloneEye(template, socketCFrame * socketToPivot)
end

local function runSchedule()
	while true do
		task.wait(random:NextNumber(MIN_SPAWN_INTERVAL, MAX_SPAWN_INTERVAL))
		spawnEye()
	end
end

local function eyeAt(position: Vector3): Model?
	for _, eye in CollectionService:GetTagged(WallEyeConfig.TAG) do
		if eye:IsA("Model") and (eye:GetPivot().Position - position).Magnitude <= SAME_EYE_DISTANCE then
			return eye
		end
	end
	return nil
end

function WallEyeSpawner.begin()
	if hasBegun then
		return
	end
	hasBegun = true
	task.spawn(runSchedule)
end

function WallEyeSpawner.eyes(): { EyeRecord }
	local records = {}
	for _, eye in CollectionService:GetTagged(WallEyeConfig.TAG) do
		if eye:IsA("Model") then
			table.insert(records, {
				pivot = eye:GetPivot(),
				isPlucked = eye:GetAttribute(WallEyeConfig.PLUCKED_ATTRIBUTE) == true,
			})
		end
	end
	return records
end

function WallEyeSpawner.restore(records: { EyeRecord })
	local template = findTemplate()
	if not template then
		return
	end
	for _, record in records do
		local eye = eyeAt(record.pivot.Position) or cloneEye(template, record.pivot)
		if record.isPlucked then
			WallEye.pluck(eye)
		end
	end
end

return WallEyeSpawner
