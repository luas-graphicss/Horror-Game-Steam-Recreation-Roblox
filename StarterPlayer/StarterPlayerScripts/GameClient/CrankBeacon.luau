local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrankCharge = require(Shared:WaitForChild("CrankCharge"))
local CrankGeneratorWorld = require(Shared:WaitForChild("CrankGeneratorWorld"))

local HIGHLIGHT_COLOR = Color3.fromRGB(255, 208, 150)
local FILL_TRANSPARENCY = 0.9
local OUTLINE_TRANSPARENCY = 0.15
local PULSE_DEPTH = 0.4
local PULSE_PERIOD = 2.2
local FADE_RESPONSIVENESS = 4
local HIDDEN_THRESHOLD = 0.01

local CrankBeacon = {}

local station: Model
local highlight: Highlight
local visibility = 0

local function onRenderStepped(dt: number)
	local isDark = not CrankCharge.isPowered(CrankCharge.current(station))
	visibility += ((if isDark then 1 else 0) - visibility) * (1 - math.exp(-FADE_RESPONSIVENESS * dt))
	highlight.Enabled = visibility > HIDDEN_THRESHOLD
	if not highlight.Enabled then
		return
	end
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 2 * math.pi / PULSE_PERIOD)
	local outline = OUTLINE_TRANSPARENCY + PULSE_DEPTH * pulse
	highlight.OutlineTransparency = 1 - (1 - outline) * visibility
	highlight.FillTransparency = 1 - (1 - FILL_TRANSPARENCY) * visibility
end

function CrankBeacon.start()
	station = CrankGeneratorWorld.resolve().station
	highlight = Instance.new("Highlight")
	highlight.Name = "CrankBeacon"
	highlight.Adornee = station
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = HIGHLIGHT_COLOR
	highlight.OutlineColor = HIGHLIGHT_COLOR
	highlight.Enabled = false
	highlight.Parent = station
	RunService.RenderStepped:Connect(onRenderStepped)
end

return CrankBeacon
