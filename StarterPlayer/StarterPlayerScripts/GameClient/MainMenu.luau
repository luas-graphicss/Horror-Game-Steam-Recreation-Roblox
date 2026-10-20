local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SaveStatus = require(Shared:WaitForChild("SaveStatus"))
local Crosshair = require(script.Parent:WaitForChild("Crosshair"))
local PlayerControls = require(script.Parent:WaitForChild("PlayerControls"))
local SettingsPanel = require(script.Parent:WaitForChild("SettingsPanel"))
local ViewportFit = require(script.Parent:WaitForChild("ViewportFit"))

local PLAYER_GUI_NAME = "PlayerGui"
local GUI_NAME = "MainMenu"
local BACKDROP_NAME = "Backdrop"
local CURTAIN_NAME = "Curtain"
local COLUMN_NAME = "Column"
local SETTINGS_PANEL_NAME = "SettingsPanel"
local BUTTONS_NAME = "Buttons"
local PLAY_BUTTON_NAME = "Play"
local SETTINGS_BUTTON_NAME = "Settings"
local BACK_BUTTON_NAME = "Back"
local STATUS_NAME = "Status"
local FIT_NAME = "Fit"
local GAMEPLAY_GUI_NAMES = { "HUD", "ResourceHud", "ToolHotbar" }
local GAMEPLAY_GUI_TIMEOUT = 10
local STATUS_MESSAGES: { [string]: string } = {
	[SaveStatus.LOADING] = "Carregando seu progresso...",
	[SaveStatus.RESUMED] = "Progresso salvo carregado.",
	[SaveStatus.FRESH] = "Primeiro turno. O progresso Ã© salvo automaticamente.",
	[SaveStatus.OFFLINE] = "Save indisponÃ­vel. O progresso desta sessÃ£o nÃ£o serÃ¡ salvo.",
}
local IDLE_COLOR = Color3.fromRGB(8, 8, 8)
local HOVER_COLOR = Color3.fromRGB(150, 22, 22)
local WAITING_TEXT_TRANSPARENCY = 0.6
local CURTAIN_CLOSE_DURATION = 0.6
local CURTAIN_OPEN_DURATION = 1
local DRIFT_DURATION = 30
local DRIFT_SCALE = 1.08

local MainMenu = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local backdrop: GuiObject
local curtain: Frame
local column: Frame
local settingsPanel: Frame
local playButton: TextButton
local statusLabel: TextLabel
local driftTween: Tween? = nil
local hasEntered = false

local function isReady(): boolean
	return SaveStatus.isReady(player:GetAttribute(PlayerAttributes.SAVE_STATUS))
end

local function renderStatus()
	local status = player:GetAttribute(PlayerAttributes.SAVE_STATUS)
	statusLabel.Text = if typeof(status) == "string" and STATUS_MESSAGES[status]
		then STATUS_MESSAGES[status]
		else STATUS_MESSAGES[SaveStatus.LOADING]
	playButton.TextTransparency = if isReady() then 0 else WAITING_TEXT_TRANSPARENCY
end

local function styleButton(button: TextButton)
	button.MouseEnter:Connect(function()
		if button ~= playButton or isReady() then
			button.BackgroundColor3 = HOVER_COLOR
		end
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = IDLE_COLOR
	end)
end

local function setGameplayGuisEnabled(isEnabled: boolean)
	local playerGui = player:WaitForChild(PLAYER_GUI_NAME)
	for _, name in GAMEPLAY_GUI_NAMES do
		local hud = playerGui:WaitForChild(name, GAMEPLAY_GUI_TIMEOUT)
		if hud and hud:IsA("ScreenGui") then
			hud.Enabled = isEnabled
		end
	end
end

local function showSettings(isShown: boolean)
	column.Visible = not isShown
	settingsPanel.Visible = isShown
end

local function fadeCurtain(target: number, duration: number)
	local tween = TweenService:Create(curtain, TweenInfo.new(duration, Enum.EasingStyle.Sine), { BackgroundTransparency = target })
	tween:Play()
	tween.Completed:Wait()
end

local function enterFactory()
	if hasEntered or not isReady() then
		return
	end
	hasEntered = true
	Remotes.BeginShift:FireServer()
	fadeCurtain(0, CURTAIN_CLOSE_DURATION)
	column.Visible = false
	settingsPanel.Visible = false
	backdrop.Visible = false
	if driftTween then
		driftTween:Cancel()
	end
	Crosshair.setCursorVisible(false)
	PlayerControls.setEnabled(true)
	setGameplayGuisEnabled(true)
	fadeCurtain(1, CURTAIN_OPEN_DURATION)
	gui.Enabled = false
end

local function open()
	gui.Enabled = true
	curtain.BackgroundTransparency = 1
	showSettings(false)
	Crosshair.setCursorVisible(true)
	driftTween = TweenService:Create(
		backdrop,
		TweenInfo.new(DRIFT_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = UDim2.fromScale(DRIFT_SCALE, DRIFT_SCALE) }
	)
	driftTween:Play()
	PlayerControls.setEnabled(false)
	setGameplayGuisEnabled(false)
end

function MainMenu.start()
	gui = player:WaitForChild(PLAYER_GUI_NAME):WaitForChild(GUI_NAME) :: ScreenGui
	backdrop = gui:WaitForChild(BACKDROP_NAME) :: GuiObject
	curtain = gui:WaitForChild(CURTAIN_NAME) :: Frame
	column = gui:WaitForChild(COLUMN_NAME) :: Frame
	settingsPanel = gui:WaitForChild(SETTINGS_PANEL_NAME) :: Frame
	local buttons = column:WaitForChild(BUTTONS_NAME)
	playButton = buttons:WaitForChild(PLAY_BUTTON_NAME) :: TextButton
	local settingsButton = buttons:WaitForChild(SETTINGS_BUTTON_NAME) :: TextButton
	local backButton = settingsPanel:WaitForChild(BACK_BUTTON_NAME) :: TextButton
	statusLabel = column:WaitForChild(STATUS_NAME) :: TextLabel
	ViewportFit.bind({ column:WaitForChild(FIT_NAME) :: UIScale, settingsPanel:WaitForChild(FIT_NAME) :: UIScale })
	SettingsPanel.bind(settingsPanel)
	for _, button in { playButton, settingsButton, backButton } do
		styleButton(button)
	end
	playButton.Activated:Connect(enterFactory)
	settingsButton.Activated:Connect(function()
		showSettings(true)
	end)
	backButton.Activated:Connect(function()
		showSettings(false)
	end)
	player:GetAttributeChangedSignal(PlayerAttributes.SAVE_STATUS):Connect(renderStatus)
	renderStatus()
	open()
end

return MainMenu
