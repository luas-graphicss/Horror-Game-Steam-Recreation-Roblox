local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlayerCapture = require(script.Parent.PlayerCapture)

local HUMANOID_NAME = "Humanoid"
local CHECK_INTERVAL = 0.25
local SPEED_TOLERANCE = 1.35
local SPEED_MARGIN = 6
local BURST_DURATION = 2
local GROUND_PLANE = Vector3.new(1, 0, 1)

type Watch = {
	humanoid: Humanoid,
	lastValidPosition: Vector3?,
	allowance: number,
}

local MovementGuard = {}

local watches: { [Player]: Watch } = {}
local sinceLastCheck = 0

local function speedLimit(humanoid: Humanoid): number
	return humanoid.WalkSpeed * SPEED_TOLERANCE + SPEED_MARGIN
end

local function pullBack(rootPart: BasePart, position: Vector3)
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.CFrame = rootPart.CFrame.Rotation + position
end

local function inspect(player: Player, watch: Watch, elapsed: number)
	local humanoid = watch.humanoid
	if humanoid.Health <= 0 or not humanoid:IsDescendantOf(Workspace) then
		watches[player] = nil
		return
	end
	local rootPart = humanoid.RootPart
	if not rootPart then
		return
	end
	local limit = speedLimit(humanoid)
	local burstAllowance = limit * BURST_DURATION
	local lastValidPosition = watch.lastValidPosition
	if not lastValidPosition or rootPart.Anchored or PlayerCapture.isCaptured(player) then
		watch.lastValidPosition = rootPart.Position
		watch.allowance = burstAllowance
		return
	end
	local travelled = ((rootPart.Position - lastValidPosition) * GROUND_PLANE).Magnitude
	watch.allowance = math.min(watch.allowance + limit * elapsed, burstAllowance)
	if travelled > watch.allowance then
		pullBack(rootPart, lastValidPosition)
		return
	end
	watch.allowance -= travelled
	watch.lastValidPosition = rootPart.Position
end

local function onHeartbeat(deltaTime: number)
	sinceLastCheck += deltaTime
	if sinceLastCheck < CHECK_INTERVAL then
		return
	end
	local elapsed = sinceLastCheck
	sinceLastCheck = 0
	for player, watch in watches do
		inspect(player, watch, elapsed)
	end
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild(HUMANOID_NAME) :: Humanoid
	if player.Character == character then
		watches[player] = { humanoid = humanoid, lastValidPosition = nil, allowance = 0 }
	end
end

local function forget(player: Player)
	watches[player] = nil
end

local function track(player: Player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		forget(player)
	end)
	local character = player.Character
	if character then
		task.spawn(watchCharacter, player, character)
	end
end

function MovementGuard.start()
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(forget)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return MovementGuard
