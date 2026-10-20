local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAttributes = require(ReplicatedStorage.Shared.PlayerAttributes)

local concludedEvent = Instance.new("BindableEvent")

local Ending = {
	concluded = concludedEvent.Event,
}

function Ending.conclude(endingId: string)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(PlayerAttributes.ENDING) == nil then
			player:SetAttribute(PlayerAttributes.ENDING, endingId)
			concludedEvent:Fire(player)
		end
	end
end

return Ending
