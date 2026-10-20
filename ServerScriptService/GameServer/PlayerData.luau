local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAttributes = require(ReplicatedStorage.Shared.PlayerAttributes)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local ToolCatalog = require(ReplicatedStorage.Shared.ToolCatalog)

local STARTING_DEBT_CENTS = 2000000
local STARTING_BALANCE_CENTS = 2000

export type Snapshot = {
	balanceCents: number,
	debtCents: number,
	blood: number,
	meat: number,
	boltsTightened: number,
	rareBoltsTightened: number,
	employeesHired: number,
	hiringUnlocked: boolean,
	equippedTool: string?,
	ownedItems: { string },
	upgradeLevels: { [string]: number },
}

local PlayerData = {}

local function initialize(player: Player)
	player:SetAttribute(PlayerAttributes.DEBT_CENTS, STARTING_DEBT_CENTS)
	player:SetAttribute(PlayerAttributes.BALANCE_CENTS, STARTING_BALANCE_CENTS)
	player:SetAttribute(PlayerAttributes.BLOOD, 0)
	player:SetAttribute(PlayerAttributes.MEAT, 0)
	player:SetAttribute(PlayerAttributes.BOLTS_TIGHTENED, 0)
	player:SetAttribute(PlayerAttributes.RARE_BOLTS_TIGHTENED, 0)
	player:SetAttribute(PlayerAttributes.EMPLOYEES_HIRED, 0)
end

