local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopCatalog = require(Shared:WaitForChild("ShopCatalog"))

local MULTIPLIER_FORMAT = "%.2f"
local TRAILING_ZEROS_PATTERN = "%.?0+$"
local HOURS_FORMAT = "%dh%02dm%02ds"
local MINUTES_FORMAT = "%dm%02ds"
local SECONDS_FORMAT = "%ds"
local PERCENT_FORMAT = "%d%%"
local PERCENT_SCALE = 100
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3600

local UpgradeValueText = {}

local function formatMultiplier(value: number): string
	local text = string.gsub(string.format(MULTIPLIER_FORMAT, value), TRAILING_ZEROS_PATTERN, "")
	return text
end

local function formatDuration(value: number): string
	local totalSeconds = math.round(value)
	local hours = totalSeconds // SECONDS_PER_HOUR
	local minutes = (totalSeconds % SECONDS_PER_HOUR) // SECONDS_PER_MINUTE
	local seconds = totalSeconds % SECONDS_PER_MINUTE
	if hours > 0 then
		return string.format(HOURS_FORMAT, hours, minutes, seconds)
	elseif minutes > 0 then
		return string.format(MINUTES_FORMAT, minutes, seconds)
	end
	return string.format(SECONDS_FORMAT, seconds)
end

local function formatPercent(value: number): string
	return string.format(PERCENT_FORMAT, math.round(value * PERCENT_SCALE))
end

local FORMATTERS: { [string]: (number) -> string } = {
	[ShopCatalog.MULTIPLIER_VALUE] = formatMultiplier,
	[ShopCatalog.DURATION_VALUE] = formatDuration,
	[ShopCatalog.PERCENT_VALUE] = formatPercent,
}

function UpgradeValueText.format(valueKind: string, value: number): string
	return FORMATTERS[valueKind](value)
end

return UpgradeValueText
