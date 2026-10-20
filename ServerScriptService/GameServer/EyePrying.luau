local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EyePryConfig = require(ReplicatedStorage.Shared.EyePryConfig)
local EyePull = require(ReplicatedStorage.Shared.EyePull)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local WallEyeConfig = require(ReplicatedStorage.Shared.WallEyeConfig)
local WallEyeWorld = require(ReplicatedStorage.Shared.WallEyeWorld)
local LooseEyes = require(script.Parent.LooseEyes)
local PlayerReach = require(script.Parent.PlayerReach)
local RemoteThrottle = require(script.Parent.RemoteThrottle)
local ToolBelt = require(script.Parent.ToolBelt)
local WallEye = require(script.Parent.WallEye)

local HEAD_NAME = "Head"
local POP_OUTWARD_SPEED = 8
local POP_UPWARD_SPEED = 7
local POP_SPIN_SPEED = 9
local PRY_REQUESTS_PER_SECOND = 4

local EyePrying = {}

local random = Random.new()
local nextPryAt: { [Player]: number } = {}

local function headOf(player: Player): BasePart?
	local character = player.Character
	local head = character and character:FindFirstChild(HEAD_NAME)
	return if head and head:IsA("BasePart") then head else nil
end

local function viewpointOf(player: Player, eyePosition: Vector3, socketNormal: Vector3): Vector3
	local head = headOf(player)
	return if head then head.Position else eyePosition + socketNormal
end

local function popEye(player: Player, model: Model, pulledPosition: Vector3, socketNormal: Vector3)
	WallEye.pluck(model)
	local facing = viewpointOf(player, pulledPosition, socketNormal)
	local velocity = EyePull.direction(pulledPosition, facing, socketNormal) * POP_OUTWARD_SPEED + Vector3.yAxis * POP_UPWARD_SPEED
	local spin = random:NextUnitVector() * POP_SPIN_SPEED
	LooseEyes.spawn(WallEyeWorld.resolveEye(model), CFrame.lookAt(pulledPosition, facing), velocity, spin, player)
end

local function onPryRequested(player: Player, model: unknown)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model:HasTag(WallEyeConfig.TAG) then
		return
	end
	local now = os.clock()
	if now < (nextPryAt[player] or 0) or not ToolBelt.isEquipped(player, ShopCatalog.CROWBAR_ITEM_ID) then
		return
	end
	local eyePosition = WallEye.eyePosition(model)
	if not eyePosition or not PlayerReach.isWithin(player, eyePosition, EyePryConfig.REACH) or not WallEye.pin(model) then
		return
	end
	nextPryAt[player] = now + EyePryConfig.COOLDOWN
	local socketNormal = WallEyeWorld.resolve(model).socket.CFrame.LookVector
	local pullOffset = EyePull.offset(eyePosition, viewpointOf(player, eyePosition, socketNormal), socketNormal)
	task.delay(EyePryConfig.POP_DELAY, popEye, player, model, eyePosition + pullOffset, socketNormal)
end

local function forget(player: Player)
	nextPryAt[player] = nil
end

function EyePrying.start()
	RemoteThrottle.connect(Remotes.PryEye, PRY_REQUESTS_PER_SECOND, onPryRequested)
	Players.PlayerRemoving:Connect(forget)
end

return EyePrying
