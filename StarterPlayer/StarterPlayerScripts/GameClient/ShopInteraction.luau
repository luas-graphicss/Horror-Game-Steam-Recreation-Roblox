local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Money = require(Shared:WaitForChild("Money"))
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))
local AimTarget = require(script.Parent:WaitForChild("AimTarget"))
local InteractionPrompt = require(script.Parent:WaitForChild("InteractionPrompt"))
local PrimaryAction = require(script.Parent:WaitForChild("PrimaryAction"))
local UpgradeValueText = require(script.Parent:WaitForChild("UpgradeValueText"))

local PURCHASE_SOUND_NAME = "PurchaseSound"
local RENDER_STEP_NAME = "ShopInteraction"
local FREE_PRICE_TEXT = "Click to buy"
local PRICE_TEXT_FORMAT = "Click to buy: %sR$"
local BLOOD_COST_FORMAT = "%s + %d sangue"
local MAX_LEVEL_TEXT = "Max level"
local OWNED_TEXT = "Owned"

local ShopInteraction = {}

local player = Players.LocalPlayer
local focusedDisplay: Instance? = nil

local function itemIdOf(display: Instance): string?
	local itemId = display:GetAttribute(ShopCatalog.ITEM_ID_ATTRIBUTE)
	return if typeof(itemId) == "string" then itemId else nil
end

local function owns(itemId: string): boolean
	return player:GetAttribute(PlayerAttributes.ownedItem(itemId)) == true
end

local function balanceCents(): number
	local balance = player:GetAttribute(PlayerAttributes.BALANCE_CENTS)
	return if typeof(balance) == "number" then balance else 0
end

local function bloodStock(): number
	local blood = player:GetAttribute(PlayerAttributes.BLOOD)
	return if typeof(blood) == "number" then blood else 0
end

local function upgradeLevelOf(itemId: string): number
	local level = player:GetAttribute(PlayerAttributes.upgradeLevel(itemId))
	return if typeof(level) == "number" then level else 0
end

local function nextPurchaseStageOf(itemId: string, item: ShopCatalog.Item): number
	return ShopCatalog.nextPurchaseStage(item, owns(itemId), upgradeLevelOf(itemId))
end

local function priceText(priceCents: number, bloodCost: number): string
	if priceCents == 0 then
		return FREE_PRICE_TEXT
	end
	local moneyText = string.format(PRICE_TEXT_FORMAT, Money.format(priceCents))
	return if bloodCost > 0 then string.format(BLOOD_COST_FORMAT, moneyText, bloodCost) else moneyText
end

local function upgradeLineOf(item: ShopCatalog.Item, fromLevel: number, toLevel: number): InteractionPrompt.Upgrade
	local valueKind = (item.upgrade :: ShopCatalog.UpgradeTrack).valueKind
	return {
		from = UpgradeValueText.format(valueKind, ShopCatalog.upgradeValueAt(item, fromLevel)),
		to = UpgradeValueText.format(valueKind, ShopCatalog.upgradeValueAt(item, toLevel)),
	}
end

local function offerOf(itemId: string): InteractionPrompt.Content?
	local item = ShopCatalog.ITEMS[itemId]
	if not item then
		return nil
	end
	local stage = nextPurchaseStageOf(itemId, item)
	local priceCents = ShopCatalog.priceAtStage(item, stage)
	if not priceCents then
		return {
			title = item.displayName,
			description = item.description,
			action = if item.upgrade then MAX_LEVEL_TEXT else OWNED_TEXT,
		}
	end
	local bloodCost = ShopCatalog.bloodCostAtStage(item, stage)
	local isUpgrade = stage ~= ShopCatalog.BASE_PURCHASE_STAGE
	return {
		title = item.displayName,
		description = item.description,
		upgrade = if isUpgrade then upgradeLineOf(item, stage - 1, stage) else nil,
		action = priceText(priceCents, bloodCost),
		isActionUnavailable = balanceCents() < priceCents or bloodStock() < bloodCost,
	}
end

local function refreshPrompt()
	local display = focusedDisplay
	if not display then
		return
	end
	local itemId = itemIdOf(display)
	local offer = if itemId then offerOf(itemId) else nil
	if offer then
		InteractionPrompt.show(display, offer)
	else
		InteractionPrompt.hide(display)
	end
end

local function onRenderStep()
	local display = AimTarget.find(ShopCatalog.TAG)
	if display == focusedDisplay then
		return
	end
	if focusedDisplay then
		InteractionPrompt.hide(focusedDisplay)
	end
	focusedDisplay = display
	refreshPrompt()
end

local function onPrimaryAction()
	local itemId = focusedDisplay and itemIdOf(focusedDisplay)
	local item = itemId and ShopCatalog.ITEMS[itemId]
	if not itemId or not item then
		return
	end
	local stage = nextPurchaseStageOf(itemId, item)
	if ShopCatalog.priceAtStage(item, stage) then
		Remotes.PurchaseItem:FireServer(itemId, stage)
	end
end

local function playPurchaseSound(itemId: string)
	for _, display in CollectionService:GetTagged(ShopCatalog.TAG) do
		if itemIdOf(display) ~= itemId then
			continue
		end
		local purchaseSound = display:FindFirstChild(PURCHASE_SOUND_NAME, true)
		if purchaseSound and purchaseSound:IsA("Sound") then
			purchaseSound:Play()
		end
	end
end

local function onOwnershipChanged(itemId: string)
	if owns(itemId) then
		playPurchaseSound(itemId)
	end
	refreshPrompt()
end

local function onUpgradeLevelChanged(itemId: string)
	playPurchaseSound(itemId)
	refreshPrompt()
end

function ShopInteraction.start()
	for itemId in ShopCatalog.ITEMS do
		player:GetAttributeChangedSignal(PlayerAttributes.ownedItem(itemId)):Connect(function()
			onOwnershipChanged(itemId)
		end)
		player:GetAttributeChangedSignal(PlayerAttributes.upgradeLevel(itemId)):Connect(function()
			onUpgradeLevelChanged(itemId)
		end)
	end
	player:GetAttributeChangedSignal(PlayerAttributes.BALANCE_CENTS):Connect(refreshPrompt)
	player:GetAttributeChangedSignal(PlayerAttributes.BLOOD):Connect(refreshPrompt)
	PrimaryAction.triggered:Connect(onPrimaryAction)
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, onRenderStep)
end

return ShopInteraction
