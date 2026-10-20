local Workspace = game:GetService("Workspace")

local MAP_NAME = "MetalBox"
local CRANK_STATION_NAME = "CrankStation"
local WHEEL_NAME = "CrankWheel"
local PINION_NAME = "CrankPinion"
local MOUNT_NAME = "CrankMount"
local SLIDER_SCREEN_NAME = "SliderScreen"
local FACEPLATE_NAME = "ScreenFaceplate"
local DISPLAY_NAME = "Display"
local CHARGE_METER_NAME = "ChargeMeter"
local LEFT_SLIDER_NAME = "SliderLeft"
local RIGHT_SLIDER_NAME = "SliderRight"

export type Instances = {
	station: Model,
	wheel: BasePart,
	pinion: BasePart,
	mount: BasePart,
	faceplate: BasePart,
	chargeMeter: SurfaceGui,
	leftSlider: BasePart,
	rightSlider: BasePart,
}

local CrankGeneratorWorld = {}

function CrankGeneratorWorld.resolve(): Instances
	local map = Workspace:WaitForChild(MAP_NAME)
	local station = map:WaitForChild(CRANK_STATION_NAME) :: Model
	local sliderScreen = map:WaitForChild(SLIDER_SCREEN_NAME)
	return {
		station = station,
		wheel = station:WaitForChild(WHEEL_NAME) :: BasePart,
		pinion = station:WaitForChild(PINION_NAME) :: BasePart,
		mount = station:WaitForChild(MOUNT_NAME) :: BasePart,
		faceplate = sliderScreen:WaitForChild(FACEPLATE_NAME) :: BasePart,
		chargeMeter = sliderScreen:WaitForChild(DISPLAY_NAME):WaitForChild(CHARGE_METER_NAME) :: SurfaceGui,
		leftSlider = sliderScreen:WaitForChild(LEFT_SLIDER_NAME) :: BasePart,
		rightSlider = sliderScreen:WaitForChild(RIGHT_SLIDER_NAME) :: BasePart,
	}
end

return CrankGeneratorWorld
