local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmployeeRoster = require(Shared:WaitForChild("EmployeeRoster"))
local Money = require(Shared:WaitForChild("Money"))
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local ProductionLineConfig = require(Shared:WaitForChild("ProductionLineConfig"))
local ProductionLineSlots = require(Shared:WaitForChild("ProductionLineSlots"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))
local Crosshair = require(script.Parent:WaitForChild("Crosshair"))

local PLAYER_GUI_NAME = "PlayerGui"
local GUI_NAME = "HiringDialogue"
local PANEL_NAME = "Panel"
local PROFILE_BOX_NAME = "ProfileBox"
local ACTION_BOX_NAME = "ActionBox"
local EMPLOYEE_NAME_LABEL_NAME = "EmployeeName"
local SPEED_LABEL_NAME = "Speed"
local SIGNING_FEE_LABEL_NAME = "SigningFee"
local PROFILE_LABEL_NAME = "Profile"
local BOLT_BUTTON_NAME = "BoltButton"
local HEART_BUTTON_NAME = "HeartButton"
local CLOSE_BUTTON_NAME = "Close"
local BUTTON_TITLE_NAME = "Title"
local BUTTON_STATUS_NAME = "Status"
local CLOSE_ACTION_NAME = "HiringDialogueClose"
local CLOSE_KEYS = { Enum.KeyCode.ButtonB }
local SPEED_FORMAT = "Velocidade: %.2fx"
local SIGNING_FEE_FORMAT = "Assinatura: %sR$"
local AVAILABLE_STATUS = "DisponÃ­vel"
local NO_FREE_LINE_STATUS = "Sem esteira livre"
local NEEDS_HAMMER_STATUS = "Requer martelo"
local INSUFFICIENT_FUNDS_STATUS = "Saldo insuficiente"
local IDLE_COLOR = Color3.fromRGB(8, 8, 8)
local ACTIVE_COLOR = Color3.fromRGB(150, 22, 22)
local UNAFFORDABLE_COLOR = Color3.fromRGB(226, 74, 62)
local AVAILABLE_TEXT_TRANSPARENCY = 0
local UNAVAILABLE_TEXT_TRANSPARENCY = 0.55

type AreaButton = {
	area: string,
	button: TextButton,
	title: TextLabel,
	status: TextLabel,
	isAvailable: boolean,
	isHovered: boolean,
}

local HiringDialogue = {}

local player = Players.LocalPlayer
local panel: Frame
local employeeNameLabel: TextLabel
local speedLabel: TextLabel
local signingFeeLabel: TextLabel
local profileLabel: TextLabel
local closeButton: TextButton
local feeColor: Color3
local areaButtons: { AreaButton } = {}
local isOpen = false
local hiresWhenOpened = 0

