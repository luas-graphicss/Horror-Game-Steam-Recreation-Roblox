local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CaptureConfig = require(ReplicatedStorage.Shared.CaptureConfig)
local WallEyeConfig = require(ReplicatedStorage.Shared.WallEyeConfig)
local WallEyeTrail = require(ReplicatedStorage.Shared.WallEyeTrail)
local WallEyeWorld = require(ReplicatedStorage.Shared.WallEyeWorld)
local PlayerCapture = require(script.Parent.PlayerCapture)

local APPROACH_SPEED = 2
local RETREAT_SPEED = 2.4
local CREEP_PERIOD = 1.6
local CREEP_FLOOR = 0.3
local CREEP_SHARPNESS = 1.5
local TURN_RATE = math.rad(75)
local CATCH_REACH = 0.9
local ARRIVAL_DISTANCE = 0.05
local EMERGE_DELAY = 1.2
local WATCH_HALF_ANGLE = math.rad(55)
local WATCH_CHECK_INTERVAL = 0.1
local WATCH_CONFIRM_TIME = 0.15
local UNWATCH_CONFIRM_TIME = 0.6
local SIGHT_SAMPLE_COUNT = 6
local SIGHT_SAMPLE_SPREAD = 0.75
local SIGHT_TOLERANCE = 0.1
local REPLICATION_INTERVAL = 0.05
local MIN_REPLICATED_MOVE = 0.01
local TRAIL_SPACING = 0.75
local COLLISION_SKIN = 0.2
local MIN_SLIDE_FRACTION = 0.2
local ROAM_MARGIN = 0.4
local RESERVED_CORD = 2.5
local STUCK_TIMEOUT = 1.25
local REROUTE_DURATION = 1.8
local DIRECT_PATH_SHARE = 0.8
local EPSILON = 1e-4
local FULL_CIRCLE = 2 * math.pi
local CATCH_DISTANCE = WallEyeConfig.EYE_RADIUS + CATCH_REACH
local COLLISION_RADIUS = WallEyeConfig.EYE_RADIUS + COLLISION_SKIN

export type Candidate = {
	player: Player,
	character: Model,
	head: BasePart,
	rootPart: BasePart,
}

export type Hunter = {
	world: WallEyeWorld.Instances,
	castParams: RaycastParams,
	restPoint: Vector3,
	socketNormal: Vector3,
	cordBudget: number,
	state: string,
	eyePosition: Vector3,
	heading: Vector3,
	trail: { Vector3 },
	trailLength: number,
	trailDirtyFrom: number,
	replicatedTrailCount: number,
	replicatedPosition: Vector3?,
	lastReplicationAt: number,
	lastWatchCheckAt: number,
	rawWatched: boolean,
	rawWatchedChangedAt: number,
	watched: boolean,
	unwatchedRestingSince: number?,
	stuckSince: number?,
	rerouteUntil: number,
	catchHoldUntil: number,
	isReturningHome: boolean,
	isPinned: boolean,
	isPlucked: boolean,
}

local WallEyeHunter = {}

local function setState(hunter: Hunter, newState: string)
	hunter.state = newState
	hunter.world.model:SetAttribute(WallEyeConfig.STATE_ATTRIBUTE, newState)
end

local function markTrailDirty(hunter: Hunter, index: number)
	hunter.trailDirtyFrom = math.min(hunter.trailDirtyFrom, index)
end

