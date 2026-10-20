local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAttributes = require(ReplicatedStorage.Shared.PlayerAttributes)
local SaveStatus = require(ReplicatedStorage.Shared.SaveStatus)
local PlayerData = require(script.Parent.PlayerData)

local settledEvent = Instance.new("BindableEvent")

local Debt = {
	settled = settledEvent.Event,
}

local function settleWhenAffordable(player: Player)
	if SaveStatus.isReady(player:GetAttribute(PlayerAttributes.SAVE_STATUS)) and PlayerData.tryPayDebt(player) then
		settledEvent:Fire(player)
	end
end

local function watch(player: Player)
	for _, attribute in { PlayerAttributes.BALANCE_CENTS, PlayerAttributes.SAVE_STATUS } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			settleWhenAffordable(player)
		end)
	end
end

function Debt.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Debt
