local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrankCharge = require(Shared:WaitForChild("CrankCharge"))
local CrankGeneratorWorld = require(Shared:WaitForChild("CrankGeneratorWorld"))
local Money = require(Shared:WaitForChild("Money"))
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))

local PLAYER_GUI_NAME = "PlayerGui"
local HUD_NAME = "ResourceHud"
local STATS_NAME = "Stats"
local MONEY_ROW_NAME = "Money"
local ENERGY_ROW_NAME = "Energy"
local MEAT_ROW_NAME = "Meat"
local BLOOD_ROW_NAME = "Blood"
local AMOUNT_LABEL_NAME = "Amount"

local ResourceHud = {}

local player = Players.LocalPlayer
local station: Model
local moneyLabel: TextLabel
local energyLabel: TextLabel
local meatRow: GuiObject
local meatLabel: TextLabel
local bloodRow: GuiObject
local bloodLabel: TextLabel
local shownEnergy: number? = nil

local function readCount(attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

local function renderMoney()
	moneyLabel.Text = Money.format(readCount(PlayerAttributes.BALANCE_CENTS))
end

local function renderMeat()
	local meat = readCount(PlayerAttributes.MEAT)
	meatLabel.Text = tostring(meat)
	meatRow.Visible = meatRow.Visible or meat > 0
end

local function renderBlood()
	local blood = readCount(PlayerAttributes.BLOOD)
	bloodLabel.Text = tostring(blood)
	bloodRow.Visible = bloodRow.Visible or blood > 0
end

local function onRenderStepped()
	local energy = math.ceil(CrankCharge.current(station))
	if energy ~= shownEnergy then
		shownEnergy = energy
		energyLabel.Text = tostring(energy)
	end
end

function ResourceHud.start()
	local stats = player:WaitForChild(PLAYER_GUI_NAME):WaitForChild(HUD_NAME):WaitForChild(STATS_NAME)
	moneyLabel = stats:WaitForChild(MONEY_ROW_NAME):WaitForChild(AMOUNT_LABEL_NAME) :: TextLabel
	energyLabel = stats:WaitForChild(ENERGY_ROW_NAME):WaitForChild(AMOUNT_LABEL_NAME) :: TextLabel
	meatRow = stats:WaitForChild(MEAT_ROW_NAME) :: GuiObject
	meatLabel = meatRow:WaitForChild(AMOUNT_LABEL_NAME) :: TextLabel
	bloodRow = stats:WaitForChild(BLOOD_ROW_NAME) :: GuiObject
	bloodLabel = bloodRow:WaitForChild(AMOUNT_LABEL_NAME) :: TextLabel
	station = CrankGeneratorWorld.resolve().station
	player:GetAttributeChangedSignal(PlayerAttributes.BALANCE_CENTS):Connect(renderMoney)
	renderMoney()
	player:GetAttributeChangedSignal(PlayerAttributes.MEAT):Connect(renderMeat)
	renderMeat()
	player:GetAttributeChangedSignal(PlayerAttributes.BLOOD):Connect(renderBlood)
	renderBlood()
	RunService.RenderStepped:Connect(onRenderStepped)
end

return ResourceHud
