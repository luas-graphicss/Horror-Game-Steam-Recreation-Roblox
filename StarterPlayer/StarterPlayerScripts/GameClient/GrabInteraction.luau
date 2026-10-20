local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GrabConfig = require(Shared:WaitForChild("GrabConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AimTarget = require(script.Parent:WaitForChild("AimTarget"))
local Crosshair = require(script.Parent:WaitForChild("Crosshair"))
local GrabCarry = require(script.Parent:WaitForChild("GrabCarry"))
local PrimaryAction = require(script.Parent:WaitForChild("PrimaryAction"))

local CONFIRM_TIMEOUT = 2

type PendingGrab = {
	body: Instance,
	part: BasePart,
	localGrabPoint: Vector3,
	requestedAt: number,
}

local GrabInteraction = {}

local player = Players.LocalPlayer
local pendingGrab: PendingGrab? = nil

local function holderOf(body: Instance): number?
	local userId = body:GetAttribute(GrabConfig.HELD_BY_ATTRIBUTE)
	return if typeof(userId) == "number" then userId else nil
end

local function isHeldByOther(body: Instance): boolean
	local holder = holderOf(body)
	return holder ~= nil and holder ~= player.UserId
end

local function aimedHandle(): (Instance?, BasePart?, Vector3?)
	local body, hit = AimTarget.findHit(GrabConfig.TAG)
	if not body or not hit or isHeldByOther(body) then
		return nil, nil, nil
	end
	local part = hit.Instance
	if not part:IsA("BasePart") or part.Anchored or not part.CanCollide then
		return nil, nil, nil
	end
	return body, part, hit.Position
end

local function onPressed()
	if pendingGrab or GrabCarry.carriedBody() then
		return
	end
	local body, part, grabPoint = aimedHandle()
	if not body or not part or not grabPoint then
		return
	end
	pendingGrab = {
		body = body,
		part = part,
		localGrabPoint = part.CFrame:PointToObjectSpace(grabPoint),
		requestedAt = os.clock(),
	}
	Remotes.GrabBody:FireServer(body, part)
end

local function release()
	GrabCarry.stop()
	Remotes.ReleaseBody:FireServer()
end

local function settlePendingGrab(pending: PendingGrab)
	if holderOf(pending.body) == player.UserId then
		pendingGrab = nil
		if PrimaryAction.isHeld() and pending.part:IsDescendantOf(Workspace) then
			GrabCarry.begin(pending.body, pending.part, pending.localGrabPoint)
		else
			Remotes.ReleaseBody:FireServer()
		end
	elseif isHeldByOther(pending.body) or os.clock() - pending.requestedAt > CONFIRM_TIMEOUT then
		pendingGrab = nil
	end
end

local function updateCarry(body: Instance)
	if not body:IsDescendantOf(Workspace) or holderOf(body) ~= player.UserId then
		GrabCarry.stop()
	elseif not PrimaryAction.isHeld() then
		release()
	end
end

local function onRenderStepped()
	local pending = pendingGrab
	if pending then
		settlePendingGrab(pending)
	end
	local carried = GrabCarry.carriedBody()
	if carried then
		updateCarry(carried)
	end
	Crosshair.showGrabHand(GrabCarry.carriedBody() ~= nil or aimedHandle() ~= nil)
end

function GrabInteraction.start()
	PrimaryAction.pressed:Connect(onPressed)
	RunService.RenderStepped:Connect(onRenderStepped)
end

return GrabInteraction
