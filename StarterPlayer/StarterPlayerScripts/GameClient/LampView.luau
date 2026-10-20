local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrankCharge = require(Shared:WaitForChild("CrankCharge"))
local CrankGeneratorWorld = require(Shared:WaitForChild("CrankGeneratorWorld"))

local LAMP_TAG = "PoweredLamp"
local GLOW_TAG = "PoweredGlow"
local LAMP_BULB_NAME = "LampBulb"
local LAMP_LIGHT_NAME = "LampLight"
local POWER_UP_SOUND_NAME = "PowerUpSound"
local POWER_DOWN_SOUND_NAME = "PowerDownSound"
local FAULTY_ATTRIBUTE = "Faulty"
local LIT_BULB_MATERIAL = Enum.Material.Neon
local LIT_BULB_COLOR = Color3.fromRGB(255, 196, 122)
local DIM_BULB_COLOR = Color3.fromRGB(96, 52, 20)
local LIT_FOG_COLOR = Color3.fromRGB(26, 20, 13)
local UNLIT_SURFACE_LIGHT_INFLUENCE = 1
local LOW_CHARGE_FRACTION = 0.25
local LOW_CHARGE_MIN_INTENSITY = 0.35
local STEADY_FLICKER_DEPTH = 0.1
local LOW_CHARGE_FLICKER_DEPTH = 0.9
local FLICKER_SPEED = 8
local FLICKER_NOISE_SEED = 0.5
local FAULT_BURST_SPEED = 0.9
local FAULT_BURST_LEVEL = -0.1
local FAULT_FLICKER_SPEED = 11
local FAULT_FLICKER_LAYER = 0.5
local FAULT_DROPOUT_LEVEL = 0
local FAULT_DROPOUT_INTENSITY = 0.03

type Lamp = {
	bulb: BasePart,
	light: Light,
	ratedBrightness: number,
	unlitMaterial: Enum.Material,
	unlitColor: Color3,
	powerUpSound: Sound,
	powerDownSound: Sound,
	isFaulty: boolean,
	faultSeed: number,
}

type LightGlow = {
	light: Light,
	ratedBrightness: number,
}

type SurfaceGlow = {
	surface: SurfaceGui,
	ratedBrightness: number,
	ratedLightInfluence: number,
}

local LampView = {}

local station: Model
local unlitFogColor: Color3
local isLit = false
local lamps: { [Instance]: Lamp } = {}
local lightGlows: { [Instance]: LightGlow } = {}
local surfaceGlows: { [Instance]: SurfaceGlow } = {}

local function lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

local function intensityAt(fraction: number, now: number): number
	local stability = math.clamp(fraction / LOW_CHARGE_FRACTION, 0, 1)
	local steadyIntensity = lerp(LOW_CHARGE_MIN_INTENSITY, 1, stability)
	local flickerDepth = lerp(LOW_CHARGE_FLICKER_DEPTH, STEADY_FLICKER_DEPTH, stability)
	local flicker = math.noise(now * FLICKER_SPEED, FLICKER_NOISE_SEED)
	return math.clamp(steadyIntensity * (1 + flicker * flickerDepth), 0, 1)
end

local function faultIntensity(lamp: Lamp, now: number): number
	local isStuttering = math.noise(now * FAULT_BURST_SPEED, lamp.faultSeed) > FAULT_BURST_LEVEL
	local isDropped = math.noise(now * FAULT_FLICKER_SPEED, lamp.faultSeed, FAULT_FLICKER_LAYER) < FAULT_DROPOUT_LEVEL
	return if isStuttering and isDropped then FAULT_DROPOUT_INTENSITY else 1
end

local function powerLamp(lamp: Lamp)
	lamp.light.Enabled = isLit
	lamp.bulb.Material = if isLit then LIT_BULB_MATERIAL else lamp.unlitMaterial
	if not isLit then
		lamp.bulb.Color = lamp.unlitColor
	end
end

local function powerSurface(glow: SurfaceGlow)
	glow.surface.LightInfluence = if isLit then glow.ratedLightInfluence else UNLIT_SURFACE_LIGHT_INFLUENCE
end

