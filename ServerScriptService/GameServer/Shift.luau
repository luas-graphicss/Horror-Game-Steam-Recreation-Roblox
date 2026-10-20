local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAttributes = require(ReplicatedStorage.Shared.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SaveStatus = require(ReplicatedStorage.Shared.SaveStatus)
local RemoteThrottle = require(script.Parent.RemoteThrottle)
local Storyline = require(script.Parent.Storyline)

local BEGIN_REQUESTS_PER_SECOND = 1

local Shift = {}

local function onBeginRequested(player: Player)
	if player:GetAttribute(PlayerAttributes.ON_SHIFT) == true then
		return
	end
	if not SaveStatus.isReady(player:GetAttribute(PlayerAttributes.SAVE_STATUS)) then
		return
	end
	player:SetAttribute(PlayerAttributes.ON_SHIFT, true)
	Storyline.begin()
end

function Shift.start()
	RemoteThrottle.connect(Remotes.BeginShift, BEGIN_REQUESTS_PER_SECOND, onBeginRequested)
end

return Shift
