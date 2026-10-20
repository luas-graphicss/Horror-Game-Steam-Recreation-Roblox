local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ToolCatalog = require(Shared:WaitForChild("ToolCatalog"))

local PLAYER_GUI_NAME = "PlayerGui"
local GUI_NAME = "ToolHotbar"
local BAR_NAME = "Bar"
local SLOT_TEMPLATE_NAME = "SlotTemplate"
local SLOT_STROKE_NAME = "UIStroke"
local ICON_NAME = "Icon"
local ASSETS_FOLDER_NAME = "Assets"
local MIN_TOOLS_TO_SHOW = 2
local ICON_FIELD_OF_VIEW = 30
local ICON_DIAGONAL_FILL = 0.85
local SQUARE_DIAGONAL_PER_SIDE = math.sqrt(2)
local SELECTED_STROKE_COLOR = Color3.fromRGB(150, 22, 22)
local SELECTED_STROKE_THICKNESS = 2
local SELECTED_STROKE_TRANSPARENCY = 0

type StrokeStyle = {
	color: Color3,
	thickness: number,
	transparency: number,
}

type Slot = {
	itemId: string,
	button: GuiButton,
	stroke: UIStroke,
}

type BoxAxis = {
	direction: Vector3,
	length: number,
}

local SELECTED_STROKE: StrokeStyle = {
	color = SELECTED_STROKE_COLOR,
	thickness = SELECTED_STROKE_THICKNESS,
	transparency = SELECTED_STROKE_TRANSPARENCY,
}

local ToolHotbar = {}

local player = Players.LocalPlayer
local assets = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME)
local bar: GuiObject
local idleStroke: StrokeStyle
local slots: { Slot } = {}

local function owns(itemId: string): boolean
	return player:GetAttribute(PlayerAttributes.ownedItem(itemId)) == true
end

local function strokeStyleOf(stroke: UIStroke): StrokeStyle
	return {
		color = stroke.Color,
		thickness = stroke.Thickness,
		transparency = stroke.Transparency,
	}
end

local function applyStrokeStyle(stroke: UIStroke, style: StrokeStyle)
	stroke.Color = style.color
	stroke.Thickness = style.thickness
	stroke.Transparency = style.transparency
end

local function boxAxesByLength(boxCFrame: CFrame, boxSize: Vector3): { BoxAxis }
	local axes: { BoxAxis } = {
		{ direction = boxCFrame.RightVector, length = boxSize.X },
		{ direction = boxCFrame.UpVector, length = boxSize.Y },
		{ direction = boxCFrame.LookVector, length = boxSize.Z },
	}
	table.sort(axes, function(first: BoxAxis, second: BoxAxis)
		return first.length > second.length
	end)
	return axes
end

local function frameIcon(viewport: ViewportFrame, template: Model)
	local model = template:Clone()
	model.Parent = viewport
	local boxCFrame, boxSize = model:GetBoundingBox()
	local axes = boxAxesByLength(boxCFrame, boxSize)
	local longest, middle, thinnest = axes[1], axes[2], axes[3]
	local halfViewTangent = math.tan(math.rad(ICON_FIELD_OF_VIEW) / 2)
	local distance = longest.length / (2 * SQUARE_DIAGONAL_PER_SIDE * halfViewTangent * ICON_DIAGONAL_FILL)
	local camera = Instance.new("Camera")
	camera.FieldOfView = ICON_FIELD_OF_VIEW
	camera.CFrame = CFrame.lookAt(
		boxCFrame.Position + thinnest.direction * distance,
		boxCFrame.Position,
		(longest.direction + middle.direction).Unit
	)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function render()
	bar.Visible = UserInputService.TouchEnabled and ToolCatalog.ownedCount(owns) >= MIN_TOOLS_TO_SHOW
	local equippedTool = player:GetAttribute(PlayerAttributes.EQUIPPED_TOOL)
	for _, slot in slots do
		slot.button.Visible = owns(slot.itemId)
		applyStrokeStyle(slot.stroke, if slot.itemId == equippedTool then SELECTED_STROKE else idleStroke)
	end
end

local function createSlot(template: GuiButton, itemId: string, order: number): Slot
	local button = template:Clone()
	button.Name = itemId
	button.LayoutOrder = order
	frameIcon(button:WaitForChild(ICON_NAME) :: ViewportFrame, assets:WaitForChild(ToolCatalog.viewmodelName(itemId)) :: Model)
	button.Activated:Connect(function()
		Remotes.EquipTool:FireServer(itemId)
	end)
	button.Parent = bar
	return {
		itemId = itemId,
		button = button,
		stroke = button:WaitForChild(SLOT_STROKE_NAME) :: UIStroke,
	}
end

function ToolHotbar.start()
	local gui = player:WaitForChild(PLAYER_GUI_NAME):WaitForChild(GUI_NAME)
	bar = gui:WaitForChild(BAR_NAME) :: GuiObject
	local template = bar:WaitForChild(SLOT_TEMPLATE_NAME) :: GuiButton
	idleStroke = strokeStyleOf(template:WaitForChild(SLOT_STROKE_NAME) :: UIStroke)
	for order, itemId in ToolCatalog.SWITCH_ORDER do
		table.insert(slots, createSlot(template, itemId, order))
		player:GetAttributeChangedSignal(PlayerAttributes.ownedItem(itemId)):Connect(render)
	end
	player:GetAttributeChangedSignal(PlayerAttributes.EQUIPPED_TOOL):Connect(render)
	render()
end

return ToolHotbar
