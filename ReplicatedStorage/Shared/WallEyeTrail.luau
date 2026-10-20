local WallEyeConfig = require(script.Parent.WallEyeConfig)

local POINT_PREFIX = WallEyeConfig.TRAIL_POINT_ATTRIBUTE_PREFIX

local WallEyeTrail = {}

local function pointAttribute(index: number): string
	return POINT_PREFIX .. index
end

function WallEyeTrail.isTrailAttribute(name: string): boolean
	return name == WallEyeConfig.TRAIL_COUNT_ATTRIBUTE or string.sub(name, 1, #POINT_PREFIX) == POINT_PREFIX
end

 
 
function WallEyeTrail.write(holder: Instance, trail: { Vector3 }, firstChangedIndex: number, previousCount: number)
	for index = firstChangedIndex, #trail do
		holder:SetAttribute(pointAttribute(index), trail[index])
	end
	holder:SetAttribute(WallEyeConfig.TRAIL_COUNT_ATTRIBUTE, #trail)
	for index = #trail + 1, previousCount do
		holder:SetAttribute(pointAttribute(index), nil)
	end
end

function WallEyeTrail.read(holder: Instance): { Vector3 }
	local trail = {}
	local count = holder:GetAttribute(WallEyeConfig.TRAIL_COUNT_ATTRIBUTE)
	if typeof(count) ~= "number" then
		return trail
	end
	for index = 1, count do
		local point = holder:GetAttribute(pointAttribute(index))
		if typeof(point) ~= "Vector3" then
			break
		end
		trail[index] = point
	end
	return trail
end

return WallEyeTrail
