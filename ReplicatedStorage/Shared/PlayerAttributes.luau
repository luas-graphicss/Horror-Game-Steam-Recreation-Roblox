local OWNED_ITEM_PREFIX = "Owns"
local UPGRADE_LEVEL_PREFIX = "UpgradeLevel"

local PlayerAttributes = {
	BALANCE_CENTS = "BalanceCents",
	BLOOD = "Blood",
	MEAT = "Meat",
	DEBT_CENTS = "DebtCents",
	BOLTS_TIGHTENED = "BoltsTightened",
	RARE_BOLTS_TIGHTENED = "RareBoltsTightened",
	CAPTURED = "Captured",
	EQUIPPED_TOOL = "EquippedTool",
	HIRING_UNLOCKED = "HiringUnlocked",
	EMPLOYEES_HIRED = "EmployeesHired",
	STAFF = "Staff",
	SAVE_STATUS = "SaveStatus",
	ON_SHIFT = "OnShift",
	ENDING = "Ending",
}

function PlayerAttributes.ownedItem(itemId: string): string
	return OWNED_ITEM_PREFIX .. itemId
end

function PlayerAttributes.upgradeLevel(itemId: string): string
	return UPGRADE_LEVEL_PREFIX .. itemId
end

return PlayerAttributes
