local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GrabConfig = require(ReplicatedStorage.Shared.GrabConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerReach = require(script.Parent.PlayerReach)
local RemoteThrottle = require(script.Parent.RemoteThrottle)

local LEASH_SLACK = 6
local LEASH_RANGE = GrabConfig.MAX_HOLD_DISTANCE + LEASH_SLACK
local MAX_RELEASE_SPEED = 70
local HOLD_REQUESTS_PER_SECOND = 6

type Hold = {
	body: Instance,
	part: BasePart,
}

local Grabbing = {}

local holds: { [Player]: Hold } = {}

local function limitSpeed(body: Instance)
	for _, part in body:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			local velocity = part.AssemblyLinearVelocity
			if velocity.Magnitude > MAX_RELEASE_SPEED then
				part.AssemblyLinearVelocity = velocity.Unit * MAX_RELEASE_SPEED
			end
		end
	end
end

local function release(player: Player)
	local hold = holds[player]
	if not hold then
		return
	end
	holds[player] = nil
	hold.body:SetAttribute(GrabConfig.HELD_BY_ATTRIBUTE, nil)
	if hold.part:IsDescendantOf(Workspace) and hold.part:CanSetNetworkOwnership() then
		hold.part:SetNetworkOwner(nil)
		limitSpeed(hold.body)
	end
end

local function canGrab(player: Player, body: Instance, part: BasePart): boolean
	return body:HasTag(GrabConfig.TAG)
		and part:IsDescendantOf(body)
		and part:IsDescendantOf(Workspace)
		and not part.Anchored
		and body:GetAttribute(GrabConfig.HELD_BY_ATTRIBUTE) == nil
		and part:CanSetNetworkOwnership()
		and PlayerReach.isWithin(player, part.Position, GrabConfig.REACH)
end

local function onGrabRequested(player: Player, body: unknown, part: unknown)
	if typeof(body) ~= "Instance" or typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return
	end
	release(player)
	if not canGrab(player, body, part) then
		return
	end
	holds[player] = { body = body, part = part }
	body:SetAttribute(GrabConfig.HELD_BY_ATTRIBUTE, player.UserId)
	body:SetAttribute(GrabConfig.LAST_HOLDER_ATTRIBUTE, player.UserId)
	part:SetNetworkOwner(player)
end

local function onHeartbeat()
	for player, hold in holds do
		if not hold.part:IsDescendantOf(Workspace) then
			holds[player] = nil
		elseif not PlayerReach.isWithin(player, hold.part.Position, LEASH_RANGE) then
			release(player)
		end
	end
end

function Grabbing.start()
	RemoteThrottle.connect(Remotes.GrabBody, HOLD_REQUESTS_PER_SECOND, onGrabRequested)
	RemoteThrottle.connect(Remotes.ReleaseBody, HOLD_REQUESTS_PER_SECOND, release)
	Players.PlayerRemoving:Connect(release)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return Grabbing
