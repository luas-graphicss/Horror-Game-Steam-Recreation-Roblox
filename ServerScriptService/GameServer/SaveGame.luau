local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAttributes = require(ReplicatedStorage.Shared.PlayerAttributes)
local SaveStatus = require(ReplicatedStorage.Shared.SaveStatus)
local CrankGenerator = require(script.Parent.CrankGenerator)
local Employees = require(script.Parent.Employees)
local Ending = require(script.Parent.Ending)
local Grinder = require(script.Parent.Grinder)
local LooseEyes = require(script.Parent.LooseEyes)
local PlacedBodies = require(script.Parent.PlacedBodies)
local PlayerData = require(script.Parent.PlayerData)
local PlayerSettings = require(script.Parent.PlayerSettings)
local SectorDoor = require(script.Parent.SectorDoor)
local Storyline = require(script.Parent.Storyline)
local Tromby = require(script.Parent.Tromby)
local TrombyWatcher = require(script.Parent.TrombyWatcher)
local WallEyeSpawner = require(script.Parent.WallEyeSpawner)

local STORE_NAME = "EmployeeFiles"
local KEY_FORMAT = "Employee_%d"
local SCHEMA_VERSION = 1
local AUTOSAVE_INTERVAL = 45
local MAX_ATTEMPTS = 4
local RETRY_BACKOFF = 2
local SESSION_LOCK_TIMEOUT = 90
local LOCK_POLL_INTERVAL = 5
local SHUTDOWN_GRACE = 25
local MAX_PENDING_CALL_DELAY = 3600
local CFRAME_COMPONENTS = 12
local ACTIVE = "Active"
local OFFLINE = "Offline"
local CONCLUDED = "Concluded"

type Table = { [any]: any }

local SaveGame = {}

local hasStore, store = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
local sessions: { [Player]: string } = {}
local writing: { [Player]: boolean } = {}
local hasRestoredWorld = false

local function keyFor(player: Player): string
	return string.format(KEY_FORMAT, player.UserId)
end

local function tableOrEmpty(value: unknown): Table
	return if typeof(value) == "table" then value else {}
end

local function amount(value: unknown, fallback: number): number
	if typeof(value) == "number" and value == value and value >= 0 and value ~= math.huge then
		return value
	end
	return fallback
end

local function stringList(value: unknown): { string }
	local list = {}
	for _, item in tableOrEmpty(value) do
		if typeof(item) == "string" then
			table.insert(list, item)
		end
	end
	return list
end

local function encodeCFrame(cframe: CFrame): { number }
	return { cframe:GetComponents() }
end

local function decodeCFrame(value: unknown): CFrame?
	if typeof(value) ~= "table" or #value ~= CFRAME_COMPONENTS then
		return nil
	end
	for _, component in value do
		if typeof(component) ~= "number" or component ~= component then
			return nil
		end
	end
	return CFrame.new(table.unpack(value))
end

local function encodeWorld(): Table
	local wallEyes = {}
	for _, eye in WallEyeSpawner.eyes() do
		table.insert(wallEyes, { pivot = encodeCFrame(eye.pivot), isPlucked = eye.isPlucked })
	end
	local looseEyes = {}
	for _, pivot in LooseEyes.pivots() do
		table.insert(looseEyes, encodeCFrame(pivot))
	end
	local bodies = {}
	for _, body in Employees.bodies() do
		table.insert(bodies, { name = body.name, pivot = encodeCFrame(body.pivot) })
	end
	return {
		story = Storyline.snapshot(),
		sectorDoor = SectorDoor.state(),
		trombyVanished = Tromby.hasVanished(),
		watcher = TrombyWatcher.snapshot(),
		generatorCharge = CrankGenerator.charge(),
		grindCount = Grinder.snapshot(),
		wallEyes = wallEyes,
		looseEyes = looseEyes,
		bodies = bodies,
		consumedBodies = PlacedBodies.consumed(),
	}
end

local function encodeProfile(player: Player): Table
	return {
		version = SCHEMA_VERSION,
		player = PlayerData.snapshot(player),
		staff = Employees.staffOf(player),
		settings = PlayerSettings.snapshot(player),
		world = encodeWorld(),
	}
end

