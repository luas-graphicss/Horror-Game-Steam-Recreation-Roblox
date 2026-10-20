local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local UpgradeEffects = require(ReplicatedStorage.Shared.UpgradeEffects)
local PlayerData = require(script.Parent.PlayerData)

local HarvestYield = {}

local random = Random.new()

function HarvestYield.roll(player: Player, baseAmount: number): number
	local heartLevel = PlayerData.upgradeLevel(player, ShopCatalog.HEART_ITEM_ID)
	local exactAmount = baseAmount * UpgradeEffects.harvestMultiplier(heartLevel)
	local wholeAmount = math.floor(exactAmount)
	return if random:NextNumber() < exactAmount - wholeAmount then wholeAmount + 1 else wholeAmount
end

return HarvestYield