local function setLit(lit: boolean)
	isLit = lit
	for _, lamp in lamps do
		powerLamp(lamp)
	end
	for _, glow in lightGlows do
		glow.light.Enabled = lit
	end
	for _, glow in surfaceGlows do
		powerSurface(glow)
	end
	if not lit then
		Lighting.FogColor = unlitFogColor
	end
end

local function announcePowerChange(lit: boolean)
	for _, lamp in lamps do
		local starting = if lit then lamp.powerUpSound else lamp.powerDownSound
		local stopping = if lit then lamp.powerDownSound else lamp.powerUpSound
		stopping:Stop()
		starting:Play()
	end
end

local function shine(intensity: number, now: number)
	for _, lamp in lamps do
		local lampIntensity = if lamp.isFaulty then intensity * faultIntensity(lamp, now) else intensity
		lamp.light.Brightness = lamp.ratedBrightness * lampIntensity
		lamp.bulb.Color = DIM_BULB_COLOR:Lerp(LIT_BULB_COLOR, lampIntensity)
	end
	for _, glow in lightGlows do
		glow.light.Brightness = glow.ratedBrightness * intensity
	end
	for _, glow in surfaceGlows do
		glow.surface.Brightness = glow.ratedBrightness * intensity
	end
	Lighting.FogColor = unlitFogColor:Lerp(LIT_FOG_COLOR, intensity)
end

local function onRenderStepped()
	local charge = CrankCharge.current(station)
	local hasCharge = CrankCharge.isPowered(charge)
	if hasCharge ~= isLit then
		setLit(hasCharge)
		announcePowerChange(hasCharge)
	end
	if isLit then
		local now = os.clock()
		shine(intensityAt(CrankCharge.fraction(charge), now), now)
	end
end

local function bindLamp(rig: Instance)
	if lamps[rig] then
		return
	end
	local bulb = rig:WaitForChild(LAMP_BULB_NAME) :: BasePart
	local light = bulb:WaitForChild(LAMP_LIGHT_NAME) :: Light
	local lamp: Lamp = {
		bulb = bulb,
		light = light,
		ratedBrightness = light.Brightness,
		unlitMaterial = bulb.Material,
		unlitColor = bulb.Color,
		powerUpSound = bulb:WaitForChild(POWER_UP_SOUND_NAME) :: Sound,
		powerDownSound = bulb:WaitForChild(POWER_DOWN_SOUND_NAME) :: Sound,
		isFaulty = rig:GetAttribute(FAULTY_ATTRIBUTE) == true,
		faultSeed = bulb.Position.X + bulb.Position.Z,
	}
	if lamps[rig] or not rig:HasTag(LAMP_TAG) then
		return
	end
	lamps[rig] = lamp
	powerLamp(lamp)
end

local function bindGlow(instance: Instance)
	if instance:IsA("Light") and not lightGlows[instance] then
		lightGlows[instance] = { light = instance, ratedBrightness = instance.Brightness }
		instance.Enabled = isLit
	elseif instance:IsA("SurfaceGui") and not surfaceGlows[instance] then
		local glow: SurfaceGlow = {
			surface = instance,
			ratedBrightness = instance.Brightness,
			ratedLightInfluence = instance.LightInfluence,
		}
		surfaceGlows[instance] = glow
		powerSurface(glow)
	end
end

local function unbindGlow(instance: Instance)
	lightGlows[instance] = nil
	surfaceGlows[instance] = nil
end

local function unbindLamp(rig: Instance)
	lamps[rig] = nil
end

function LampView.start()
	station = CrankGeneratorWorld.resolve().station
	unlitFogColor = Lighting.FogColor
	isLit = CrankCharge.isPowered(CrankCharge.current(station))
	CollectionService:GetInstanceAddedSignal(LAMP_TAG):Connect(bindLamp)
	CollectionService:GetInstanceRemovedSignal(LAMP_TAG):Connect(unbindLamp)
	CollectionService:GetInstanceAddedSignal(GLOW_TAG):Connect(bindGlow)
	CollectionService:GetInstanceRemovedSignal(GLOW_TAG):Connect(unbindGlow)
	for _, rig in CollectionService:GetTagged(LAMP_TAG) do
		task.spawn(bindLamp, rig)
	end
	for _, instance in CollectionService:GetTagged(GLOW_TAG) do
		bindGlow(instance)
	end
	RunService.RenderStepped:Connect(onRenderStepped)
end

return LampView
