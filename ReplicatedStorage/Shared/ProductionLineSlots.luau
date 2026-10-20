local CollectionService = game:GetService("CollectionService")

local ProductionLineConfig = require(script.Parent.ProductionLineConfig)

local ProductionLineSlots = {}

function ProductionLineSlots.isStaffed(line: Instance): boolean
	return line:GetAttribute(ProductionLineConfig.EMPLOYEE_ATTRIBUTE) ~= nil
end

function ProductionLineSlots.acceptsAnyArea(line: Instance): boolean
	return line:GetAttribute(ProductionLineConfig.LAYOUT_ROLE_ATTRIBUTE) == ProductionLineConfig.VERTICAL_LAYOUT_ROLE
end

function ProductionLineSlots.freeLine(area: string): Instance?
	local sharedLine: Instance? = nil
	for _, line in CollectionService:GetTagged(ProductionLineConfig.TAG) do
		if ProductionLineSlots.isStaffed(line) then
			continue
		elseif ProductionLineSlots.acceptsAnyArea(line) then
			sharedLine = sharedLine or line
		elseif line:GetAttribute(ProductionLineConfig.WORK_AREA_ATTRIBUTE) == area then
			return line
		end
	end
	return sharedLine
end

return ProductionLineSlots
