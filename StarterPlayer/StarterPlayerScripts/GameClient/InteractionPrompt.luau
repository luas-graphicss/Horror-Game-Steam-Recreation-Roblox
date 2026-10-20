local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PLAYER_GUI_NAME = "PlayerGui"
local HUD_NAME = "HUD"
local PROMPT_NAME = "InteractionPrompt"
local TITLE_NAME = "Title"
local DESCRIPTION_NAME = "Description"
local UPGRADE_LINE_NAME = "UpgradeLine"
local ACTION_NAME = "Action"
local RESPONSIVE_SCALE_NAME = "ResponsiveScale"
local UPGRADE_LINE_FORMAT = "%s -> %s"
local REFERENCE_VIEWPORT_HEIGHT = 1080
local MIN_PROMPT_SCALE = 0.8
local MAX_PROMPT_SCALE = 1.4
local HIGHLIGHT_COLOR = Color3.fromRGB(236, 232, 222)
local HIGHLIGHT_FILL_TRANSPARENCY = 0.88
local HIGHLIGHT_OUTLINE_TRANSPARENCY = 0.15
local UNAVAILABLE_ACTION_COLOR = Color3.fromRGB(226, 74, 62)
local READY_ACTION_COLOR = Color3.fromRGB(120, 220, 110)

export type Upgrade = {
	from: string,
	to: string,
}

export type Content = {
	title: string?,
	titleColor: Color3?,
	description: string?,
	upgrade: Upgrade?,
	action: string?,
	isActionUnavailable: boolean?,
	isActionReady: boolean?,
}

type PromptLabels = {
	frame: Frame,
	title: TextLabel,
	description: TextLabel,
	upgradeLine: TextLabel,
	action: TextLabel,
}

local InteractionPrompt = {}

local highlight = Instance.new("Highlight")
highlight.FillColor = HIGHLIGHT_COLOR
highlight.OutlineColor = HIGHLIGHT_COLOR
highlight.FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY
highlight.OutlineTransparency = HIGHLIGHT_OUTLINE_TRANSPARENCY
highlight.DepthMode = Enum.HighlightDepthMode.Occluded

local shownTarget: Instance? = nil
local shownContent: Content? = nil
local labels: PromptLabels? = nil
local defaultTitleColor: Color3
local availableActionColor: Color3

local function upgradeLineText(upgrade: Upgrade): string
	return string.format(UPGRADE_LINE_FORMAT, upgrade.from, upgrade.to)
end

local function actionColor(content: Content): Color3
	if content.isActionUnavailable then
		return UNAVAILABLE_ACTION_COLOR
	end
	return if content.isActionReady then READY_ACTION_COLOR else availableActionColor
end

local function render()
	if not labels then
		return
	end
	labels.frame.Visible = shownTarget ~= nil
	if shownContent then
		local upgrade = shownContent.upgrade
		labels.title.Visible = shownContent.title ~= nil
		labels.title.Text = shownContent.title or ""
		labels.title.TextColor3 = shownContent.titleColor or defaultTitleColor
		labels.description.Visible = shownContent.description ~= nil
		labels.description.Text = shownContent.description or ""
		labels.upgradeLine.Visible = upgrade ~= nil
		labels.upgradeLine.Text = if upgrade then upgradeLineText(upgrade) else ""
		labels.action.Visible = shownContent.action ~= nil
		labels.action.Text = shownContent.action or ""
		labels.action.TextColor3 = actionColor(shownContent)
	end
end

function InteractionPrompt.show(target: Instance, content: Content)
	if target == shownTarget and content == shownContent then
		return
	end
	shownTarget = target
	shownContent = content
	highlight.Adornee = target
	highlight.Parent = target
	render()
end

function InteractionPrompt.hide(target: Instance)
	if target ~= shownTarget then
		return
	end
	shownTarget = nil
	shownContent = nil
	highlight.Adornee = nil
	highlight.Parent = nil
	render()
end

function InteractionPrompt.start()
	local frame = Players.LocalPlayer:WaitForChild(PLAYER_GUI_NAME):WaitForChild(HUD_NAME):WaitForChild(PROMPT_NAME) :: Frame
	local promptScale = frame:WaitForChild(RESPONSIVE_SCALE_NAME) :: UIScale
	local function updatePromptScale()
		local viewportHeight = Workspace.CurrentCamera.ViewportSize.Y
		promptScale.Scale = math.clamp(viewportHeight / REFERENCE_VIEWPORT_HEIGHT, MIN_PROMPT_SCALE, MAX_PROMPT_SCALE)
	end
	labels = {
		frame = frame,
		title = frame:WaitForChild(TITLE_NAME) :: TextLabel,
		description = frame:WaitForChild(DESCRIPTION_NAME) :: TextLabel,
		upgradeLine = frame:WaitForChild(UPGRADE_LINE_NAME) :: TextLabel,
		action = frame:WaitForChild(ACTION_NAME) :: TextLabel,
	}
	defaultTitleColor = labels.title.TextColor3
	availableActionColor = labels.action.TextColor3
	updatePromptScale()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePromptScale)
	render()
end

return InteractionPrompt
