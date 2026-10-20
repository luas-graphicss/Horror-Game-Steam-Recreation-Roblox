local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))
local UpgradeEffects = require(Shared:WaitForChild("UpgradeEffects"))
local CameraTremor = require(script.Parent:WaitForChild("CameraTremor"))
local ToolViewmodel = require(script.Parent:WaitForChild("ToolViewmodel"))

local MAX_SWING_DURATION = 0.3
local SHAKE_STRENGTH = 1

local HammerSwing = {}

local player = Players.LocalPlayer
local nextSwingAt = -math.huge

local function hammerLevel(): number
	local level = player:GetAttribute(PlayerAttributes.upgradeLevel(ShopCatalog.HAMMER_ITEM_ID))
	return if typeof(level) == "number" then level else 0
end

function HammerSwing.isReady(): boolean
	return os.clock() >= nextSwingAt and player:GetAttribute(PlayerAttributes.EQUIPPED_TOOL) == ShopCatalog.HAMMER_ITEM_ID
end

function HammerSwing.swing()
	local strikeInterval = UpgradeEffects.strikeInterval(hammerLevel())
	local swingDuration = math.min(strikeInterval, MAX_SWING_DURATION)
	nextSwingAt = os.clock() + strikeInterval
	ToolViewmodel.playSwing(swingDuration)
	task.delay(swingDuration / 2, CameraTremor.shake, SHAKE_STRENGTH)
end

return HammerSwing
