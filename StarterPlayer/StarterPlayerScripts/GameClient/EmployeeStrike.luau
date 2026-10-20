local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmployeeConfig = require(Shared:WaitForChild("EmployeeConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AimTarget = require(script.Parent:WaitForChild("AimTarget"))
local HammerSwing = require(script.Parent:WaitForChild("HammerSwing"))
local PrimaryAction = require(script.Parent:WaitForChild("PrimaryAction"))

local EmployeeStrike = {}

local player = Players.LocalPlayer

local function isStrikeable(rig: Instance): boolean
	return rig:GetAttribute(EmployeeConfig.OWNER_ATTRIBUTE) == player.UserId
		and rig:GetAttribute(EmployeeConfig.KNOCKED_OUT_ATTRIBUTE) ~= true
end

local function tryStrike()
	if not HammerSwing.isReady() then
		return
	end
	local rig = AimTarget.find(EmployeeConfig.TAG)
	if not rig or not isStrikeable(rig) then
		return
	end
	HammerSwing.swing()
	Remotes.StrikeEmployee:FireServer(rig)
end

function EmployeeStrike.start()
	PrimaryAction.triggered:Connect(tryStrike)
end

return EmployeeStrike
