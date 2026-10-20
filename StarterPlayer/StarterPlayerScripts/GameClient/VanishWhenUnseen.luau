local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LOOK_AWAY_ANGLE = 100
local LOOK_AWAY_DOT = math.cos(math.rad(LOOK_AWAY_ANGLE))

local VanishWhenUnseen = {}

local function hasLookedAway(model: Model): boolean
	local view = Workspace.CurrentCamera.CFrame
	local towardModel = (model:GetPivot().Position - view.Position).Unit
	return view.LookVector:Dot(towardModel) < LOOK_AWAY_DOT
end

local function hideLocally(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
		end
	end
end

function VanishWhenUnseen.watch(model: Model, onVanished: () -> ())
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			connection:Disconnect()
		elseif hasLookedAway(model) then
			connection:Disconnect()
			hideLocally(model)
			onVanished()
		end
	end)
end

return VanishWhenUnseen