local function readNumber(attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

local function ownsHammer(): boolean
	return player:GetAttribute(PlayerAttributes.ownedItem(ShopCatalog.HAMMER_ITEM_ID)) == true
end

local function statusOf(area: string, canAfford: boolean): string
	if area == ProductionLineConfig.HEART_AREA and not ownsHammer() then
		return NEEDS_HAMMER_STATUS
	elseif not ProductionLineSlots.freeLine(area) then
		return NO_FREE_LINE_STATUS
	elseif not canAfford then
		return INSUFFICIENT_FUNDS_STATUS
	end
	return AVAILABLE_STATUS
end

local function paintAreaButton(entry: AreaButton)
	local textTransparency = if entry.isAvailable then AVAILABLE_TEXT_TRANSPARENCY else UNAVAILABLE_TEXT_TRANSPARENCY
	entry.button.BackgroundColor3 = if entry.isAvailable and entry.isHovered then ACTIVE_COLOR else IDLE_COLOR
	entry.title.TextTransparency = textTransparency
	entry.status.TextTransparency = textTransparency
end

local function render()
	local hiredCount = readNumber(PlayerAttributes.EMPLOYEES_HIRED)
	local candidate = EmployeeRoster.candidateAt(hiredCount)
	local priceCents = EmployeeRoster.hirePriceCents(hiredCount)
	local canAfford = readNumber(PlayerAttributes.BALANCE_CENTS) >= priceCents
	employeeNameLabel.Text = candidate.name
	speedLabel.Text = string.format(SPEED_FORMAT, candidate.speed)
	signingFeeLabel.Text = string.format(SIGNING_FEE_FORMAT, Money.format(priceCents))
	signingFeeLabel.TextColor3 = if canAfford then feeColor else UNAFFORDABLE_COLOR
	profileLabel.Text = candidate.profile
	for _, entry in areaButtons do
		local status = statusOf(entry.area, canAfford)
		entry.isAvailable = status == AVAILABLE_STATUS
		entry.status.Text = status
		paintAreaButton(entry)
	end
end

local function refresh()
	if isOpen then
		render()
	end
end

local function onCloseAction(_actionName: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		HiringDialogue.close()
	end
	return Enum.ContextActionResult.Sink
end

local function onHiresChanged()
	if isOpen and readNumber(PlayerAttributes.EMPLOYEES_HIRED) > hiresWhenOpened then
		HiringDialogue.close()
	end
end

local function requestHire(entry: AreaButton)
	if isOpen and entry.isAvailable then
		Remotes.HireEmployee:FireServer(entry.area)
	end
end

local function setHovered(entry: AreaButton, isHovered: boolean)
	entry.isHovered = isHovered
	paintAreaButton(entry)
end

local function bindAreaButton(button: TextButton, area: string): AreaButton
	local entry: AreaButton = {
		area = area,
		button = button,
		title = button:WaitForChild(BUTTON_TITLE_NAME) :: TextLabel,
		status = button:WaitForChild(BUTTON_STATUS_NAME) :: TextLabel,
		isAvailable = false,
		isHovered = false,
	}
	button.MouseEnter:Connect(function()
		setHovered(entry, true)
	end)
	button.MouseLeave:Connect(function()
		setHovered(entry, false)
	end)
	button.Activated:Connect(function()
		requestHire(entry)
	end)
	return entry
end

local function bindCloseButton()
	closeButton.MouseEnter:Connect(function()
		closeButton.BackgroundColor3 = ACTIVE_COLOR
	end)
	closeButton.MouseLeave:Connect(function()
		closeButton.BackgroundColor3 = IDLE_COLOR
	end)
	closeButton.Activated:Connect(function()
		HiringDialogue.close()
	end)
end

local function watchLine(line: Instance)
	line:GetAttributeChangedSignal(ProductionLineConfig.EMPLOYEE_ATTRIBUTE):Connect(refresh)
end

function HiringDialogue.isOpen(): boolean
	return isOpen
end

function HiringDialogue.open()
	if isOpen then
		return
	end
	isOpen = true
	hiresWhenOpened = readNumber(PlayerAttributes.EMPLOYEES_HIRED)
	render()
	panel.Visible = true
	closeButton.Modal = true
	Crosshair.setCursorVisible(true)
	ContextActionService:BindActionAtPriority(
		CLOSE_ACTION_NAME,
		onCloseAction,
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(CLOSE_KEYS)
	)
end

function HiringDialogue.close()
	if not isOpen then
		return
	end
	isOpen = false
	panel.Visible = false
	closeButton.Modal = false
	closeButton.BackgroundColor3 = IDLE_COLOR
	Crosshair.setCursorVisible(false)
	ContextActionService:UnbindAction(CLOSE_ACTION_NAME)
	for _, entry in areaButtons do
		setHovered(entry, false)
	end
end

function HiringDialogue.start()
	local gui = player:WaitForChild(PLAYER_GUI_NAME):WaitForChild(GUI_NAME)
	panel = gui:WaitForChild(PANEL_NAME) :: Frame
	local profileBox = panel:WaitForChild(PROFILE_BOX_NAME)
	local actionBox = panel:WaitForChild(ACTION_BOX_NAME)
	employeeNameLabel = profileBox:WaitForChild(EMPLOYEE_NAME_LABEL_NAME) :: TextLabel
	speedLabel = profileBox:WaitForChild(SPEED_LABEL_NAME) :: TextLabel
	signingFeeLabel = profileBox:WaitForChild(SIGNING_FEE_LABEL_NAME) :: TextLabel
	profileLabel = profileBox:WaitForChild(PROFILE_LABEL_NAME) :: TextLabel
	closeButton = panel:WaitForChild(CLOSE_BUTTON_NAME) :: TextButton
	feeColor = signingFeeLabel.TextColor3
	areaButtons = {
		bindAreaButton(actionBox:WaitForChild(BOLT_BUTTON_NAME) :: TextButton, ProductionLineConfig.BOLT_AREA),
		bindAreaButton(actionBox:WaitForChild(HEART_BUTTON_NAME) :: TextButton, ProductionLineConfig.HEART_AREA),
	}
	panel.Visible = false
	bindCloseButton()
	player:GetAttributeChangedSignal(PlayerAttributes.BALANCE_CENTS):Connect(refresh)
	player:GetAttributeChangedSignal(PlayerAttributes.ownedItem(ShopCatalog.HAMMER_ITEM_ID)):Connect(refresh)
	player:GetAttributeChangedSignal(PlayerAttributes.EMPLOYEES_HIRED):Connect(onHiresChanged)
	CollectionService:GetInstanceAddedSignal(ProductionLineConfig.TAG):Connect(watchLine)
	for _, line in CollectionService:GetTagged(ProductionLineConfig.TAG) do
		watchLine(line)
	end
end

return HiringDialogue
