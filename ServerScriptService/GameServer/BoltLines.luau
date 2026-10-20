local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoltStationConfig = require(ReplicatedStorage.Shared.BoltStationConfig)
local BoltStationWorld = require(ReplicatedStorage.Shared.BoltStationWorld)
local ProductionLineConfig = require(ReplicatedStorage.Shared.ProductionLineConfig)
local ProductionLineSlots = require(ReplicatedStorage.Shared.ProductionLineSlots)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local UpgradeEffects = require(ReplicatedStorage.Shared.UpgradeEffects)
local BoltConveyor = require(script.Parent.BoltConveyor)
local BoltValue = require(script.Parent.BoltValue)
local CrankGenerator = require(script.Parent.CrankGenerator)
local PlayerData = require(script.Parent.PlayerData)

local BoltLines = {}

local conveyorsByLine: { [Instance]: BoltConveyor.Conveyor } = {}

local function processingBeltSpeed(): number
	return UpgradeEffects.processingBeltSpeed(PlayerData.highestUpgradeLevel(ShopCatalog.PROCESSING_COMPUTER_ITEM_ID))
end

local function makesBolts(line: Instance): boolean
	return line:GetAttribute(ProductionLineConfig.WORK_AREA_ATTRIBUTE) == ProductionLineConfig.BOLT_AREA
end

local function followArea(line: Instance, conveyor: BoltConveyor.Conveyor)
	if makesBolts(line) then
		BoltConveyor.activate(conveyor)
	else
		BoltConveyor.deactivate(conveyor)
	end
end

local function addLine(line: Instance)
	local conveyor = BoltConveyor.new(BoltStationWorld.fromLine(line), {
		beltSpeed = processingBeltSpeed,
		isPowered = function()
			return ProductionLineSlots.isStaffed(line) and CrankGenerator.isPowered()
		end,
	})
	conveyorsByLine[line] = conveyor
	line:GetAttributeChangedSignal(ProductionLineConfig.WORK_AREA_ATTRIBUTE):Connect(function()
		followArea(line, conveyor)
	end)
end

function BoltLines.turn(line: Instance, owner: Player)
	local conveyor = conveyorsByLine[line]
	local bolt = conveyor and BoltConveyor.restingBolt(conveyor)
	if not bolt or not CrankGenerator.isPowered() then
		return
	end
	local turns = (bolt:GetAttribute(BoltStationConfig.TURNS_ATTRIBUTE) :: number) + 1
	bolt:SetAttribute(BoltStationConfig.TURNS_ATTRIBUTE, turns)
	if turns >= BoltStationConfig.TURNS_TO_SEAT then
		PlayerData.recordTightenedBolt(owner, BoltValue.payoutCents(owner, bolt), BoltValue.isRare(bolt))
		BoltConveyor.advance(conveyor)
	end
end

function BoltLines.start()
	for _, line in CollectionService:GetTagged(ProductionLineConfig.TAG) do
		if makesBolts(line) then
			addLine(line)
		end
	end
end

return BoltLines