local function pushTrail(hunter: Hunter, point: Vector3)
	local trail = hunter.trail
	local last = trail[#trail]
	if last then
		hunter.trailLength += (point - last).Magnitude
	end
	table.insert(trail, point)
	markTrailDirty(hunter, #trail)
end

local function popTrail(hunter: Hunter)
	local trail = hunter.trail
	local count = #trail
	if count >= 2 then
		hunter.trailLength -= (trail[count] - trail[count - 1]).Magnitude
	end
	trail[count] = nil
	markTrailDirty(hunter, count)
end

local function clearTrail(hunter: Hunter)
	table.clear(hunter.trail)
	hunter.trailLength = 0
	markTrailDirty(hunter, 1)
end

local function clampToRoamVolume(hunter: Hunter, position: Vector3): Vector3
	local volume = hunter.world.roamVolume
	local half = volume.Size / 2 - Vector3.one * (COLLISION_RADIUS + ROAM_MARGIN)
	local offset = volume.CFrame:PointToObjectSpace(position)
	local clamped = Vector3.new(
		math.clamp(offset.X, -half.X, half.X),
		math.clamp(offset.Y, -half.Y, half.Y),
		math.clamp(offset.Z, -half.Z, half.Z)
	)
	return volume.CFrame:PointToWorldSpace(clamped)
end

local function isFacingEye(candidate: Candidate, toEye: Vector3): boolean
	local look = candidate.rootPart.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local flatToEye = Vector3.new(toEye.X, 0, toEye.Z)
	if flatLook.Magnitude < EPSILON or flatToEye.Magnitude < EPSILON then
		return false
	end
	local angle = math.acos(math.clamp(flatLook.Unit:Dot(flatToEye.Unit), -1, 1))
	local angularRadius = math.asin(math.min(WallEyeConfig.EYE_RADIUS / toEye.Magnitude, 1))
	return angle <= WATCH_HALF_ANGLE + angularRadius
end

local function hasLineOfSight(hunter: Hunter, origin: Vector3, target: Vector3): boolean
	local offset = target - origin
	local hit = Workspace:Raycast(origin, offset, hunter.castParams)
	return hit == nil or (hit.Position - origin).Magnitude >= offset.Magnitude - SIGHT_TOLERANCE
end

local function isEyeVisibleFrom(hunter: Hunter, origin: Vector3): boolean
	local eyePosition = hunter.eyePosition
	if hasLineOfSight(hunter, origin, eyePosition) then
		return true
	end
	local sightLine = (eyePosition - origin).Unit
	local side = sightLine:Cross(Vector3.yAxis)
	side = if side.Magnitude > EPSILON then side.Unit else Vector3.xAxis
	local lift = side:Cross(sightLine)
	local spread = WallEyeConfig.EYE_RADIUS * SIGHT_SAMPLE_SPREAD
	for index = 1, SIGHT_SAMPLE_COUNT do
		local angle = FULL_CIRCLE * index / SIGHT_SAMPLE_COUNT
		local sample = eyePosition + (side * math.cos(angle) + lift * math.sin(angle)) * spread
		if hasLineOfSight(hunter, origin, sample) then
			return true
		end
	end
	return false
end

local function isWatchedBy(hunter: Hunter, candidate: Candidate): boolean
	local origin = candidate.head.Position
	return isFacingEye(candidate, hunter.eyePosition - origin) and isEyeVisibleFrom(hunter, origin)
end

local function updateWatched(hunter: Hunter, candidates: { Candidate }, now: number)
	if now - hunter.lastWatchCheckAt >= WATCH_CHECK_INTERVAL then
		hunter.lastWatchCheckAt = now
		local anyoneWatching = false
		for _, candidate in candidates do
			if isWatchedBy(hunter, candidate) then
				anyoneWatching = true
				break
			end
		end
		if anyoneWatching ~= hunter.rawWatched then
			hunter.rawWatched = anyoneWatching
			hunter.rawWatchedChangedAt = now
		end
	end
	local confirmTime = if hunter.rawWatched then WATCH_CONFIRM_TIME else UNWATCH_CONFIRM_TIME
	if hunter.watched ~= hunter.rawWatched and now - hunter.rawWatchedChangedAt >= confirmTime then
		hunter.watched = hunter.rawWatched
	end
end

local function nearestCandidate(hunter: Hunter, candidates: { Candidate }): Candidate?
	local nearest: Candidate? = nil
	local nearestDistance = math.huge
	for _, candidate in candidates do
		local distance = (candidate.head.Position - hunter.eyePosition).Magnitude
		if distance < nearestDistance then
			nearest = candidate
			nearestDistance = distance
		end
	end
	return nearest
end

local function creepFactor(now: number): number
	local phase = (now % CREEP_PERIOD) / CREEP_PERIOD
	local surge = 0.5 - 0.5 * math.cos(FULL_CIRCLE * phase)
	return CREEP_FLOOR + (1 - CREEP_FLOOR) * surge ^ CREEP_SHARPNESS
end

local function turnToward(current: Vector3, desired: Vector3, maxAngle: number): Vector3
	local angle = math.acos(math.clamp(current:Dot(desired), -1, 1))
	if angle <= maxAngle then
		return desired
	end
	local axis = current:Cross(desired)
	if axis.Magnitude < EPSILON then
		axis = current:Cross(Vector3.yAxis)
		if axis.Magnitude < EPSILON then
			axis = current:Cross(Vector3.xAxis)
		end
	end
	return CFrame.fromAxisAngle(axis.Unit, maxAngle):VectorToWorldSpace(current).Unit
end

local function trailDirection(hunter: Hunter): Vector3
	local trail = hunter.trail
	local count = #trail
	local last = trail[count]
	if last and (hunter.eyePosition - last).Magnitude > EPSILON then
		return (hunter.eyePosition - last).Unit
	elseif count >= 2 then
		return (trail[count] - trail[count - 1]).Unit
	end
	return hunter.socketNormal
end

local function finishResting(hunter: Hunter)
	hunter.eyePosition = hunter.restPoint
	hunter.heading = hunter.socketNormal
	clearTrail(hunter)
	hunter.unwatchedRestingSince = nil
	hunter.stuckSince = nil
	hunter.isReturningHome = false
	setState(hunter, WallEyeConfig.RESTING_STATE)
end

local function beginHunting(hunter: Hunter)
	clearTrail(hunter)
	pushTrail(hunter, hunter.restPoint)
	hunter.heading = hunter.socketNormal
	hunter.stuckSince = nil
	setState(hunter, WallEyeConfig.HUNTING_STATE)
end

local function resumeHunting(hunter: Hunter)
	hunter.heading = trailDirection(hunter)
	hunter.stuckSince = nil
	setState(hunter, WallEyeConfig.HUNTING_STATE)
end

local function retreatAlongTrail(hunter: Hunter, dt: number)
	local trail = hunter.trail
	local remaining = RETREAT_SPEED * dt
	while remaining > 0 do
		local waypoint = trail[#trail]
		if waypoint == nil then
			finishResting(hunter)
			return
		end
		local toWaypoint = waypoint - hunter.eyePosition
		local distance = toWaypoint.Magnitude
		if distance > remaining then
			hunter.eyePosition += toWaypoint.Unit * remaining
			return
		end
		hunter.eyePosition = waypoint
		remaining -= distance
		if #trail == 1 then
			finishResting(hunter)
			return
		end
		popTrail(hunter)
	end
end

local function moveEye(hunter: Hunter, displacement: Vector3): (number, boolean)
	local length = displacement.Magnitude
	if length < EPSILON then
		return 0, false
	end
	local origin = hunter.eyePosition
	local hit = Workspace:Spherecast(origin, COLLISION_RADIUS, displacement, hunter.castParams)
	if hit then
		local slide = displacement - hit.Normal * displacement:Dot(hit.Normal)
		if slide.Magnitude < length * MIN_SLIDE_FRACTION then
			return 0, false
		end
		if Workspace:Spherecast(origin, COLLISION_RADIUS, slide, hunter.castParams) then
			return 0, false
		end
		displacement = slide
	end
	local anchor = hunter.trail[#hunter.trail]
	local nextPosition = origin + displacement
	if hunter.trailLength + (nextPosition - anchor).Magnitude > hunter.cordBudget then
		return 0, true
	end
	hunter.eyePosition = nextPosition
	if (nextPosition - anchor).Magnitude >= TRAIL_SPACING then
		pushTrail(hunter, nextPosition)
	end
	return displacement.Magnitude, false
end

local function huntToward(hunter: Hunter, target: Candidate, dt: number, now: number)
	local goal = clampToRoamVolume(hunter, target.head.Position)
	local toGoal = goal - hunter.eyePosition
	local distance = toGoal.Magnitude
	if distance < ARRIVAL_DISTANCE then
		hunter.stuckSince = nil
		return
	end
	hunter.heading = turnToward(hunter.heading, toGoal.Unit, TURN_RATE * dt)
	local intended = math.min(APPROACH_SPEED * creepFactor(now) * dt, distance)
	local moved, cordExhausted = moveEye(hunter, hunter.heading * intended)
	local blocked = moved < intended * MIN_SLIDE_FRACTION
	local pathIsWasteful = cordExhausted and (goal - hunter.restPoint).Magnitude < hunter.cordBudget * DIRECT_PATH_SHARE
	if not blocked or (cordExhausted and not pathIsWasteful) then
		hunter.stuckSince = nil
		return
	end
	local stuckSince = hunter.stuckSince or now
	hunter.stuckSince = stuckSince
	if now - stuckSince >= STUCK_TIMEOUT then
		hunter.stuckSince = nil
		hunter.rerouteUntil = now + REROUTE_DURATION
	end
end

local function catchIfTouching(hunter: Hunter, target: Candidate, now: number)
	if (target.head.Position - hunter.eyePosition).Magnitude > CATCH_DISTANCE then
		return
	end
	PlayerCapture.capture(target.player)
	hunter.isReturningHome = true
	hunter.catchHoldUntil = now + CaptureConfig.JUMPSCARE_DURATION
end

local function replicate(hunter: Hunter, now: number, force: boolean)
	local model = hunter.world.model
	if hunter.trailDirtyFrom ~= math.huge then
		local firstChangedIndex = math.min(hunter.trailDirtyFrom, #hunter.trail + 1)
		WallEyeTrail.write(model, hunter.trail, firstChangedIndex, hunter.replicatedTrailCount)
		hunter.replicatedTrailCount = #hunter.trail
		hunter.trailDirtyFrom = math.huge
	end
	local replicatedPosition = hunter.replicatedPosition
	local isDue = force or now - hunter.lastReplicationAt >= REPLICATION_INTERVAL
	if isDue and (replicatedPosition == nil or (hunter.eyePosition - replicatedPosition).Magnitude > MIN_REPLICATED_MOVE) then
		model:SetAttribute(WallEyeConfig.EYE_POSITION_ATTRIBUTE, hunter.eyePosition)
		hunter.replicatedPosition = hunter.eyePosition
		hunter.lastReplicationAt = now
	end
end

function WallEyeHunter.new(world: WallEyeWorld.Instances, castParams: RaycastParams): Hunter
	local restPoint = world.eyeRest.WorldPosition
	local mouthPoint = world.cordMouth.WorldPosition
	local fixedCord = (world.cordSink.WorldPosition - mouthPoint).Magnitude + (mouthPoint - restPoint).Magnitude
	local socketNormal = world.socket.CFrame.LookVector
	local hunter: Hunter = {
		world = world,
		castParams = castParams,
		restPoint = restPoint,
		socketNormal = socketNormal,
		cordBudget = WallEyeConfig.CORD_LENGTH - fixedCord - RESERVED_CORD,
		state = WallEyeConfig.RESTING_STATE,
		eyePosition = restPoint,
		heading = socketNormal,
		trail = {},
		trailLength = 0,
		trailDirtyFrom = math.huge,
		replicatedTrailCount = 0,
		replicatedPosition = nil,
		lastReplicationAt = -math.huge,
		lastWatchCheckAt = -math.huge,
		rawWatched = false,
		rawWatchedChangedAt = 0,
		watched = false,
		unwatchedRestingSince = nil,
		stuckSince = nil,
		rerouteUntil = 0,
		catchHoldUntil = 0,
		isReturningHome = false,
		isPinned = false,
		isPlucked = false,
	}
	WallEyeTrail.write(world.model, hunter.trail, 1, 0)
	setState(hunter, WallEyeConfig.RESTING_STATE)
	replicate(hunter, os.clock(), true)
	return hunter
end

local function pursue(hunter: Hunter, candidates: { Candidate }, isAnyoneWorking: boolean, dt: number, now: number)
	updateWatched(hunter, candidates, now)
	local target = nearestCandidate(hunter, candidates)
	local shouldRetreat = hunter.isReturningHome or hunter.watched or target == nil or isAnyoneWorking
	if hunter.state == WallEyeConfig.RESTING_STATE then
		if shouldRetreat then
			hunter.unwatchedRestingSince = nil
		else
			local restingSince = hunter.unwatchedRestingSince or now
			hunter.unwatchedRestingSince = restingSince
			if now - restingSince >= EMERGE_DELAY then
				beginHunting(hunter)
			end
		end
	elseif hunter.state == WallEyeConfig.HUNTING_STATE then
		if shouldRetreat then
			setState(hunter, WallEyeConfig.RETREATING_STATE)
		elseif now < hunter.rerouteUntil then
			retreatAlongTrail(hunter, dt)
		elseif target then
			huntToward(hunter, target, dt, now)
			catchIfTouching(hunter, target, now)
		end
	elseif not shouldRetreat then
		resumeHunting(hunter)
	else
		retreatAlongTrail(hunter, dt)
	end
end

local function withdraw(hunter: Hunter, dt: number)
	if hunter.state == WallEyeConfig.RESTING_STATE then
		return
	end
	if hunter.state == WallEyeConfig.HUNTING_STATE then
		setState(hunter, WallEyeConfig.RETREATING_STATE)
	end
	retreatAlongTrail(hunter, dt)
end

function WallEyeHunter.update(hunter: Hunter, candidates: { Candidate }, isAnyoneWorking: boolean, dt: number, now: number)
	if hunter.isPinned or now < hunter.catchHoldUntil then
		return
	end
	local previousState = hunter.state
	if hunter.isPlucked then
		withdraw(hunter, dt)
	else
		pursue(hunter, candidates, isAnyoneWorking, dt, now)
	end
	replicate(hunter, now, hunter.state ~= previousState)
end

function WallEyeHunter.isWatched(hunter: Hunter): boolean
	return hunter.watched
end

function WallEyeHunter.pin(hunter: Hunter): boolean
	if hunter.isPinned or hunter.isPlucked then
		return false
	end
	hunter.isPinned = true
	return true
end

function WallEyeHunter.pluck(hunter: Hunter)
	hunter.isPinned = false
	hunter.isPlucked = true
end

return WallEyeHunter
