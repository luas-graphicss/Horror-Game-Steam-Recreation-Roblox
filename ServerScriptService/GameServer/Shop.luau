local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local ToolCatalog = require(ReplicatedStorage.Shared.ToolCatalog)
local PlayerData = require(script.Parent.PlayerData)
local PlayerReach = require(script.Parent.PlayerReach)
local RemoteThrottle = require(script.Parent.RemoteThrottle)
local ToolBelt = require(script.Parent.ToolBelt)

local PURCHASE_RANGE = 14
local PURCHASE_REQUESTS_PER_SECOND = 10

local Shop = {}

local function findDisplay(itemId: string): Instance?
	for _, display in CollectionService:GetTagged(ShopCatalog.TAG) do
		if display:GetAttribute(ShopCatalog.ITEM_ID_ATTRIBUTE) == itemId then
			return display
		end
	end
	return nil
end

local function displayPosition(display: Instance): Vector3?
	if display:IsA("Model") then
		return display:GetPivot().Position
	elseif display:IsA("BasePart") then
		return display.Position
	end
	return nil
end

local function isWithinReach(player: Player, itemId: string): boolean
	local display = findDisplay(itemId)
	local position = display and displayPosition(display)
	return position ~= nil and PlayerReach.isWithin(player, position, PURCHASE_RANGE)
end

local function nextPurchaseStage(player: Player, itemId: string, item: ShopCatalog.Item): number
	return ShopCatalog.nextPurchaseStage(item, PlayerData.ownsItem(player, itemId), PlayerData.upgradeLevel(player, itemId))
end

local function onPurchaseRequested(player: Player, itemId: unknown, stage: unknown)
	if typeof(itemId) ~= "string" or typeof(stage) ~= "number" then
		return
	end
	local item = ShopCatalog.ITEMS[itemId]
	if not item or stage ~= nextPurchaseStage(player, itemId, item) then
		return
	end
	local priceCents = ShopCatalog.priceAtStage(item, stage)
	local bloodCost = ShopCatalog.bloodCostAtStage(item, stage)
	if not priceCents or not isWithinReach(player, itemId) or not PlayerData.trySpend(player, priceCents, bloodCost) then
		return
	end
	if stage == ShopCatalog.BASE_PURCHASE_STAGE then
		PlayerData.grantItem(player, itemId)
		if ToolCatalog.isTool(itemId) then
			ToolBelt.equip(player, itemId)
		end
	else
		PlayerData.grantUpgrade(player, itemId)
	end
end

function Shop.start()
	RemoteThrottle.connect(Remotes.PurchaseItem, PURCHASE_REQUESTS_PER_SECOND, onPurchaseRequested)
end

return Shop
