local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local FOOTSTEPS_FOLDER_NAME = "Footsteps"
local HUMANOID_NAME = "Humanoid"
local ROOT_PART_NAME = "HumanoidRootPart"
local DEFAULT_RUNNING_SOUND_NAME = "Running"
local DEFAULT_SOUND_TIMEOUT = 10
local STRIDE_LENGTH = 5.2
local FIRST_STEP_HEAD_START = 0.6
local MIN_STEP_SPEED = 2
local PITCH_VARIATION = 0.08
local GROUNDED_STATES = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
}

type Walker = {
	humanoid: Humanoid,
	rootPart: BasePart,
	steps: { Sound },
	distance: number,
	lastStepIndex: number,
}

local Footsteps = {}

local walkers: { [Model]: Walker } = {}
local random = Random.new()

local function muteDefaultRunningSound(rootPart: BasePart)
	local running = rootPart:WaitForChild(DEFAULT_RUNNING_SOUND_NAME, DEFAULT_SOUND_TIMEOUT)
	if running and running:IsA("Sound") then
		running.Volume = 0
	end
end

local function track(character: Model)
	local humanoid = character:WaitForChild(HUMANOID_NAME) :: Humanoid
	local rootPart = character:WaitForChild(ROOT_PART_NAME) :: BasePart
	local steps: { Sound } = {}
	for _, template in SoundService:WaitForChild(FOOTSTEPS_FOLDER_NAME):GetChildren() do
		local step = template:Clone() :: Sound
		step.Parent = rootPart
		table.insert(steps, step)
	end
	walkers[character] = {
		humanoid = humanoid,
		rootPart = rootPart,
		steps = steps,
		distance = STRIDE_LENGTH * FIRST_STEP_HEAD_START,
		lastStepIndex = #steps,
	}
	muteDefaultRunningSound(rootPart)
end

local function playStep(walker: Walker)
	local index = random:NextInteger(1, #walker.steps - 1)
	if index >= walker.lastStepIndex then
		index += 1
	end
	walker.lastStepIndex = index
	local step = walker.steps[index]
	step.PlaybackSpeed = 1 + random:NextNumber(-PITCH_VARIATION, PITCH_VARIATION)
	step:Play()
end

local function onHeartbeat(deltaTime: number)
	for character, walker in walkers do
		if not character.Parent then
			walkers[character] = nil
			continue
		end
		local velocity = walker.rootPart.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local grounded = GROUNDED_STATES[walker.humanoid:GetState()] == true
		if walker.humanoid.Health <= 0 or not grounded or speed < MIN_STEP_SPEED then
			walker.distance = STRIDE_LENGTH * FIRST_STEP_HEAD_START
			continue
		end
		walker.distance += speed * deltaTime
		if walker.distance >= STRIDE_LENGTH then
			walker.distance -= STRIDE_LENGTH
			playStep(walker)
		end
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(track)
	if player.Character then
		task.spawn(track, player.Character)
	end
end

function Footsteps.start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	RunService.Heartbeat:Connect(onHeartbeat)
end

return Footsteps
