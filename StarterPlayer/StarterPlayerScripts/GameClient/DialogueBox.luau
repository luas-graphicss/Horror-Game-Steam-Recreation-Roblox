local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Crosshair = require(script.Parent:WaitForChild("Crosshair"))

local PLAYER_GUI_NAME = "PlayerGui"
local GUI_NAME = "TrombyDialogue"
local PANEL_NAME = "Panel"
local NAME_BOX_NAME = "NameBox"
local NAME_LABEL_NAME = "Label"
local SPEECH_BOX_NAME = "SpeechBox"
local SPEECH_LABEL_NAME = "Line"
local CONTINUE_BUTTON_NAME = "Continue"
local CHOICES_NAME = "Choices"
local CHOICE_TEMPLATE_NAME = "ChoiceTemplate"
local CHOICE_LAYOUT_NAME = "ChoiceLayout"
local CONTINUE_ACTION_NAME = "DialogueContinue"
local CONTINUE_KEYS = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA }
local IDLE_COLOR = Color3.fromRGB(8, 8, 8)
local ACTIVE_COLOR = Color3.fromRGB(150, 22, 22)

local DialogueBox = {}

local panel: Frame
local nameLabel: TextLabel
local speechLabel: TextLabel
local continueButton: TextButton
local choicesFrame: Frame
local choiceTemplate: TextButton
local choiceGap: number
local continuedEvent = Instance.new("BindableEvent")
local isHovered = false
local isPressed = false
local revealTween: Tween? = nil

local function paintContinue()
	continueButton.BackgroundColor3 = if isHovered or isPressed then ACTIVE_COLOR else IDLE_COLOR
end

local function setPressed(pressed: boolean)
	isPressed = pressed
	paintContinue()
end

local function setHovered(hovered: boolean)
	isHovered = hovered
	if not hovered then
		isPressed = false
	end
	paintContinue()
end

local function requestContinue()
	if continueButton.Visible then
		continuedEvent:Fire()
	end
end

local function onContinueAction(_actionName: string, state: Enum.UserInputState): Enum.ContextActionResult
	setPressed(state == Enum.UserInputState.Begin)
	if state == Enum.UserInputState.Begin then
		requestContinue()
	end
	return Enum.ContextActionResult.Sink
end

local function cancelReveal()
	if revealTween then
		revealTween:Cancel()
		revealTween = nil
	end
end

local function createChoiceButton(label: string, order: number, count: number, onChosen: () -> ()): TextButton
	local button = choiceTemplate:Clone()
	button.Text = label
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 1 / count, -choiceGap * (count - 1) / count)
	button.Visible = true
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = ACTIVE_COLOR
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = IDLE_COLOR
	end)
	button.Activated:Connect(onChosen)
	button.Parent = choicesFrame
	return button
end

function DialogueBox.open(speakerName: string)
	nameLabel.Text = speakerName
	speechLabel.Text = ""
	panel.Visible = true
	ContextActionService:BindActionAtPriority(
		CONTINUE_ACTION_NAME,
		onContinueAction,
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(CONTINUE_KEYS)
	)
end

function DialogueBox.say(text: string, revealDuration: number, canContinue: boolean)
	cancelReveal()
	speechLabel.Text = text
	speechLabel.MaxVisibleGraphemes = 0
	continueButton.Visible = canContinue
	Crosshair.setCursorVisible(canContinue)
	local tween = TweenService:Create(
		speechLabel,
		TweenInfo.new(revealDuration, Enum.EasingStyle.Linear),
		{ MaxVisibleGraphemes = utf8.len(text) or #text }
	)
	revealTween = tween
	tween:Play()
end

function DialogueBox.awaitContinue()
	continuedEvent.Event:Wait()
end

function DialogueBox.choose(labels: { string }): number
	local chosenEvent = Instance.new("BindableEvent")
	local buttons = {}
	for index, label in labels do
		table.insert(buttons, createChoiceButton(label, index, #labels, function()
			chosenEvent:Fire(index)
		end))
	end
	continueButton.Visible = false
	choicesFrame.Visible = true
	Crosshair.setCursorVisible(true)
	local chosenIndex = chosenEvent.Event:Wait()
	choicesFrame.Visible = false
	Crosshair.setCursorVisible(false)
	for _, button in buttons do
		button:Destroy()
	end
	chosenEvent:Destroy()
	return chosenIndex
end

function DialogueBox.close()
	ContextActionService:UnbindAction(CONTINUE_ACTION_NAME)
	cancelReveal()
	panel.Visible = false
	setHovered(false)
	Crosshair.setCursorVisible(false)
end

function DialogueBox.start()
	local gui = Players.LocalPlayer:WaitForChild(PLAYER_GUI_NAME):WaitForChild(GUI_NAME)
	panel = gui:WaitForChild(PANEL_NAME) :: Frame
	nameLabel = panel:WaitForChild(NAME_BOX_NAME):WaitForChild(NAME_LABEL_NAME) :: TextLabel
	speechLabel = panel:WaitForChild(SPEECH_BOX_NAME):WaitForChild(SPEECH_LABEL_NAME) :: TextLabel
	continueButton = panel:WaitForChild(CONTINUE_BUTTON_NAME) :: TextButton
	choicesFrame = panel:WaitForChild(CHOICES_NAME) :: Frame
	choiceTemplate = choicesFrame:WaitForChild(CHOICE_TEMPLATE_NAME) :: TextButton
	choiceGap = (choicesFrame:WaitForChild(CHOICE_LAYOUT_NAME) :: UIListLayout).Padding.Offset
	panel.Visible = false
	choicesFrame.Visible = false
	continueButton.MouseEnter:Connect(function()
		setHovered(true)
	end)
	continueButton.MouseLeave:Connect(function()
		setHovered(false)
	end)
	continueButton.MouseButton1Down:Connect(function()
		setPressed(true)
	end)
	continueButton.MouseButton1Up:Connect(function()
		setPressed(false)
	end)
	continueButton.Activated:Connect(requestContinue)
end

return DialogueBox