local function decodePlayer(raw: Table, defaults: PlayerData.Snapshot): PlayerData.Snapshot
	local upgradeLevels = {}
	for itemId, level in tableOrEmpty(raw.upgradeLevels) do
		if typeof(itemId) == "string" then
			upgradeLevels[itemId] = math.floor(amount(level, 0))
		end
	end
	return {
		balanceCents = amount(raw.balanceCents, defaults.balanceCents),
		debtCents = amount(raw.debtCents, defaults.debtCents),
		blood = amount(raw.blood, defaults.blood),
		meat = amount(raw.meat, defaults.meat),
		boltsTightened = amount(raw.boltsTightened, defaults.boltsTightened),
		rareBoltsTightened = amount(raw.rareBoltsTightened, defaults.rareBoltsTightened),
		employeesHired = amount(raw.employeesHired, defaults.employeesHired),
		hiringUnlocked = raw.hiringUnlocked == true,
		equippedTool = if typeof(raw.equippedTool) == "string" then raw.equippedTool else nil,
		ownedItems = stringList(raw.ownedItems),
		upgradeLevels = upgradeLevels,
	}
end

local function decodeSettings(raw: unknown): PlayerSettings.Snapshot
	local values = {}
	for name, value in tableOrEmpty(raw) do
		if typeof(name) == "string" and typeof(value) == "number" then
			values[name] = value
		end
	end
	return values
end

local function decodeStaff(raw: unknown): { Employees.StaffRecord }
	local records = {}
	for _, entry in tableOrEmpty(raw) do
		if
			typeof(entry) == "table"
			and typeof(entry.line) == "string"
			and typeof(entry.area) == "string"
			and typeof(entry.candidate) == "string"
		then
			table.insert(records, { line = entry.line, area = entry.area, candidate = entry.candidate })
		end
	end
	return records
end

local function decodeStory(raw: unknown): Storyline.Snapshot
	local story = tableOrEmpty(raw)
	local pending = {}
	for callId, delay in tableOrEmpty(story.pending) do
		if typeof(callId) == "string" then
			pending[callId] = math.min(amount(delay, 0), MAX_PENDING_CALL_DELAY)
		end
	end
	return {
		rung = stringList(story.rung),
		heard = stringList(story.heard),
		pending = pending,
		crankSessions = math.floor(amount(story.crankSessions, 0)),
	}
end

local function decodeWatcher(raw: unknown): TrombyWatcher.Snapshot
	local watcher = tableOrEmpty(raw)
	return {
		contributions = amount(watcher.contributions, 0),
		hasDeparted = watcher.hasDeparted == true,
	}
end

local function decodeEyes(raw: unknown): { WallEyeSpawner.EyeRecord }
	local records = {}
	for _, entry in tableOrEmpty(raw) do
		local pivot = if typeof(entry) == "table" then decodeCFrame(entry.pivot) else nil
		if pivot then
			table.insert(records, { pivot = pivot, isPlucked = entry.isPlucked == true })
		end
	end
	return records
end

local function decodePivots(raw: unknown): { CFrame }
	local pivots = {}
	for _, entry in tableOrEmpty(raw) do
		local pivot = decodeCFrame(entry)
		if pivot then
			table.insert(pivots, pivot)
		end
	end
	return pivots
end

local function decodeBodies(raw: unknown): { Employees.BodyRecord }
	local records = {}
	for _, entry in tableOrEmpty(raw) do
		local pivot = if typeof(entry) == "table" then decodeCFrame(entry.pivot) else nil
		if pivot and typeof(entry.name) == "string" then
			table.insert(records, { name = entry.name, pivot = pivot })
		end
	end
	return records
end

local function restoreWorld(world: Table, player: Player)
	Storyline.restore(decodeStory(world.story))
	if typeof(world.sectorDoor) == "string" then
		SectorDoor.restore(world.sectorDoor)
	end
	Tromby.restore(world.trombyVanished == true)
	TrombyWatcher.restore(decodeWatcher(world.watcher))
	CrankGenerator.restore(amount(world.generatorCharge, 0))
	Grinder.restore(math.floor(amount(world.grindCount, 0)))
	WallEyeSpawner.restore(decodeEyes(world.wallEyes))
	LooseEyes.restore(decodePivots(world.looseEyes), player)
	Employees.restoreBodies(decodeBodies(world.bodies), player)
	PlacedBodies.restore(stringList(world.consumedBodies))
end

local function restoreProfile(player: Player, profile: Table): boolean
	PlayerSettings.restore(player, decodeSettings(profile.settings))
	local hasProgress = typeof(profile.player) == "table"
	if hasProgress then
		PlayerData.restore(player, decodePlayer(profile.player, PlayerData.snapshot(player)))
	end
	if not hasRestoredWorld and typeof(profile.world) == "table" then
		restoreWorld(profile.world, player)
	end
	Employees.restoreStaff(player, decodeStaff(profile.staff))
	return hasProgress
end

