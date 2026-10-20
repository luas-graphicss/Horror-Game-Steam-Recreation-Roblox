local TweenService = game:GetService("TweenService")

local BoltStationConfig = require(script.Parent.BoltStationConfig)
local BoltStationWorld = require(script.Parent.BoltStationWorld)

local FALL_DURATION = 0.32
local UPRIGHT_TRAVEL = 1.6
local TOPPLE_DURATION = 0.45
local TOPPLE_REST_ANGLE = math.rad(104.75)
local UNIT_TOPPLE_PROFILE = {
	Vector2.new(0.5115, 0),
	Vector2.new(0.6351, 0.0714),
	Vector2.new(0.7, 0.396),
	Vector2.new(0.7, 0.454),
	Vector2.new(0.31, 1.94),
	Vector2.new(0.27, 1.97),
	Vector2.new(0.23, 2),
}
local TOPPLE_PROFILE = table.create(#UNIT_TOPPLE_PROFILE)
for index, point in UNIT_TOPPLE_PROFILE do
	TOPPLE_PROFILE[index] = point * BoltStationConfig.BOLT_SCALE
end
local DROP_DURATION = 0.35

export type Routes = {
	slotPose: CFrame,
	spawnPose: CFrame,
	beltSpeed: number,
	travelDirection: Vector3,
	beltDuration: number,
	landingTime: number,
	toppleImpactTime: number,
	dropStartTime: number,
	outgoingDuration: number,
	poseAt: (route: string, elapsed: number) -> CFrame,
}

local BoltRoutes = {}

local routesByWorld: { [BoltStationWorld.Instances]: { [number]: Routes } } = {}

local function easeIn(alpha: number): number
	return TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

local function toppleLift(angle: number): number
	local lift = -math.huge
	for _, point in TOPPLE_PROFILE do
		lift = math.max(lift, point.X * math.sin(angle) - point.Y * math.cos(angle))
	end
	return lift
end

local function build(world: BoltStationWorld.Instances, beltSpeed: number): Routes
	local slotPose = world.boltSlot.WorldCFrame
	local landingPose = world.intakeLanding.WorldCFrame
	local spawnPose = world.intakeSpawn.WorldCFrame
	local dropPose = world.disposalDrop.WorldCFrame
	local travelDirection = (slotPose.Position - landingPose.Position).Unit
	local toppleAxis = slotPose.UpVector:Cross(travelDirection)
	local rollRadius = TOPPLE_PROFILE[1].X
	local toppleStart = UPRIGHT_TRAVEL / beltSpeed
	local mouthDistance = (world.disposalMouth.WorldPosition - slotPose.Position):Dot(travelDirection)
	local slideDuration = (mouthDistance - rollRadius * (1 - math.cos(TOPPLE_REST_ANGLE))) / beltSpeed
	local incomingSlideDuration = (slotPose.Position - landingPose.Position).Magnitude / beltSpeed
	local beltDuration = math.max(slideDuration, FALL_DURATION + incomingSlideDuration)
	local landingTime = beltDuration - incomingSlideDuration
	local fallStart = landingTime - FALL_DURATION
	local function slidingPoseAt(elapsed: number): CFrame
		local angle = TOPPLE_REST_ANGLE * easeIn(math.clamp((elapsed - toppleStart) / TOPPLE_DURATION, 0, 1))
		local travel = beltSpeed * elapsed + rollRadius * (1 - math.cos(angle))
		local position = slotPose.Position + travelDirection * travel + slotPose.UpVector * toppleLift(angle)
		return CFrame.new(position) * CFrame.fromAxisAngle(toppleAxis, angle) * slotPose.Rotation
	end
	local slideEndPose = slidingPoseAt(slideDuration)
	local function incomingPoseAt(elapsed: number): CFrame
		if elapsed < fallStart then
			return spawnPose
		elseif elapsed < landingTime then
			return spawnPose:Lerp(landingPose, easeIn((elapsed - fallStart) / FALL_DURATION))
		end
		return landingPose:Lerp(slotPose, math.min((elapsed - landingTime) / incomingSlideDuration, 1))
	end
	local function outgoingPoseAt(elapsed: number): CFrame
		if elapsed < slideDuration then
			return slidingPoseAt(math.max(elapsed, 0))
		end
		return slideEndPose:Lerp(dropPose, easeIn(math.min((elapsed - slideDuration) / DROP_DURATION, 1)))
	end
	return {
		slotPose = slotPose,
		spawnPose = spawnPose,
		beltSpeed = beltSpeed,
		travelDirection = travelDirection,
		beltDuration = beltDuration,
		landingTime = landingTime,
		toppleImpactTime = toppleStart + TOPPLE_DURATION,
		dropStartTime = slideDuration,
		outgoingDuration = slideDuration + DROP_DURATION,
		poseAt = function(route: string, elapsed: number): CFrame
			if route == BoltStationConfig.INCOMING_ROUTE then
				return incomingPoseAt(elapsed)
			end
			return outgoingPoseAt(elapsed)
		end,
	}
end

function BoltRoutes.fromWorld(world: BoltStationWorld.Instances, beltSpeed: number): Routes
	local routesBySpeed = routesByWorld[world]
	if not routesBySpeed then
		routesBySpeed = {}
		routesByWorld[world] = routesBySpeed
	end
	local routes = routesBySpeed[beltSpeed]
	if not routes then
		routes = build(world, beltSpeed)
		routesBySpeed[beltSpeed] = routes
	end
	return routes
end

return BoltRoutes
