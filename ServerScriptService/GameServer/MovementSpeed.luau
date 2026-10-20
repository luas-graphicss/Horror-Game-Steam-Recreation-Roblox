local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAttributes = require(ReplicatedStorage.Shared.PlayerAttributes)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local UpgradeEffects = require(ReplicatedStorage.Shared.UpgradeEffects)
local PlayerData = require(script.Parent.PlayerData)

local HUMANOID_NAME = "Humanoid"

local MovementSpeed = {}

local function applyWalkSpeed(player: Player, humanoid: Humanoid)
	humanoid.WalkSpeed = UpgradeEffects.walkSpeed(PlayerData.upgradeLevel(player, ShopCatalog.SODA_MACHINE_ITEM_ID))
end

local function refresh(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		applyWalkSpeed(player, humanoid)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	applyWalkSpeed(player, character:WaitForChild(HUMANOID_NAME) :: Humanoid)
end

local function track(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player:GetAttributeChangedSignal(PlayerAttributes.upgradeLevel(ShopCatalog.SODA_MACHINE_ITEM_ID)):Connect(function()
		refresh(player)
	end)
	refresh(player)
end

function MovementSpeed.start()
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
end

return MovementSpeed