local function attempt(operation: () -> ()): boolean
	for tryNumber = 1, MAX_ATTEMPTS do
		local succeeded, problem = pcall(operation)
		if succeeded then
			return true
		end
		warn(string.format("[SaveGame] Tentativa %d de %d falhou: %s", tryNumber, MAX_ATTEMPTS, tostring(problem)))
		if tryNumber < MAX_ATTEMPTS then
			task.wait(RETRY_BACKOFF * tryNumber)
		end
	end
	return false
end

local function isLockedElsewhere(lock: unknown): boolean
	return typeof(lock) == "table"
		and lock.jobId ~= game.JobId
		and typeof(lock.lockedAt) == "number"
		and os.time() - lock.lockedAt < SESSION_LOCK_TIMEOUT
end

local function claim(player: Player): (boolean, Table?)
	local startedWaitingAt = os.clock()
	while player.Parent == Players do
		local isBlocked = false
		local profile: Table? = nil
		local mayTakeOver = os.clock() - startedWaitingAt >= SESSION_LOCK_TIMEOUT
		local succeeded = attempt(function()
			store:UpdateAsync(keyFor(player), function(record: Table?)
				local current = record or {}
				isBlocked = not mayTakeOver and isLockedElsewhere(current.lock)
				if isBlocked then
					return nil
				end
				profile = if typeof(current.profile) == "table" then current.profile else nil
				current.lock = { jobId = game.JobId, lockedAt = os.time() }
				return current
			end)
		end)
		if not succeeded then
			return false, nil
		end
		if not isBlocked then
			return true, profile
		end
		task.wait(LOCK_POLL_INTERVAL)
	end
	return false, nil
end

local function write(player: Player, profile: Table, releasesLock: boolean)
	attempt(function()
		store:UpdateAsync(keyFor(player), function(record: Table?)
			local current = record or {}
			if isLockedElsewhere(current.lock) then
				return nil
			end
			current.profile = profile
			current.lock = if releasesLock then nil else { jobId = game.JobId, lockedAt = os.time() }
			return current
		end)
	end)
end

local function unlock(player: Player)
	attempt(function()
		store:UpdateAsync(keyFor(player), function(record: Table?)
			if not record or typeof(record.lock) ~= "table" or record.lock.jobId ~= game.JobId then
				return nil
			end
			record.lock = nil
			return record
		end)
	end)
end

local function awaitTurn(player: Player)
	while writing[player] do
		task.wait()
	end
	writing[player] = true
end

local function save(player: Player, releasesLock: boolean)
	if sessions[player] ~= ACTIVE then
		return
	end
	local profile = encodeProfile(player)
	awaitTurn(player)
	if sessions[player] == ACTIVE then
		write(player, profile, releasesLock)
	end
	writing[player] = nil
end

local function load(player: Player)
	player:SetAttribute(PlayerAttributes.SAVE_STATUS, SaveStatus.LOADING)
	local succeeded, profile = false, nil
	if hasStore then
		succeeded, profile = claim(player)
	end
	if player.Parent ~= Players then
		if succeeded then
			unlock(player)
		end
		return
	end
	local status = SaveStatus.FRESH
	sessions[player] = if succeeded then ACTIVE else OFFLINE
	if not succeeded then
		status = SaveStatus.OFFLINE
	elseif profile and profile.version == SCHEMA_VERSION then
		local restored, result = pcall(restoreProfile, player, profile)
		if not restored then
			warn("[SaveGame] Falha ao restaurar o progresso:", result)
			sessions[player] = OFFLINE
			status = SaveStatus.OFFLINE
		elseif result then
			status = SaveStatus.RESUMED
		end
	end
	hasRestoredWorld = true
	player:SetAttribute(PlayerAttributes.SAVE_STATUS, status)
end

local function closeWithFreshProfile(player: Player)
	if sessions[player] ~= ACTIVE then
		return
	end
	sessions[player] = CONCLUDED
	local profile = { version = SCHEMA_VERSION, settings = PlayerSettings.snapshot(player) }
	awaitTurn(player)
	write(player, profile, true)
	writing[player] = nil
end

local function onPlayerRemoving(player: Player)
	save(player, true)
	sessions[player] = nil
end

local function onShutdown()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			save(player, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + SHUTDOWN_GRACE
	while pending > 0 and os.clock() < deadline do
		task.wait()
	end
end

local function autosave()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			task.spawn(save, player, false)
		end
	end
end

function SaveGame.start()
	Ending.concluded:Connect(closeWithFreshProfile)
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	game:BindToClose(onShutdown)
	task.spawn(autosave)
end

return SaveGame
