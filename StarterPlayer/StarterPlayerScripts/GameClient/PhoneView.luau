local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PhoneConfig = require(Shared:WaitForChild("PhoneConfig"))
local PhoneWorld = require(Shared:WaitForChild("PhoneWorld"))

local RING_SOUND_NAME = "RingSound"
local PICKUP_SOUND_NAME = "PickupSound"

local PhoneView = {}

local world: PhoneWorld.Instances
local ringSound: Sound
local pickupSound: Sound

local function hasCall(attribute: string): boolean
	return typeof(world.box:GetAttribute(attribute)) == "string"
end

local function onRingingCallChanged()
	if hasCall(PhoneConfig.RINGING_CALL_ATTRIBUTE) then
		ringSound.TimePosition = 0
		ringSound:Play()
	else
		ringSound:Stop()
	end
end

local function onActiveCallChanged()
	if hasCall(PhoneConfig.ACTIVE_CALL_ATTRIBUTE) then
		pickupSound:Play()
	end
end

function PhoneView.start()
	world = PhoneWorld.resolve()
	ringSound = world.housing:WaitForChild(RING_SOUND_NAME) :: Sound
	pickupSound = world.housing:WaitForChild(PICKUP_SOUND_NAME) :: Sound
	world.box:GetAttributeChangedSignal(PhoneConfig.RINGING_CALL_ATTRIBUTE):Connect(onRingingCallChanged)
	world.box:GetAttributeChangedSignal(PhoneConfig.ACTIVE_CALL_ATTRIBUTE):Connect(onActiveCallChanged)
	onRingingCallChanged()
end

return PhoneView
