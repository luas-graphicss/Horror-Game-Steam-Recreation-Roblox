local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EmployeeConfig = require(ReplicatedStorage.Shared.EmployeeConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Employees = require(script.Parent.Employees)
local HammerSwings = require(script.Parent.HammerSwings)
local PlayerReach = require(script.Parent.PlayerReach)
local RemoteThrottle = require(script.Parent.RemoteThrottle)

local STRIKE_REQUESTS_PER_SECOND = 12

local EmployeeStrikes = {}

local function hitsOf(rig: Model): number
	local hits = rig:GetAttribute(EmployeeConfig.HITS_ATTRIBUTE)
	return if typeof(hits) == "number" then hits else 0
end

local function canStrike(player: Player, rig: Model): boolean
	return rig:HasTag(EmployeeConfig.TAG)
		and rig:IsDescendantOf(Workspace)
		and rig:GetAttribute(EmployeeConfig.KNOCKED_OUT_ATTRIBUTE) ~= true
		and rig:GetAttribute(EmployeeConfig.OWNER_ATTRIBUTE) == player.UserId
		and PlayerReach.isWithin(player, rig:GetPivot().Position, EmployeeConfig.STRIKE_REACH)
end

local function onStrikeRequested(player: Player, rig: unknown)
	if typeof(rig) ~= "Instance" or not rig:IsA("Model") or not canStrike(player, rig) or not HammerSwings.tryConsume(player) then
		return
	end
	local hits = hitsOf(rig) + 1
	rig:SetAttribute(EmployeeConfig.HITS_ATTRIBUTE, hits)
	if hits >= EmployeeConfig.HITS_TO_KNOCK_OUT then
		Employees.knockOut(rig)
	end
end

function EmployeeStrikes.start()
	RemoteThrottle.connect(Remotes.StrikeEmployee, STRIKE_REQUESTS_PER_SECOND, onStrikeRequested)
end

return EmployeeStrikes
