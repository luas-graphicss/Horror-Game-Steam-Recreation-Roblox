local EyePryConfig = require(script.Parent.EyePryConfig)

local MIN_FLAT_DISTANCE = 1e-3

local EyePull = {}

function EyePull.direction(eyePosition: Vector3, viewpoint: Vector3, socketNormal: Vector3): Vector3
	local offset = viewpoint - eyePosition
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	return if flatOffset.Magnitude > MIN_FLAT_DISTANCE then flatOffset.Unit else socketNormal
end

function EyePull.offset(eyePosition: Vector3, viewpoint: Vector3, socketNormal: Vector3): Vector3
	return EyePull.direction(eyePosition, viewpoint, socketNormal) * EyePryConfig.PULL_DISTANCE
end

return EyePull
