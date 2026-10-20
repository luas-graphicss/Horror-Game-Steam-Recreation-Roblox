local StarterPlayer = game:GetService("StarterPlayer")

local BoltStationConfig = require(script.Parent.BoltStationConfig)
local CrankGeneratorConfig = require(script.Parent.CrankGeneratorConfig)
local HeartLineConfig = require(script.Parent.HeartLineConfig)
local ShopCatalog = require(script.Parent.ShopCatalog)

local UpgradeEffects = {}

local function valueAt(itemId: string, level: number): number
	return ShopCatalog.upgradeValueAt(ShopCatalog.ITEMS[itemId], level)
end

function UpgradeEffects.turnInterval(wrenchLevel: number): number
	return BoltStationConfig.TURN_INTERVAL / valueAt(ShopCatalog.WRENCH_ITEM_ID, wrenchLevel)
end

function UpgradeEffects.crankTurnsPerSecond(crankLevel: number): number
	return CrankGeneratorConfig.TURNS_PER_SECOND * valueAt(ShopCatalog.CRANK_ITEM_ID, crankLevel)
end

function UpgradeEffects.energyPerTurn(gearLevel: number): number
	return CrankGeneratorConfig.ENERGY_PER_TURN * valueAt(ShopCatalog.GEAR_ITEM_ID, gearLevel)
end

function UpgradeEffects.inertiaDuration(inertiaLevel: number): number
	return valueAt(ShopCatalog.INERTIA_ITEM_ID, inertiaLevel)
end

function UpgradeEffects.fullDrainDuration(batteryLevel: number): number
	return valueAt(ShopCatalog.BATTERY_ITEM_ID, batteryLevel)
end

function UpgradeEffects.beltSpeed(computerLevel: number): number
	return BoltStationConfig.BELT_SPEED * valueAt(ShopCatalog.COMPUTER_ITEM_ID, computerLevel)
end

function UpgradeEffects.rareBoltChance(boltLevel: number): number
	return valueAt(ShopCatalog.BOLT_ITEM_ID, boltLevel)
end

function UpgradeEffects.payoutMultiplier(looseNutLevel: number): number
	return valueAt(ShopCatalog.LOOSE_NUT_ITEM_ID, looseNutLevel)
end

function UpgradeEffects.walkSpeed(sodaMachineLevel: number): number
	return StarterPlayer.CharacterWalkSpeed * valueAt(ShopCatalog.SODA_MACHINE_ITEM_ID, sodaMachineLevel)
end

function UpgradeEffects.harvestMultiplier(heartLevel: number): number
	return valueAt(ShopCatalog.HEART_ITEM_ID, heartLevel)
end

function UpgradeEffects.processingBeltSpeed(processingComputerLevel: number): number
	return BoltStationConfig.BELT_SPEED * valueAt(ShopCatalog.PROCESSING_COMPUTER_ITEM_ID, processingComputerLevel)
end

function UpgradeEffects.strikeInterval(hammerLevel: number): number
	return HeartLineConfig.STRIKE_INTERVAL / valueAt(ShopCatalog.HAMMER_ITEM_ID, hammerLevel)
end

function UpgradeEffects.bloodPerHeart(redMugLevel: number): number
	return HeartLineConfig.BLOOD_PER_HEART * valueAt(ShopCatalog.RED_MUG_ITEM_ID, redMugLevel)
end

function UpgradeEffects.employeeSpeed(staplerLevel: number): number
	return valueAt(ShopCatalog.STAPLER_ITEM_ID, staplerLevel)
end

return UpgradeEffects
