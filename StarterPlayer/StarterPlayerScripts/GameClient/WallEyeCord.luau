local ATTACH_INSET = 0.18
local EYE_CLEARANCE = 0.1
local MIN_BRIDGE_LENGTH = 1.2
local MAX_BRIDGE_LENGTH = 3
local MAX_BRIDGE_SPAN = 6
local MAX_BRIDGE_COS = math.cos(math.rad(95))
local BRIDGE_EXIT_HANDLE = 0.45
local BRIDGE_ENTRY_HANDLE = 0.3
local BRIDGE_STEP = 0.5
local MIN_POINT_SPACING = 0.05
local CURVE_STEP = 0.2
local SWAY_AMPLITUDE = 0.07
local SWAY_WAVELENGTH = 3.5
local SWAY_SPEED = 1.3
local SWAY_FULL_LENGTH = 4
local FULL_CIRCLE = 2 * math.pi

export type Anchors = {
	eyeRadius: number,
	mouthPoint: Vector3,
	sinkPoint: Vector3,
}

export type Solver = {
	anchors: Anchors,
	boneCount: number,
	restSpacing: number,
	pathPoints: { Vector3 },
	samples: { Vector3 },
	distances: { number },
	frames: { CFrame },
}

local WallEyeCord = {}

local function appendPoint(points: { Vector3 }, point: Vector3)
	local last = points[#points]
	if last == nil or (point - last).Magnitude > MIN_POINT_SPACING then
		table.insert(points, point)
	end
end

local function knot(from: Vector3, to: Vector3, previous: number): number
	return previous + math.sqrt(math.max((to - from).Magnitude, 1e-4))
end

 
local function centripetalPoint(
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	t1: number,
	t2: number,
	t3: number,
	alpha: number
): Vector3
	local t = t1 + (t2 - t1) * alpha
	local a1 = p0 * ((t1 - t) / t1) + p1 * (t / t1)
	local a2 = p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
	local a3 = p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
	local b1 = a1 * ((t2 - t) / t2) + a2 * (t / t2)
	local b2 = a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
	return b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1))
end

