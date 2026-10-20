local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoltStationConfig = require(ReplicatedStorage.Shared.BoltStationConfig)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local UpgradeEffects = require(ReplicatedStorage.Shared.UpgradeEffects)
local PlayerData = require(script.Parent.PlayerData)

local COMMON_PAYOUT_MIN_CENTS = 70
local COMMON_PAYOUT_MAX_CENTS = 80
local RARE_PAYOUT_MIN_CENTS = 350
local RARE_PAYOUT_MAX_CENTS = 400

local BoltValue = {}

local random = Random.new()

function BoltValue.rollRare(): boolean
	local chance = UpgradeEffects.rareBoltChance(PlayerData.highestUpgradeLevel(ShopCatalog.BOLT_ITEM_ID))
	return random:NextNumber() < chance
end

function BoltValue.isRare(bolt: Model): boolean
	return bolt:GetAttribute(BoltStationConfig.RARE_ATTRIBUTE) == true
end

function BoltValue.payoutCents(player: Player, bolt: Model): number
	local baseCents = if BoltValue.isRare(bolt)
		then random:NextInteger(RARE_PAYOUT_MIN_CENTS, RARE_PAYOUT_MAX_CENTS)
		else random:NextInteger(COMMON_PAYOUT_MIN_CENTS, COMMON_PAYOUT_MAX_CENTS)
	local multiplier = UpgradeEffects.payoutMultiplier(PlayerData.upgradeLevel(player, ShopCatalog.LOOSE_NUT_ITEM_ID))
	return math.round(baseCents * multiplier)
end

return BoltValue