local function readCount(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

function PlayerData.start()
	Players.PlayerAdded:Connect(initialize)
	for _, player in Players:GetPlayers() do
		initialize(player)
	end
end

function PlayerData.ownsItem(player: Player, itemId: string): boolean
	return player:GetAttribute(PlayerAttributes.ownedItem(itemId)) == true
end

function PlayerData.grantItem(player: Player, itemId: string)
	player:SetAttribute(PlayerAttributes.ownedItem(itemId), true)
end

function PlayerData.upgradeLevel(player: Player, itemId: string): number
	return readCount(player, PlayerAttributes.upgradeLevel(itemId))
end

function PlayerData.highestUpgradeLevel(itemId: string, excludedPlayer: Player?): number
	local highestLevel = 0
	for _, player in Players:GetPlayers() do
		if player ~= excludedPlayer then
			highestLevel = math.max(highestLevel, PlayerData.upgradeLevel(player, itemId))
		end
	end
	return highestLevel
end

function PlayerData.grantUpgrade(player: Player, itemId: string)
	player:SetAttribute(PlayerAttributes.upgradeLevel(itemId), PlayerData.upgradeLevel(player, itemId) + 1)
end

function PlayerData.balanceCents(player: Player): number
	return readCount(player, PlayerAttributes.BALANCE_CENTS)
end

function PlayerData.addBalance(player: Player, cents: number)
	player:SetAttribute(PlayerAttributes.BALANCE_CENTS, PlayerData.balanceCents(player) + cents)
end

function PlayerData.trySpend(player: Player, cents: number, blood: number?): boolean
	local bloodCost = blood or 0
	local balance = PlayerData.balanceCents(player)
	local bloodStock = readCount(player, PlayerAttributes.BLOOD)
	if balance < cents or bloodStock < bloodCost then
		return false
	end
	player:SetAttribute(PlayerAttributes.BALANCE_CENTS, balance - cents)
	player:SetAttribute(PlayerAttributes.BLOOD, bloodStock - bloodCost)
	return true
end

function PlayerData.tryPayDebt(player: Player): boolean
	local debt = readCount(player, PlayerAttributes.DEBT_CENTS)
	local balance = PlayerData.balanceCents(player)
	if debt <= 0 or balance < debt then
		return false
	end
	player:SetAttribute(PlayerAttributes.DEBT_CENTS, 0)
	player:SetAttribute(PlayerAttributes.BALANCE_CENTS, balance - debt)
	return true
end

function PlayerData.meat(player: Player): number
	return readCount(player, PlayerAttributes.MEAT)
end

function PlayerData.addMeat(player: Player, amount: number)
	player:SetAttribute(PlayerAttributes.MEAT, PlayerData.meat(player) + amount)
end

function PlayerData.trySpendMeat(player: Player, amount: number): boolean
	local meat = PlayerData.meat(player)
	if meat < amount then
		return false
	end
	player:SetAttribute(PlayerAttributes.MEAT, meat - amount)
	return true
end

function PlayerData.addBlood(player: Player, amount: number)
	player:SetAttribute(PlayerAttributes.BLOOD, readCount(player, PlayerAttributes.BLOOD) + amount)
end

function PlayerData.hasUnlockedHiring(player: Player): boolean
	return player:GetAttribute(PlayerAttributes.HIRING_UNLOCKED) == true
end

function PlayerData.unlockHiring(player: Player)
	player:SetAttribute(PlayerAttributes.HIRING_UNLOCKED, true)
end

function PlayerData.employeesHired(player: Player): number
	return readCount(player, PlayerAttributes.EMPLOYEES_HIRED)
end

function PlayerData.recordHire(player: Player)
	player:SetAttribute(PlayerAttributes.EMPLOYEES_HIRED, PlayerData.employeesHired(player) + 1)
end

function PlayerData.rareBoltsTightened(player: Player): number
	return readCount(player, PlayerAttributes.RARE_BOLTS_TIGHTENED)
end

function PlayerData.recordTightenedBolt(player: Player, payoutCents: number, isRare: boolean)
	PlayerData.addBalance(player, payoutCents)
	player:SetAttribute(PlayerAttributes.BOLTS_TIGHTENED, readCount(player, PlayerAttributes.BOLTS_TIGHTENED) + 1)
	if isRare then
		player:SetAttribute(PlayerAttributes.RARE_BOLTS_TIGHTENED, PlayerData.rareBoltsTightened(player) + 1)
	end
end

function PlayerData.snapshot(player: Player): Snapshot
	local ownedItems = {}
	local upgradeLevels = {}
	for itemId in ShopCatalog.ITEMS do
		if PlayerData.ownsItem(player, itemId) then
			table.insert(ownedItems, itemId)
		end
		local level = PlayerData.upgradeLevel(player, itemId)
		if level > 0 then
			upgradeLevels[itemId] = level
		end
	end
	local equippedTool = player:GetAttribute(PlayerAttributes.EQUIPPED_TOOL)
	return {
		balanceCents = PlayerData.balanceCents(player),
		debtCents = readCount(player, PlayerAttributes.DEBT_CENTS),
		blood = readCount(player, PlayerAttributes.BLOOD),
		meat = PlayerData.meat(player),
		boltsTightened = readCount(player, PlayerAttributes.BOLTS_TIGHTENED),
		rareBoltsTightened = PlayerData.rareBoltsTightened(player),
		employeesHired = PlayerData.employeesHired(player),
		hiringUnlocked = PlayerData.hasUnlockedHiring(player),
		equippedTool = if typeof(equippedTool) == "string" then equippedTool else nil,
		ownedItems = ownedItems,
		upgradeLevels = upgradeLevels,
	}
end

function PlayerData.restore(player: Player, snapshot: Snapshot)
	player:SetAttribute(PlayerAttributes.DEBT_CENTS, snapshot.debtCents)
	player:SetAttribute(PlayerAttributes.BALANCE_CENTS, snapshot.balanceCents)
	player:SetAttribute(PlayerAttributes.BLOOD, snapshot.blood)
	player:SetAttribute(PlayerAttributes.MEAT, snapshot.meat)
	player:SetAttribute(PlayerAttributes.BOLTS_TIGHTENED, snapshot.boltsTightened)
	player:SetAttribute(PlayerAttributes.RARE_BOLTS_TIGHTENED, snapshot.rareBoltsTightened)
	player:SetAttribute(PlayerAttributes.EMPLOYEES_HIRED, snapshot.employeesHired)
	player:SetAttribute(PlayerAttributes.HIRING_UNLOCKED, if snapshot.hiringUnlocked then true else nil)
	for _, itemId in snapshot.ownedItems do
		if ShopCatalog.ITEMS[itemId] then
			PlayerData.grantItem(player, itemId)
		end
	end
	for itemId, level in snapshot.upgradeLevels do
		local item = ShopCatalog.ITEMS[itemId]
		local track = if item then item.upgrade else nil
		if track then
			player:SetAttribute(PlayerAttributes.upgradeLevel(itemId), math.clamp(level, 0, track.maxLevel))
		end
	end
	local equippedTool = snapshot.equippedTool
	if equippedTool and ToolCatalog.isTool(equippedTool) and PlayerData.ownsItem(player, equippedTool) then
		player:SetAttribute(PlayerAttributes.EQUIPPED_TOOL, equippedTool)
	end
end

return PlayerData
