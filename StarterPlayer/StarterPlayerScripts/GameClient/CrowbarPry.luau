local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EyePryConfig = require(Shared:WaitForChild("EyePryConfig"))
local EyePull = require(Shared:WaitForChild("EyePull"))
local WallEyeConfig = require(Shared:WaitForChild("WallEyeConfig"))

local PRY_SCALE = 1
local CLAW_TIP = Vector3.new(1.85, 0.4, 0) * PRY_SCALE
local BAR_CENTER_HEIGHT = 0.05 * PRY_SCALE
local BAR_HALF_THICKNESS = 0.07 * PRY_SCALE
local SEAM_ANGLE = math.rad(76)
local SIDE_ON_SCREEN = Vector2.new(1, -0.3)
local HANDLE_OUTWARD = 0.3
local HANDLE_SIDEWAYS = 0.5
local HANDLE_DOWNWARD = 0.4
local HOOK_DEPTH = 1
local GRAB_SHIFT = 0.5
local INSERT_TRAVEL = 0.9
local TUG_ANGLE = math.rad(10)
local APPROACH_END = 0.26
local INSERT_END = 0.36
local GRAB_END = 0.44
local PULL_END = EyePryConfig.POP_DELAY
local RELEASE_DEADLINE = 1.6
local RETURN_DURATION = 0.32
local MIN_SIDE_LENGTH = 1e-3

export type Pry = {
	ready: CFrame,
	inserted: CFrame,
	hooked: CFrame,
	pullOffset: Vector3,
	releasedAt: number?,
}

local CrowbarPry = {}

local function progress(elapsed: number, startsAt: number, endsAt: number, style: Enum.EasingStyle, direction: Enum.EasingDirection): number
	return TweenService:GetValue(math.clamp((elapsed - startsAt) / (endsAt - startsAt), 0, 1), style, direction)
end

local function pullProgress(elapsed: number): number
	return progress(elapsed, GRAB_END, PULL_END, Enum.EasingStyle.Back, Enum.EasingDirection.InOut)
end

local function lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

local function sideOnWall(socketNormal: Vector3, camera: CFrame): Vector3
	local screenSide = camera.RightVector * SIDE_ON_SCREEN.X + camera.UpVector * SIDE_ON_SCREEN.Y
	local side = screenSide - socketNormal * screenSide:Dot(socketNormal)
	if side.Magnitude < MIN_SIDE_LENGTH then
		side = socketNormal:Cross(camera.UpVector)
	end
	return side.Unit
end

local function downOnWall(socketNormal: Vector3, side: Vector3, camera: CFrame): Vector3
	local along = socketNormal:Cross(side)
	return if along:Dot(camera.UpVector) > 0 then -along else along
end

local function pullPose(pry: Pry, alpha: number): CFrame
	local tug = CFrame.new(CLAW_TIP) * CFrame.Angles(0, 0, TUG_ANGLE * alpha) * CFrame.new(-CLAW_TIP)
	return pry.hooked * tug + pry.pullOffset * alpha
end

function CrowbarPry.new(eyeCenter: Vector3, socketNormal: Vector3, camera: CFrame): Pry
	local side = sideOnWall(socketNormal, camera)
	local down = downOnWall(socketNormal, side, camera)
	local seamDirection = socketNormal * math.cos(SEAM_ANGLE) + side * math.sin(SEAM_ANGLE)
	local entry = eyeCenter + seamDirection * (WallEyeConfig.EYE_RADIUS + BAR_HALF_THICKNESS)
	local barAxis = -(socketNormal * HANDLE_OUTWARD + side * HANDLE_SIDEWAYS + down * HANDLE_DOWNWARD).Unit
	local towardEye = eyeCenter - entry
	local clawSide = (towardEye - barAxis * towardEye:Dot(barAxis)).Unit
	local orientation = CFrame.fromMatrix(Vector3.zero, barAxis, clawSide)
	local hooked = orientation + (entry - barAxis * (CLAW_TIP.X - HOOK_DEPTH) - clawSide * BAR_CENTER_HEIGHT)
	local inserted = hooked + side * GRAB_SHIFT
	return {
		ready = inserted - barAxis * INSERT_TRAVEL,
		inserted = inserted,
		hooked = hooked,
		pullOffset = EyePull.offset(eyeCenter, camera.Position, socketNormal),
		releasedAt = nil,
	}
end

function CrowbarPry.toolPose(pry: Pry, hold: CFrame, holdScale: number, elapsed: number, isPlucked: boolean): (CFrame?, number?)
	if elapsed < APPROACH_END then
		local alpha = progress(elapsed, 0, APPROACH_END, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		return hold:Lerp(pry.ready, alpha), lerp(holdScale, PRY_SCALE, alpha)
	elseif elapsed < INSERT_END then
		local alpha = progress(elapsed, APPROACH_END, INSERT_END, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		return pry.ready:Lerp(pry.inserted, alpha), PRY_SCALE
	elseif elapsed < GRAB_END then
		local alpha = progress(elapsed, INSERT_END, GRAB_END, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		return pry.inserted:Lerp(pry.hooked, alpha), PRY_SCALE
	elseif elapsed < PULL_END then
		return pullPose(pry, pullProgress(elapsed)), PRY_SCALE
	end
	if not pry.releasedAt then
		if not isPlucked and elapsed < RELEASE_DEADLINE then
			return pullPose(pry, 1), PRY_SCALE
		end
		pry.releasedAt = elapsed
	end
	local releasedAt = pry.releasedAt :: number
	local alpha = progress(elapsed, releasedAt, releasedAt + RETURN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	if alpha >= 1 then
		return nil, nil
	end
	return pullPose(pry, 1):Lerp(hold, alpha), lerp(PRY_SCALE, holdScale, alpha)
end

function CrowbarPry.eyeOffset(pry: Pry, elapsed: number, isPlucked: boolean): Vector3?
	if isPlucked or elapsed >= RELEASE_DEADLINE then
		return nil
	end
	return if elapsed < GRAB_END then Vector3.zero else pry.pullOffset * pullProgress(elapsed)
end

return CrowbarPry
