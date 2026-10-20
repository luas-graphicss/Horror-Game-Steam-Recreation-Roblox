local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CaptureConfig = require(ReplicatedStorage.Shared.CaptureConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.PlayerAttributes)

local RESPAWN_DELAY = CaptureConfig.JUMPSCARE_DURATION + CaptureConfig.FADE_OUT_DURATION

local PlayerCapture = {}

local function freeze(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = humanoid and humanoid.RootPart
	if rootPart then
		rootPart.Anchored = true
	end
end

local function respawn(player: Player)
	if player.Parent ~= Players then
		return
	end
	player:LoadCharacterAsync()
	player:SetAttribute(PlayerAttributes.CAPTURED, false)
end

function PlayerCapture.isCaptured(player: Player): boolean
	return player:GetAttribute(PlayerAttributes.CAPTURED) == true
end

function PlayerCapture.capture(player: Player)
	if PlayerCapture.isCaptured(player) then
		return
	end
	player:SetAttribute(PlayerAttributes.CAPTURED, true)
	freeze(player)
	task.delay(RESPAWN_DELAY, respawn, player)
end

return PlayerCapture
