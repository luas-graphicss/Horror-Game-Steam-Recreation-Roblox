local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrankCharge = require(Shared:WaitForChild("CrankCharge"))
local CrankGeneratorWorld = require(Shared:WaitForChild("CrankGeneratorWorld"))

local LEFT_STRIP_NAME = "LeftStrip"
local RIGHT_STRIP_NAME = "RightStrip"
local FILL_NAME = "Fill"
local RIGHT_STRIP_SHARE = 0.2
local LOW_CHARGE_COLOR = Color3.fromRGB(255, 72, 40)
local FULL_CHARGE_COLOR = Color3.fromRGB(255, 186, 64)

type Strip = {
	fill: Frame,
	slider: BasePart,
	sliderRestCFrame: CFrame,
	sliderTravel: number,
	fractionStart: number,
	fractionEnd: number,
}

local ChargeMeterView = {}

local world: CrankGeneratorWorld.Instances
local strips: { Strip } = {}
local shownFraction: number? = nil

local function slotTravel(slider: BasePart): number
	local restHeight = world.faceplate.CFrame:PointToObjectSpace(slider.Position).Y
	return math.abs(restHeight) * 2
end

local function bindStrip(stripName: string, slider: BasePart, fractionStart: number, fractionEnd: number): Strip
	return {
		fill = world.chargeMeter:WaitForChild(stripName):WaitForChild(FILL_NAME) :: Frame,
		slider = slider,
		sliderRestCFrame = slider.CFrame,
		sliderTravel = slotTravel(slider),
		fractionStart = fractionStart,
		fractionEnd = fractionEnd,
	}
end

local function stripLevel(strip: Strip, fraction: number): number
	return math.clamp((fraction - strip.fractionStart) / (strip.fractionEnd - strip.fractionStart), 0, 1)
end

local function render(fraction: number)
	local color = LOW_CHARGE_COLOR:Lerp(FULL_CHARGE_COLOR, fraction)
	for _, strip in strips do
		local level = stripLevel(strip, fraction)
		strip.fill.Size = UDim2.fromScale(1, level)
		strip.fill.BackgroundColor3 = color
		strip.slider.CFrame = strip.sliderRestCFrame * CFrame.new(0, strip.sliderTravel * level, 0)
	end
end

local function onRenderStepped()
	local fraction = CrankCharge.fraction(CrankCharge.current(world.station))
	if fraction ~= shownFraction then
		shownFraction = fraction
		render(fraction)
	end
end

function ChargeMeterView.start()
	world = CrankGeneratorWorld.resolve()
	strips = {
		bindStrip(RIGHT_STRIP_NAME, world.rightSlider, 0, RIGHT_STRIP_SHARE),
		bindStrip(LEFT_STRIP_NAME, world.leftSlider, RIGHT_STRIP_SHARE, 1),
	}
	RunService.RenderStepped:Connect(onRenderStepped)
end

return ChargeMeterView
