local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BoltStationConfig = require(ReplicatedStorage.Shared.BoltStationConfig)
local BoltStationWorld = require(ReplicatedStorage.Shared.BoltStationWorld)
local ConveyorClock = require(ReplicatedStorage.Shared.ConveyorClock)
local HeartLineConfig = require(ReplicatedStorage.Shared.HeartLineConfig)
local HeartLineRoutes = require(ReplicatedStorage.Shared.HeartLineRoutes)
local ProductionLineConfig = require(ReplicatedStorage.Shared.ProductionLineConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local UpgradeEffects = require(ReplicatedStorage.Shared.UpgradeEffects)
local CrankGenerator = require(script.Parent.CrankGenerator)
local HammerSwings = require(script.Parent.HammerSwings)
local HarvestYield = require(script.Parent.HarvestYield)
local PlayerData = require(script.Parent.PlayerData)
local PlayerReach = require(script.Parent.PlayerReach)
local RemoteThrottle = require(script.Parent.RemoteThrottle)

local STRIKE_REQUESTS_PER_SECOND = 12

type Line = {
	model: Instance,
	world: BoltStationWorld.Instances,
	heart: BasePart,
	heartOffset: CFrame,
	poolRest: CFrame,
	routes: HeartLineRoutes.Routes?,
	cycleStartsAt: number?,
}

local HeartLine = {}

local linesByModel: { [Instance]: Line } = {}
local linesByHeart: { [Instance]: Line } = {}
local heartTemplate: BasePart? = nil

local function processingBeltSpeed(): number
	return UpgradeEffects.processingBeltSpeed(PlayerData.highestUpgradeLevel(ShopCatalog.PROCESSING_COMPUTER_ITEM_ID))
end

local function bloodYield(owner: Player): number
	local redMugLevel = PlayerData.upgradeLevel(owner, ShopCatalog.RED_MUG_ITEM_ID)
	return HarvestYield.roll(owner, UpgradeEffects.bloodPerHeart(redMugLevel))
end

local function makesHearts(model: Instance): boolean
	return model:GetAttribute(ProductionLineConfig.WORK_AREA_ATTRIBUTE) == ProductionLineConfig.HEART_AREA
end

local function hitsOf(heart: BasePart): number
	local hits = heart:GetAttribute(HeartLineConfig.HITS_ATTRIBUTE)
	return if typeof(hits) == "number" then hits else 0
end

local function setBeltRunning(line: Line, isRunning: boolean)
	local belt = line.world.belt
	if belt:GetAttribute(BoltStationConfig.BELT_RUNNING_ATTRIBUTE) ~= isRunning then
		belt:SetAttribute(BoltStationConfig.BELT_RUNNING_ATTRIBUTE, isRunning)
	end
end

local function pop(line: Line, owner: Player)
	local belt = line.world.belt
	local beltSpeed = processingBeltSpeed()
	local routes = HeartLineRoutes.fromWorld(line.world, line.heartOffset, line.poolRest, beltSpeed)
	local cycleStartsAt = ConveyorClock.now(belt) + HeartLineConfig.POP_SETTLE_DURATION
	line.routes = routes
	line.cycleStartsAt = cycleStartsAt
	belt:SetAttribute(BoltStationConfig.BELT_SPEED_ATTRIBUTE, beltSpeed)
	line.model:SetAttribute(HeartLineConfig.CYCLE_STARTED_AT_ATTRIBUTE, cycleStartsAt)
	line.model:SetAttribute(HeartLineConfig.POPPED_AT_ATTRIBUTE, Workspace:GetServerTimeNow())
	line.heart:SetAttribute(HeartLineConfig.HITS_ATTRIBUTE, 0)
	line.heart.CFrame = routes.spawnPose
	PlayerData.addBlood(owner, bloodYield(owner))
end

local function settle(line: Line, routes: HeartLineRoutes.Routes)
	line.heart.CFrame = routes.restPose
	line.routes = nil
	line.cycleStartsAt = nil
	line.model:SetAttribute(HeartLineConfig.CYCLE_STARTED_AT_ATTRIBUTE, nil)
	setBeltRunning(line, false)
end

local function followPower(line: Line)
	if CrankGenerator.isPowered() then
		ConveyorClock.resume(line.world.belt)
	elseif line.cycleStartsAt then
		ConveyorClock.pause(line.world.belt)
	end
end

local function step(line: Line)
	followPower(line)
	local routes = line.routes
	local cycleStartsAt = line.cycleStartsAt
	if not routes or not cycleStartsAt then
		return
	end
	local belt = line.world.belt
	local elapsed = ConveyorClock.now(belt) - cycleStartsAt
	if elapsed >= routes.cycleDuration then
		settle(line, routes)
	else
		setBeltRunning(line, elapsed >= 0 and not ConveyorClock.isPaused(belt))
	end
end

local function onHeartbeat()
	for _, line in linesByModel do
		step(line)
	end
end

local function onStrikeRequested(player: Player, heart: unknown)
	local line = if typeof(heart) == "Instance" then linesByHeart[heart] else nil
	if not line or line.cycleStartsAt or not PlayerReach.isWithin(player, line.heart.Position, HeartLineConfig.STRIKE_REACH) then
		return
	end
	if HammerSwings.tryConsume(player) then
		HeartLine.strike(line.model, player)
	end
end

local function spawnHeart(world: BoltStationWorld.Instances): BasePart
	local heart = (heartTemplate :: BasePart):Clone()
	heart.CFrame = world.boltSlot.WorldCFrame * (heart:GetAttribute(HeartLineConfig.REST_OFFSET_ATTRIBUTE) :: CFrame)
	heart.Parent = world.boltFolder
	return heart
end

local function addLine(model: Instance)
	if linesByModel[model] then
		return
	end
	local world = BoltStationWorld.fromLine(model)
	local placedHeart = world.boltFolder:FindFirstChild(HeartLineConfig.HEART_NAME) :: BasePart?
	if placedHeart and not heartTemplate then
		heartTemplate = placedHeart:Clone()
	end
	local heart = placedHeart or spawnHeart(world)
	local line: Line = {
		model = model,
		world = world,
		heart = heart,
		heartOffset = heart:GetAttribute(HeartLineConfig.REST_OFFSET_ATTRIBUTE) :: CFrame,
		poolRest = (model:WaitForChild(HeartLineConfig.POOL_NAME) :: BasePart).CFrame,
		routes = nil,
		cycleStartsAt = nil,
	}
	heart:SetAttribute(HeartLineConfig.HITS_ATTRIBUTE, 0)
	setBeltRunning(line, false)
	linesByModel[model] = line
	linesByHeart[heart] = line
end

local function removeLine(model: Instance)
	local line = linesByModel[model]
	if not line then
		return
	end
	linesByModel[model] = nil
	linesByHeart[line.heart] = nil
	model:SetAttribute(HeartLineConfig.CYCLE_STARTED_AT_ATTRIBUTE, nil)
	setBeltRunning(line, false)
	line.heart:Destroy()
end

local function followArea(model: Instance)
	if makesHearts(model) then
		addLine(model)
	else
		removeLine(model)
	end
end

function HeartLine.strike(model: Instance, owner: Player)
	local line = linesByModel[model]
	if not line or line.cycleStartsAt or not CrankGenerator.isPowered() then
		return
	end
	local hits = hitsOf(line.heart) + 1
	if hits >= HeartLineConfig.HITS_TO_POP then
		pop(line, owner)
	else
		line.heart:SetAttribute(HeartLineConfig.HITS_ATTRIBUTE, hits)
	end
end

function HeartLine.start()
	for _, model in CollectionService:GetTagged(ProductionLineConfig.TAG) do
		followArea(model)
		model:GetAttributeChangedSignal(ProductionLineConfig.WORK_AREA_ATTRIBUTE):Connect(function()
			followArea(model)
		end)
	end
	RemoteThrottle.connect(Remotes.StrikeHeart, STRIKE_REQUESTS_PER_SECOND, onStrikeRequested)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return HeartLine
