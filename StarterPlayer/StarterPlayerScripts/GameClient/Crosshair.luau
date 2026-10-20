local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local PLAYER_GUI_NAME = "PlayerGui"
local HUD_NAME = "HUD"
local DOT_NAME = "Crosshair"
local GRAB_HAND_NAME = "GrabHand"

local Crosshair = {}

local dot: GuiObject? = nil
local grabHand: GuiObject? = nil

function Crosshair.setCursorVisible(isVisible: boolean)
	UserInputService.MouseIconEnabled = isVisible
end

function Crosshair.showGrabHand(isShown: boolean)
	if dot and grabHand then
		dot.Visible = not isShown
		grabHand.Visible = isShown
	end
end

function Crosshair.start()
	Crosshair.setCursorVisible(false)
	local hud = Players.LocalPlayer:WaitForChild(PLAYER_GUI_NAME):WaitForChild(HUD_NAME)
	dot = hud:WaitForChild(DOT_NAME) :: GuiObject
	grabHand = hud:WaitForChild(GRAB_HAND_NAME) :: GuiObject
end

return Crosshair
