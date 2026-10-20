local Workspace = game:GetService("Workspace")

local CrankGeneratorConfig = require(script.Parent.CrankGeneratorConfig)

export type CrankRates = {
	turnsPerSecond: number,
	energyPerTurn: number,
	inertiaDuration: number,
}

local CrankCharge = {}

local function readNumber(station: Instance, attribute: string, fallback: number): number
	local value = station:GetAttribute(attribute)
	return if typeof(value) == "number" then value else fallback
end

local function turnsPerSecond(station: Instance): number
	return readNumber(station, CrankGeneratorConfig.TURNS_PER_SECOND_ATTRIBUTE, CrankGeneratorConfig.TURNS_PER_SECOND)
end

local function energyPerTurn(station: Instance): number
	return readNumber(station, CrankGeneratorConfig.ENERGY_PER_TURN_ATTRIBUTE, CrankGeneratorConfig.ENERGY_PER_TURN)
end

local function coastDuration(station: Instance): number
	return readNumber(station, CrankGeneratorConfig.COAST_DURATION_ATTRIBUTE, 0)
end

local function drainPerSecond(station: Instance): number
	local duration = readNumber(station, CrankGeneratorConfig.FULL_DRAIN_DURATION_ATTRIBUTE, CrankGeneratorConfig.FULL_DRAIN_DURATION)
	return CrankGeneratorConfig.MAX_CHARGE / duration
end

local function elapsedSinceCharged(station: Instance): number
	local chargedAt = readNumber(station, CrankGeneratorConfig.CHARGED_AT_ATTRIBUTE, 0)
	return math.max(Workspace:GetServerTimeNow() - chargedAt, 0)
end

local function coastedTurns(station: Instance, elapsed: number): number
	local duration = coastDuration(station)
	if duration <= 0 then
		return 0
	end
	local coastTime = math.min(elapsed, duration)
	return turnsPerSecond(station) * (coastTime - coastTime * coastTime / (2 * duration))
end

function CrankCharge.isCranking(station: Instance): boolean
	return station:GetAttribute(CrankGeneratorConfig.CRANKING_ATTRIBUTE) == true
end

function CrankCharge.spinTurnsPerSecond(station: Instance): number
	if CrankCharge.isCranking(station) then
		return turnsPerSecond(station)
	end
	local duration = coastDuration(station)
	if duration <= 0 then
		return 0
	end
	return turnsPerSecond(station) * math.max(1 - elapsedSinceCharged(station) / duration, 0)
end

function CrankCharge.current(station: Instance): number
	local storedCharge = readNumber(station, CrankGeneratorConfig.CHARGE_ATTRIBUTE, 0)
	local elapsed = elapsedSinceCharged(station)
	if CrankCharge.isCranking(station) then
		local crankedCharge = storedCharge + elapsed * turnsPerSecond(station) * energyPerTurn(station)
		return math.min(crankedCharge, CrankGeneratorConfig.MAX_CHARGE)
	end
	local coastedCharge = storedCharge + coastedTurns(station, elapsed) * energyPerTurn(station)
	local drainTime = math.max(elapsed - coastDuration(station) - CrankGeneratorConfig.DRAIN_DELAY, 0)
	return math.max(math.min(coastedCharge, CrankGeneratorConfig.MAX_CHARGE) - drainTime * drainPerSecond(station), 0)
end

function CrankCharge.fraction(charge: number): number
	return charge / CrankGeneratorConfig.MAX_CHARGE
end

function CrankCharge.isPowered(charge: number): boolean
	return charge > 0
end

function CrankCharge.hasRoom(charge: number): boolean
	return charge < CrankGeneratorConfig.MAX_CHARGE
end

function CrankCharge.crank(station: Instance, rates: CrankRates, fullDrainDuration: number)
	station:SetAttribute(CrankGeneratorConfig.CHARGE_ATTRIBUTE, CrankCharge.current(station))
	station:SetAttribute(CrankGeneratorConfig.CHARGED_AT_ATTRIBUTE, Workspace:GetServerTimeNow())
	station:SetAttribute(CrankGeneratorConfig.CRANKING_ATTRIBUTE, true)
	station:SetAttribute(CrankGeneratorConfig.TURNS_PER_SECOND_ATTRIBUTE, rates.turnsPerSecond)
	station:SetAttribute(CrankGeneratorConfig.ENERGY_PER_TURN_ATTRIBUTE, rates.energyPerTurn)
	station:SetAttribute(CrankGeneratorConfig.COAST_DURATION_ATTRIBUTE, rates.inertiaDuration)
	station:SetAttribute(CrankGeneratorConfig.FULL_DRAIN_DURATION_ATTRIBUTE, fullDrainDuration)
end

function CrankCharge.release(station: Instance, fullDrainDuration: number)
	local charge = CrankCharge.current(station)
	local spinTurnsPerSecond = CrankCharge.spinTurnsPerSecond(station)
	local elapsed = if CrankCharge.isCranking(station) then 0 else elapsedSinceCharged(station)
	local duration = coastDuration(station)
	local heldFor = math.clamp(elapsed - duration, 0, CrankGeneratorConfig.DRAIN_DELAY)
	station:SetAttribute(CrankGeneratorConfig.CHARGE_ATTRIBUTE, charge)
	station:SetAttribute(CrankGeneratorConfig.CHARGED_AT_ATTRIBUTE, Workspace:GetServerTimeNow() - heldFor)
	station:SetAttribute(CrankGeneratorConfig.CRANKING_ATTRIBUTE, false)
	station:SetAttribute(CrankGeneratorConfig.TURNS_PER_SECOND_ATTRIBUTE, spinTurnsPerSecond)
	station:SetAttribute(CrankGeneratorConfig.COAST_DURATION_ATTRIBUTE, math.max(duration - elapsed, 0))
	station:SetAttribute(CrankGeneratorConfig.FULL_DRAIN_DURATION_ATTRIBUTE, fullDrainDuration)
end

return CrankCharge
