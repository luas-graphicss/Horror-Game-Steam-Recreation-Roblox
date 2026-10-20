local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmployeeConfig = require(Shared:WaitForChild("EmployeeConfig"))

local STRIKE_SOUND_NAME = "StrikeSound"
local MIN_STRIKE_PITCH = 0.9
local MAX_STRIKE_PITCH = 1.1

local EmployeeHitView = {}

local random = Random.new()
local hitConnections: { [Instance]: RBXScriptConnection } = {}

local function playStrike(rig: Instance)
	local sound = rig:FindFirstChild(STRIKE_SOUND_NAME, true)
	if sound and sound:IsA("Sound") then
		sound.PlaybackSpeed = random:NextNumber(MIN_STRIKE_PITCH, MAX_STRIKE_PITCH)
		sound:Play()
	end
end

local function bind(rig: Instance)
	if hitConnections[rig] then
		return
	end
	hitConnections[rig] = rig:GetAttributeChangedSignal(EmployeeConfig.HITS_ATTRIBUTE):Connect(function()
		playStrike(rig)
	end)
end

local function unbind(rig: Instance)
	local connection = hitConnections[rig]
	if connection then
		connection:Disconnect()
		hitConnections[rig] = nil
	end
end

function EmployeeHitView.start()
	CollectionService:GetInstanceAddedSignal(EmployeeConfig.TAG):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(EmployeeConfig.TAG):Connect(unbind)
	for _, rig in CollectionService:GetTagged(EmployeeConfig.TAG) do
		bind(rig)
	end
end

return EmployeeHitView
