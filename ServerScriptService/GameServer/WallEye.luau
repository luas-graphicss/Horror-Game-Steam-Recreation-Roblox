local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerAttributes = require(ReplicatedStorage.Shared.PlayerAttributes)
local WallEyeConfig = require(ReplicatedStorage.Shared.WallEyeConfig)
local WallEyeWorld = require(ReplicatedStorage.Shared.WallEyeWorld)
local PlayerCapture = require(script.Parent.PlayerCapture)
local WallEyeHunter = require(script.Parent.WallEyeHunter)
local WorkActivity = require(script.Parent.WorkActivity)

local HEAD_NAME = "Head"

local firstSeenEvent = Instance.new("BindableEvent")

local WallEye = {
	firstSeen = firstSeenEvent.Event,
}

local castParams = RaycastParams.new()
local hunters: { [Model]: WallEyeHunter.Hunter } = {}
local roomVolume: BasePart? = nil
local isAwake = false
local hasBeenSeen = false

local function isInside(volume: BasePart, position: Vector3): boolean
	local offset = volume.CFrame:PointToObjectSpace(position)
	local half = volume.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

local function collectCandidates(volume: BasePart): { WallEyeHunter.Candidate }
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local head = character and character:FindFirstChild(HEAD_NAME)
		local rootPart = humanoid and humanoid.RootPart
		if
			character
			and humanoid
			and humanoid.Health > 0
			and rootPart
			and head
			and head:IsA("BasePart")
			and not PlayerCapture.isCaptured(player)
			and player:GetAttribute(PlayerAttributes.ON_SHIFT) == true
			and isInside(volume, rootPart.Position)
		then
			table.insert(candidates, { player = player, character = character, head = head, rootPart = rootPart })
		end
	end
	return candidates
end

local function refreshCastFilter(candidates: { WallEyeHunter.Candidate })
	local ignored: { Instance } = {}
	for model in hunters do
		table.insert(ignored, model)
	end
	for _, candidate in candidates do
		table.insert(ignored, candidate.character)
	end
	castParams.FilterDescendantsInstances = ignored
end

local function isAnyoneWorking(candidates: { WallEyeHunter.Candidate }): boolean
	for _, candidate in candidates do
		if WorkActivity.isWorking(candidate.player) then
			return true
		end
	end
	return false
end

local function noticeFirstSighting(hunter: WallEyeHunter.Hunter)
	if not hasBeenSeen and WallEyeHunter.isWatched(hunter) then
		hasBeenSeen = true
		firstSeenEvent:Fire()
	end
end

local function onHeartbeat(dt: number)
	local volume = roomVolume
	if not isAwake or not volume then
		return
	end
	local now = os.clock()
	local candidates = collectCandidates(volume)
	refreshCastFilter(candidates)
	local someoneIsWorking = isAnyoneWorking(candidates)
	for _, hunter in hunters do
		WallEyeHunter.update(hunter, candidates, someoneIsWorking, dt, now)
		noticeFirstSighting(hunter)
	end
end

local function register(instance: Instance): WallEyeHunter.Hunter?
	if not instance:IsA("Model") then
		return nil
	end
	local existing = hunters[instance]
	if existing then
		return existing
	end
	local world = WallEyeWorld.resolve(instance)
	instance:SetAttribute(WallEyeConfig.AWAKE_ATTRIBUTE, isAwake)
	local hunter = WallEyeHunter.new(world, castParams)
	hunters[instance] = hunter
	roomVolume = roomVolume or world.roamVolume
	return hunter
end

function WallEye.eyePosition(model: Model): Vector3?
	local hunter = hunters[model]
	return if hunter then hunter.eyePosition else nil
end

function WallEye.pin(model: Model): boolean
	local hunter = hunters[model]
	return isAwake and hunter ~= nil and WallEyeHunter.pin(hunter)
end

function WallEye.pluck(model: Model)
	local hunter = register(model)
	if hunter then
		WallEyeHunter.pluck(hunter)
		model:SetAttribute(WallEyeConfig.PLUCKED_ATTRIBUTE, true)
	end
end

function WallEye.awaken()
	isAwake = true
	for model in hunters do
		model:SetAttribute(WallEyeConfig.AWAKE_ATTRIBUTE, true)
	end
end

function WallEye.start()
	castParams.FilterType = Enum.RaycastFilterType.Exclude
	castParams.RespectCanCollide = true
	CollectionService:GetInstanceAddedSignal(WallEyeConfig.TAG):Connect(register)
	for _, model in CollectionService:GetTagged(WallEyeConfig.TAG) do
		register(model)
	end
	RunService.Heartbeat:Connect(onHeartbeat)
end

return WallEye
