local ShopCatalog = require(script.Parent.ShopCatalog)

local SWITCH_ORDER = { ShopCatalog.WRENCH_ITEM_ID, ShopCatalog.CROWBAR_ITEM_ID, ShopCatalog.HAMMER_ITEM_ID }
local VIEWMODEL_NAMES = {
	[ShopCatalog.WRENCH_ITEM_ID] = "WrenchViewmodel",
	[ShopCatalog.CROWBAR_ITEM_ID] = "CrowbarViewmodel",
	[ShopCatalog.HAMMER_ITEM_ID] = "HammerViewmodel",
}

local ToolCatalog = {
	SWITCH_ORDER = SWITCH_ORDER,
}

function ToolCatalog.isTool(itemId: string): boolean
	return table.find(SWITCH_ORDER, itemId) ~= nil
end

function ToolCatalog.viewmodelName(itemId: string): string
	return VIEWMODEL_NAMES[itemId]
end

function ToolCatalog.ownedCount(owns: (string) -> boolean): number
	local count = 0
	for _, itemId in SWITCH_ORDER do
		if owns(itemId) then
			count += 1
		end
	end
	return count
end

function ToolCatalog.nextOwned(current: string?, owns: (string) -> boolean): string?
	local toolCount = #SWITCH_ORDER
	local currentIndex = if current then table.find(SWITCH_ORDER, current) or 0 else 0
	for offset = 1, toolCount do
		local candidate = SWITCH_ORDER[(currentIndex + offset - 1) % toolCount + 1]
		if candidate ~= current and owns(candidate) then
			return candidate
		end
	end
	return nil
end

return ToolCatalog
