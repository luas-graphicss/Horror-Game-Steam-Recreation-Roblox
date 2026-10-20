local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RENDER_STEP_NAME = "PlayerGlow"
local LIGHT_COLOR = Color3.fromRGB(255, 176, 96)
local LIGHT_BRIGHTNESS = 0.6
local LIGHT_RANGE = 11
local CAMERA_OFFSET = Vector3.new(0, 0.35, 0.6)

local PlayerGlow = {}

function PlayerGlow.start()
	local anchor = Instance.new("Attachment")
	anchor.Name = "PlayerGlow"
	local light = Instance.new("PointLight")
	light.Color = LIGHT_COLOR
	light.Brightness = LIGHT_BRIGHTNESS
	light.Range = LIGHT_RANGE
	light.Shadows = true
	light.Parent = anchor
	anchor.Parent = Workspace.Terrain
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local camera = Workspace.CurrentCamera
		if camera then
			anchor.WorldPosition = camera.CFrame:PointToWorldSpace(CAMERA_OFFSET)
		end
	end)
end

return PlayerGlow
