local Workspace = game:GetService("Workspace")

local MAP_NAME = "MetalBox"
local PHONE_BOX_NAME = "PhoneBox"
local HOUSING_NAME = "PhoneHousing"

export type Instances = {
	box: Model,
	housing: BasePart,
}

local PhoneWorld = {}

function PhoneWorld.resolve(): Instances
	local box = Workspace:WaitForChild(MAP_NAME):WaitForChild(PHONE_BOX_NAME) :: Model
	return {
		box = box,
		housing = box:WaitForChild(HOUSING_NAME) :: BasePart,
	}
end

return PhoneWorld
