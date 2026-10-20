local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local UpgradeEffects = require(ReplicatedStorage.Shared.UpgradeEffects)
local PlayerData = require(script.Parent.PlayerData)
local ToolBelt = require(script.Parent.ToolBelt)

local LATENCY_TOLERANCE = 0.3

local HammerSwings = {}

local nextSwingAt: { [Player]: number } = {}

local function forget(player: Player)
	nextSwingAt[player] = nil
end

function HammerSwings.tryConsume(player: Player): boolean
	local now = os.clock()
	if now < (nextSwingAt[player] or 0) or not ToolBelt.isEquipped(player, ShopCatalog.HAMMER_ITEM_ID) then
		return false
	end
	local strikeInterval = UpgradeEffects.strikeInterval(PlayerData.upgradeLevel(player, ShopCatalog.HAMMER_ITEM_ID))
	nextSwingAt[player] = now + strikeInterval * (1 - LATENCY_TOLERANCE)
	return true
end

function HammerSwings.start()
	Players.PlayerRemoving:Connect(forget)
end

return HammerSwings
