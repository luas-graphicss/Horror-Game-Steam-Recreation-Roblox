local CENTS_PER_UNIT = 100
local AMOUNT_FORMAT = "%.2f"

local Money = {}

function Money.format(cents: number): string
	return string.format(AMOUNT_FORMAT, cents / CENTS_PER_UNIT)
end

return Money
