local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoltStationConfig = require(Shared:WaitForChild("BoltStationConfig"))

local BODY_NAME = "Body"
local NUT_NAME = "Nut"
local GOLD_TINT = Color3.fromRGB(255, 196, 92)
local GLOW_COLOR = Color3.fromRGB(255, 180, 70)
local GLOW_BRIGHTNESS = 0.8
local GLOW_RANGE = 5

local RareBoltView = {}

local function tint(part: Instance)
	local finish = part:FindFirstChildOfClass("SurfaceAppearance")
	if finish then
		finish.Color = GOLD_TINT
	end
end

local function gild(bolt: Instance)
	if bolt:GetAttribute(BoltStationConfig.RARE_ATTRIBUTE) ~= true then
		return
	end
	local body = bolt:WaitForChild(BODY_NAME)
	tint(body)
	tint(bolt:WaitForChild(NUT_NAME))
	local glow = Instance.new("PointLight")
	glow.Color = GLOW_COLOR
	glow.Brightness = GLOW_BRIGHTNESS
	glow.Range = GLOW_RANGE
	glow.Parent = body
end

function RareBoltView.start()
	CollectionService:GetInstanceAddedSignal(BoltStationConfig.BOLT_TAG):Connect(gild)
	for _, bolt in CollectionService:GetTagged(BoltStationConfig.BOLT_TAG) do
		task.spawn(gild, bolt)
	end
end

return RareBoltView
