local Players = game:GetService("Players")

local PLAYER_SCRIPTS_NAME = "PlayerScripts"
local PLAYER_MODULE_NAME = "PlayerModule"

local PlayerControls = {}

local controls = nil

local function resolveControls()
	if not controls then
		local playerModule = Players.LocalPlayer:WaitForChild(PLAYER_SCRIPTS_NAME):WaitForChild(PLAYER_MODULE_NAME) :: ModuleScript
		controls = require(playerModule):GetControls()
	end
	return controls
end

function PlayerControls.setEnabled(isEnabled: boolean)
	local activeControls = resolveControls()
	if isEnabled then
		activeControls:Enable()
	else
		activeControls:Disable()
	end
end

return PlayerControls
