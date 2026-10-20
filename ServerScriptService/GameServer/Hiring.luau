local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeRoster = require(ReplicatedStorage.Shared.EmployeeRoster)
local HiringConfig = require(ReplicatedStorage.Shared.HiringConfig)
local ProductionLineConfig = require(ReplicatedStorage.Shared.ProductionLineConfig)
local ProductionLineSlots = require(ReplicatedStorage.Shared.ProductionLineSlots)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local Employees = require(script.Parent.Employees)
local PlayerData = require(script.Parent.PlayerData)
local PlayerReach = require(script.Parent.PlayerReach)
local RemoteThrottle = require(script.Parent.RemoteThrottle)

local TERMINAL_RANGE = 14
local TERMINAL_REQUESTS_PER_SECOND = 4

local Hiring = {}

local terminalPosition: Vector3

local function isNearTerminal(player: Player): boolean
	return PlayerReach.isWithin(player, terminalPosition, TERMINAL_RANGE)
end

local function mayStaff(player: Player, area: string): boolean
	if area == ProductionLineConfig.HEART_AREA then
		return PlayerData.ownsItem(player, ShopCatalog.HAMMER_ITEM_ID)
	end
	return area == ProductionLineConfig.BOLT_AREA
end

local function onUnlockRequested(player: Player)
	if PlayerData.hasUnlockedHiring(player) or not isNearTerminal(player) then
		return
	end
	if PlayerData.trySpend(player, HiringConfig.UNLOCK_PRICE_CENTS) then
		PlayerData.unlockHiring(player)
	end
end

local function onHireRequested(player: Player, area: unknown)
	if typeof(area) ~= "string" or not PlayerData.hasUnlockedHiring(player) or not mayStaff(player, area) then
		return
	end
	local line = ProductionLineSlots.freeLine(area)
	if not line or not isNearTerminal(player) then
		return
	end
	local hiredCount = PlayerData.employeesHired(player)
	if PlayerData.trySpend(player, EmployeeRoster.hirePriceCents(hiredCount)) then
		PlayerData.recordHire(player)
		Employees.hire(player, line, area, EmployeeRoster.candidateAt(hiredCount))
	end
end

function Hiring.start()
	local terminal = CollectionService:GetTagged(HiringConfig.TERMINAL_TAG)[1] :: Model
	terminalPosition = terminal:GetPivot().Position
	RemoteThrottle.connect(Remotes.UnlockHiring, TERMINAL_REQUESTS_PER_SECOND, onUnlockRequested)
	RemoteThrottle.connect(Remotes.HireEmployee, TERMINAL_REQUESTS_PER_SECOND, onHireRequested)
end

return Hiring