local function bezierPoint(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local u = 1 - t
	return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
end

 
 
 
 
local function buildPath(solver: Solver, eyeCFrame: CFrame, trail: { Vector3 })
	local anchors = solver.anchors
	local points = solver.pathPoints
	table.clear(points)
	local eyeCenter = eyeCFrame.Position
	local back = -eyeCFrame.LookVector
	local attach = eyeCenter + back * (anchors.eyeRadius - ATTACH_INSET)
	local followers = {}
	for index = #trail, 1, -1 do
		if (trail[index] - eyeCenter).Magnitude > anchors.eyeRadius + EYE_CLEARANCE then
			table.insert(followers, trail[index])
		end
	end
	table.insert(followers, anchors.mouthPoint)
	table.insert(followers, anchors.sinkPoint)
	local stalk = followers[1] - eyeCenter
	local deviation = 0
	if stalk.Magnitude > 1e-3 then
		deviation = math.clamp(math.acos(math.clamp(back:Dot(stalk.Unit), -1, 1)) / (math.pi / 2), 0, 1)
	end
	local bridgeLength = MIN_BRIDGE_LENGTH + (MAX_BRIDGE_LENGTH - MIN_BRIDGE_LENGTH) * deviation
	local function canRejoin(point: Vector3): boolean
		local chord = point - attach
		local length = chord.Magnitude
		if length < bridgeLength then
			return false
		end
		return length >= MAX_BRIDGE_SPAN or back:Dot(chord / length) >= MAX_BRIDGE_COS
	end
	local first = 1
	while first < #followers - 1 and not canRejoin(followers[first]) do
		first += 1
	end
	local target = followers[first]
	local onward = followers[first + 1] - target
	local span = (target - attach).Magnitude
	appendPoint(points, attach)
	if span > MIN_POINT_SPACING then
		local entryDirection = if onward.Magnitude > 1e-3 then onward.Unit else (target - attach).Unit
		local exitHandle = attach + back * (span * BRIDGE_EXIT_HANDLE)
		local entryHandle = target - entryDirection * (span * BRIDGE_ENTRY_HANDLE)
		local steps = math.max(1, math.ceil(span / BRIDGE_STEP))
		for step = 1, steps - 1 do
			appendPoint(points, bezierPoint(attach, exitHandle, entryHandle, target, step / steps))
		end
	end
	for index = first, #followers do
		appendPoint(points, followers[index])
	end
end

local function samplePath(solver: Solver)
	local points, samples, distances = solver.pathPoints, solver.samples, solver.distances
	table.clear(samples)
	table.clear(distances)
	local count = #points
	for index = 1, count - 1 do
		local p1, p2 = points[index], points[index + 1]
		local p0 = points[index - 1] or (p1 * 2 - p2)
		local p3 = points[index + 2] or (p2 * 2 - p1)
		local t1 = knot(p0, p1, 0)
		local t2 = knot(p1, p2, t1)
		local t3 = knot(p2, p3, t2)
		local steps = math.max(1, math.ceil((p2 - p1).Magnitude / CURVE_STEP))
		for step = 0, steps - 1 do
			table.insert(samples, centripetalPoint(p0, p1, p2, p3, t1, t2, t3, step / steps))
		end
	end
	table.insert(samples, points[count])
	distances[1] = 0
	for index = 2, #samples do
		distances[index] = distances[index - 1] + (samples[index] - samples[index - 1]).Magnitude
	end
end

 
 
local function placeBones(solver: Solver, eyeCFrame: CFrame, now: number)
	local samples, distances, frames = solver.samples, solver.distances, solver.frames
	local lastSample = #samples
	local total = distances[lastSample]
	local spacing = math.max(solver.restSpacing, total / (solver.boneCount - 1))
	local swayWeight = math.clamp(total / SWAY_FULL_LENGTH, 0, 1) * SWAY_AMPLITUDE
	local up = eyeCFrame.UpVector
	local tangent = -eyeCFrame.LookVector
	local segment = 1
	for index = 1, solver.boneCount do
		local distance = math.min((index - 1) * spacing, total)
		while segment < lastSample - 1 and distances[segment + 1] < distance do
			segment += 1
		end
		local nextIndex = math.min(segment + 1, lastSample)
		local from, to = samples[segment], samples[nextIndex]
		local span = distances[nextIndex] - distances[segment]
		local position = if span > 1e-6 then from:Lerp(to, (distance - distances[segment]) / span) else from
		if (to - from).Magnitude > 1e-6 then
			tangent = (to - from).Unit
		end
		local projected = up - tangent * up:Dot(tangent)
		up = if projected.Magnitude > 1e-4 then projected.Unit else tangent:Cross(Vector3.xAxis).Unit
		if distance < total then
			local taper = math.sin(math.pi * distance / total)
			local phase = distance / SWAY_WAVELENGTH * FULL_CIRCLE - now * SWAY_SPEED
			local right = tangent:Cross(up)
			position += (right * math.sin(phase) + up * math.cos(phase * 0.8)) * (swayWeight * taper)
		end
		frames[index] = CFrame.lookAt(position, position + tangent, up)
	end
end

function WallEyeCord.new(anchors: Anchors, boneCount: number, cordLength: number): Solver
	assert(boneCount >= 2, "WallEyeCord precisa de pelo menos dois ossos")
	return {
		anchors = anchors,
		boneCount = boneCount,
		restSpacing = cordLength / (boneCount - 1),
		pathPoints = {},
		samples = {},
		distances = {},
		frames = table.create(boneCount, CFrame.identity),
	}
end

 
function WallEyeCord.solve(solver: Solver, eyeCFrame: CFrame, trail: { Vector3 }, now: number): { CFrame }
	buildPath(solver, eyeCFrame, trail)
	samplePath(solver)
	placeBones(solver, eyeCFrame, now)
	return solver.frames
end

return WallEyeCord
