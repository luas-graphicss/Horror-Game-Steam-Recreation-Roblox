local HiringConfig = require(script.Parent.HiringConfig)
local ProductionLineConfig = require(script.Parent.ProductionLineConfig)

export type Candidate = {
	name: string,
	speed: number,
	profile: string,
}

local CANDIDATES: { Candidate } = {
	{ name = "Osvaldo Prates", speed = 1, profile = "Vinte anos apertando parafusos. NÃ£o lembra de onde veio." },
	{ name = "Dalva Moreira", speed = 1.25, profile = "Trabalha sem piscar. NinguÃ©m nunca a viu comer." },
	{ name = "Ezequiel Bortolo", speed = 1.5, profile = "Pediu para ficar perto do triturador. Gosta do barulho." },
	{ name = "Nair Fontana", speed = 1.8, profile = "Diz que jÃ¡ trabalhou aqui antes. Diz que nunca saiu." },
}

local EmployeeRoster = {}

function EmployeeRoster.candidateAt(hiredCount: number): Candidate
	return CANDIDATES[math.min(hiredCount + 1, #CANDIDATES)]
end

function EmployeeRoster.candidateNamed(name: string): Candidate?
	for _, candidate in CANDIDATES do
		if candidate.name == name then
			return candidate
		end
	end
	return nil
end

function EmployeeRoster.hirePriceCents(hiredCount: number): number
	local exactPriceCents = HiringConfig.HIRE_BASE_PRICE_CENTS * HiringConfig.HIRE_PRICE_GROWTH ^ hiredCount
	return math.round(exactPriceCents / HiringConfig.HIRE_PRICE_STEP_CENTS) * HiringConfig.HIRE_PRICE_STEP_CENTS
end

function EmployeeRoster.workInterval(candidate: Candidate, area: string): number
	local baseInterval = if area == ProductionLineConfig.HEART_AREA
		then HiringConfig.HEART_STRIKE_INTERVAL
		else HiringConfig.BOLT_TURN_INTERVAL
	return baseInterval / candidate.speed
end

return EmployeeRoster
