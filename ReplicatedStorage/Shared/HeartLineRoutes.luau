local TweenService = game:GetService("TweenService")

local BoltStationWorld = require(script.Parent.BoltStationWorld)

local FALL_DURATION = 0.32
local POOL_DROP_DURATION = 0.4
local POOL_DROP_DEPTH = 0.6

export type Routes = {
	beltSpeed: number,
	restPose: CFrame,
	spawnPose: CFrame,
	poolSlideDuration: number,
	poolDropEndTime: number,
	heartLandingTime: number,
	cycleDuration: number,
	heartPoseAt: (elapsed: number) -> CFrame,
	poolPoseAt: (elapsed: number) -> (CFrame, number),
}

local HeartLineRoutes = {}

local routesByWorld: { [BoltStationWorld.Instances]: { [number]: Routes } } = {}

local function easeIn(alpha: number): number
	return TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

local function build(world: BoltStationWorld.Instances, heartOffset: CFrame, poolRest: CFrame, beltSpeed: number): Routes
	local slotPosition = world.boltSlot.WorldPosition
	local restPose = world.boltSlot.WorldCFrame * heartOffset
	local landingPose = world.intakeLanding.WorldCFrame * heartOffset
	local spawnPose = world.intakeSpawn.WorldCFrame * heartOffset
	local travelDirection = (slotPosition - world.intakeLanding.WorldPosition).Unit
	local mouthDistance = (world.disposalMouth.WorldPosition - slotPosition):Dot(travelDirection)
	local poolMouthPose = poolRest + travelDirection * mouthDistance
	local poolDropPose = poolRest.Rotation + (world.disposalDrop.WorldPosition - Vector3.yAxis * POOL_DROP_DEPTH)
	local poolSlideDuration = mouthDistance / beltSpeed
	local poolDropEndTime = poolSlideDuration + POOL_DROP_DURATION
	local heartLandingTime = poolDropEndTime + FALL_DURATION
	local incomingSlideDuration = (restPose.Position - landingPose.Position).Magnitude / beltSpeed
	return {
		beltSpeed = beltSpeed,
		restPose = restPose,
		spawnPose = spawnPose,
		poolSlideDuration = poolSlideDuration,
		poolDropEndTime = poolDropEndTime,
		heartLandingTime = heartLandingTime,
		cycleDuration = heartLandingTime + incomingSlideDuration,
		heartPoseAt = function(elapsed: number): CFrame
			if elapsed < poolDropEndTime then
				return spawnPose
			elseif elapsed < heartLandingTime then
				return spawnPose:Lerp(landingPose, easeIn((elapsed - poolDropEndTime) / FALL_DURATION))
			end
			return landingPose:Lerp(restPose, math.min((elapsed - heartLandingTime) / incomingSlideDuration, 1))
		end,
		poolPoseAt = function(elapsed: number): (CFrame, number)
			if elapsed < poolSlideDuration then
				return poolRest + travelDirection * (beltSpeed * math.max(elapsed, 0)), 1
			end
			local alpha = math.min((elapsed - poolSlideDuration) / POOL_DROP_DURATION, 1)
			return poolMouthPose:Lerp(poolDropPose, easeIn(alpha)), 1 - alpha
		end,
	}
end

function HeartLineRoutes.fromWorld(world: BoltStationWorld.Instances, heartOffset: CFrame, poolRest: CFrame, beltSpeed: number): Routes
	local routesBySpeed = routesByWorld[world]
	if not routesBySpeed then
		routesBySpeed = {}
		routesByWorld[world] = routesBySpeed
	end
	local routes = routesBySpeed[beltSpeed]
	if not routes then
		routes = build(world, heartOffset, poolRest, beltSpeed)
		routesBySpeed[beltSpeed] = routes
	end
	return routes
end

return HeartLineRoutes
