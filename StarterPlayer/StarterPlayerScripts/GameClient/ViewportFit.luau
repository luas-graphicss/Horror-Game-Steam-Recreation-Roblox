local Workspace = game:GetService("Workspace")

local REFERENCE_HEIGHT = 760
local MIN_SCALE = 0.6

local ViewportFit = {}

function ViewportFit.bind(scales: { UIScale })
	local viewportConnection: RBXScriptConnection? = nil
	local function refit()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local scale = math.clamp(camera.ViewportSize.Y / REFERENCE_HEIGHT, MIN_SCALE, 1)
		for _, uiScale in scales do
			uiScale.Scale = scale
		end
	end
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		local camera = Workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
		end
		refit()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

return ViewportFit
