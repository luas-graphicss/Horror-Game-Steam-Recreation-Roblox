local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Money = require(Shared:WaitForChild("Money"))
local PlayerAttributes = require(Shared:WaitForChild("PlayerAttributes"))

local PLAYER_GUI_NAME = "PlayerGui"
local DISPLAY_NAME = "StatusTabletDisplay"
local CONTENT_NAME = "Content"
local DEBT_LABEL_NAME = "Debt"
local BALANCE_LABEL_NAME = "Balance"
local BOLTS_LABEL_NAME = "Bolts"
local MAP_NAME = "MetalBox"
local TABLET_NAME = "StatusTablet"
local TABLET_BODY_NAME = "TabletBody"
local PAYOUT_SOUND_NAME = "PayoutSound"
local DEBT_FORMAT = "Debt: %s$"
local BALANCE_FORMAT = "Balance: %s$"
local BOLTS_FORMAT = "Bolts: %d"

local StatusTablet = {}

local player = Players.LocalPlayer

local function readCount(attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

function StatusTablet.start()
	local content = player:WaitForChild(PLAYER_GUI_NAME):WaitForChild(DISPLAY_NAME):WaitForChild(CONTENT_NAME)
	local debtLabel = content:WaitForChild(DEBT_LABEL_NAME) :: TextLabel
	local balanceLabel = content:WaitForChild(BALANCE_LABEL_NAME) :: TextLabel
	local boltsLabel = content:WaitForChild(BOLTS_LABEL_NAME) :: TextLabel
	local tabletBody = Workspace:WaitForChild(MAP_NAME):WaitForChild(TABLET_NAME):WaitForChild(TABLET_BODY_NAME)
	local payoutSound = tabletBody:WaitForChild(PAYOUT_SOUND_NAME) :: Sound
	local shownBalance = readCount(PlayerAttributes.BALANCE_CENTS)
	local function render()
		local balance = readCount(PlayerAttributes.BALANCE_CENTS)
		debtLabel.Text = string.format(DEBT_FORMAT, Money.format(readCount(PlayerAttributes.DEBT_CENTS)))
		balanceLabel.Text = string.format(BALANCE_FORMAT, Money.format(balance))
		boltsLabel.Text = string.format(BOLTS_FORMAT, readCount(PlayerAttributes.BOLTS_TIGHTENED))
		if balance > shownBalance then
			payoutSound:Play()
		end
		shownBalance = balance
	end
	for _, attribute in { PlayerAttributes.DEBT_CENTS, PlayerAttributes.BALANCE_CENTS, PlayerAttributes.BOLTS_TIGHTENED } do
		player:GetAttributeChangedSignal(attribute):Connect(render)
	end
	render()
end

return StatusTablet
