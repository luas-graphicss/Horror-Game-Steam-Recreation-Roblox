local CrankGeneratorConfig = require(script.Parent.CrankGeneratorConfig)

export type UpgradeTrack = {
	maxLevel: number,
	baseValue: number,
	valuePerLevel: number,
	basePriceCents: number,
	priceGrowth: number,
	bloodFromLevel: number,
	valueKind: string,
}

export type Item = {
	displayName: string,
	description: string,
	purchasePriceCents: number?,
	upgrade: UpgradeTrack?,
}

local WRENCH_ITEM_ID = "Wrench"
local BATTERY_ITEM_ID = "Battery"
local CRANK_ITEM_ID = "Crank"
local GEAR_ITEM_ID = "Gear"
local INERTIA_ITEM_ID = "Inertia"
local COMPUTER_ITEM_ID = "Computer"
local BRAIN_ITEM_ID = "Brain"
local BOLT_ITEM_ID = "Bolt"
local LOOSE_NUT_ITEM_ID = "LooseNut"
local CROWBAR_ITEM_ID = "Crowbar"
local SODA_MACHINE_ITEM_ID = "SodaMachine"
local HEART_ITEM_ID = "Heart"
local PROCESSING_COMPUTER_ITEM_ID = "ProcessingComputer"
local HAMMER_ITEM_ID = "Hammer"
local RED_MUG_ITEM_ID = "RedMug"
local STAPLER_ITEM_ID = "Stapler"
local BASE_PURCHASE_STAGE = 0
local PRICE_STEP_CENTS = 10
local BLOOD_BASE_COST = 8
local BLOOD_COST_PER_LEVEL = 8
local NO_BLOOD_COST = 0
local MULTIPLIER_VALUE = "Multiplier"
local DURATION_VALUE = "Duration"
local PERCENT_VALUE = "Percent"

local ITEMS: { [string]: Item } = {
	[WRENCH_ITEM_ID] = {
		displayName = "Chave Inglesa",
		description = "Enrosca a rosca do parafuso na esteira.",
		purchasePriceCents = 0,
		upgrade = {
			maxLevel = 20,
			baseValue = 1,
			valuePerLevel = 0.2,
			basePriceCents = 170,
			priceGrowth = 1.27,
			bloodFromLevel = 13,
			valueKind = MULTIPLIER_VALUE,
		},
	},
	[BATTERY_ITEM_ID] = {
		displayName = "Bateria Industrial",
		description = "Faz a energia durar mais antes de acabar.",
		upgrade = {
			maxLevel = 15,
			baseValue = CrankGeneratorConfig.FULL_DRAIN_DURATION,
			valuePerLevel = 30,
			basePriceCents = 200,
			priceGrowth = 1.27,
			bloodFromLevel = 10,
			valueKind = DURATION_VALUE,
		},
	},
	[CRANK_ITEM_ID] = {
		displayName = "Manivela",
		description = "Enche as faixas de energia mais rÃ¡pido ao girar.",
		upgrade = {
			maxLevel = 15,
			baseValue = 1,
			valuePerLevel = 0.1,
			basePriceCents = 130,
			priceGrowth = 1.27,
			bloodFromLevel = 10,
			valueKind = MULTIPLIER_VALUE,
		},
	},
	[GEAR_ITEM_ID] = {
		displayName = "Engrenagem",
		description = "Cada giro da manivela produz mais energia.",
		upgrade = {
			maxLevel = 12,
			baseValue = 1,
			valuePerLevel = 0.15,
			basePriceCents = 160,
			priceGrowth = 1.32,
			bloodFromLevel = 8,
			valueKind = MULTIPLIER_VALUE,
		},
	},
	[INERTIA_ITEM_ID] = {
		displayName = "Monitor de InÃ©rcia",
		description = "A manivela segue girando e gerando energia por mais tempo depois que vocÃª solta.",
		upgrade = {
			maxLevel = 12,
			baseValue = CrankGeneratorConfig.INERTIA_DURATION,
			valuePerLevel = 1,
			basePriceCents = 130,
			priceGrowth = 1.27,
			bloodFromLevel = 8,
			valueKind = DURATION_VALUE,
		},
	},
	[COMPUTER_ITEM_ID] = {
		displayName = "Computador Antigo",
		description = "Aumenta a velocidade da esteira.",
		upgrade = {
			maxLevel = 10,
			baseValue = 1,
			valuePerLevel = 0.15,
			basePriceCents = 500,
			priceGrowth = 1.55,
			bloodFromLevel = 7,
			valueKind = MULTIPLIER_VALUE,
		},
	},
	[BRAIN_ITEM_ID] = {
		displayName = "CÃ©rebro",
		description = "Enrosca os parafusos sozinho, sÃ³ de mirar, sem clicar.",
		purchasePriceCents = 12000,
	},
	[BOLT_ITEM_ID] = {
		displayName = "Parafuso",
		description = "Aumenta a chance de vir parafusos raros na esteira.",
		upgrade = {
			maxLevel = 12,
			baseValue = 0.05,
			valuePerLevel = 0.02,
			basePriceCents = 250,
			priceGrowth = 1.45,
			bloodFromLevel = 8,
			valueKind = PERCENT_VALUE,
		},
	},
	[LOOSE_NUT_ITEM_ID] = {
		displayName = "Rosca Solta",
		description = "Aumenta o valor dos parafusos, comuns e raros.",
		upgrade = {
			maxLevel = 15,
			baseValue = 1,
			valuePerLevel = 0.4,
			basePriceCents = 400,
			priceGrowth = 1.4,
			bloodFromLevel = 10,
			valueKind = MULTIPLIER_VALUE,
		},
	},
	[CROWBAR_ITEM_ID] = {
		displayName = "PÃ© de Cabra",
		description = "Arranca os olhos que brotam das paredes.",
		purchasePriceCents = 66000,
	},
	[SODA_MACHINE_ITEM_ID] = {
		displayName = "MÃ¡quina de Refri",
		description = "Um refri gelado deixa vocÃª mais rÃ¡pido.",
		upgrade = {
			maxLevel = 10,
			baseValue = 1,
			valuePerLevel = 0.06,
			basePriceCents = 750,
			priceGrowth = 1.3,
			bloodFromLevel = 7,
			valueKind = MULTIPLIER_VALUE,
		},
	},
	[HEART_ITEM_ID] = {
		displayName = "CoraÃ§Ã£o",
		description = "Corpos e olhos moÃ­dos rendem mais carne, e coraÃ§Ãµes esmagados rendem mais sangue.",
		upgrade = {
			maxLevel = 12,
			baseValue = 1,
			valuePerLevel = 0.25,
			basePriceCents = 1500,
			priceGrowth = 1.35,
			bloodFromLevel = 6,
			valueKind = MULTIPLIER_VALUE,
		},
	},
	[PROCESSING_COMPUTER_ITEM_ID] = {
		displayName = "Computador de Processamento",
		description = "Aumenta a velocidade das esteiras do setor 2.",
		upgrade = {
			maxLevel = 10,
			baseValue = 1,
			valuePerLevel = 0.2,
			basePriceCents = 3000,
			priceGrowth = 1.5,
			bloodFromLevel = 6,
			valueKind = MULTIPLIER_VALUE,
		},
	},
	[HAMMER_ITEM_ID] = {
		displayName = "Martelo",
		description = "Esmaga os coraÃ§Ãµes das esteiras. Cada melhoria deixa as marteladas mais rÃ¡pidas.",
		purchasePriceCents = 4000,
		upgrade = {
			maxLevel = 10,
			baseValue = 1,
			valuePerLevel = 0.15,
			basePriceCents = 2200,
			priceGrowth = 1.4,
			bloodFromLevel = 7,
			valueKind = MULTIPLIER_VALUE,
		},
	},
	[RED_MUG_ITEM_ID] = {
		displayName = "Caneca Vermelha",
		description = "Cada coraÃ§Ã£o marretado na esteira rende mais sangue.",
		upgrade = {
			maxLevel = 12,
			baseValue = 1,
			valuePerLevel = 0.25,
			basePriceCents = 1800,
			priceGrowth = 1.35,
			bloodFromLevel = 6,
			valueKind = MULTIPLIER_VALUE,
		},
	},
	[STAPLER_ITEM_ID] = {
		displayName = "Grampeador",
		description = "Os funcionÃ¡rios trabalham mais rÃ¡pido.",
		upgrade = {
			maxLevel = 10,
			baseValue = 1,
			valuePerLevel = 0.25,
			basePriceCents = 3800,
			priceGrowth = 1.5,
			bloodFromLevel = 6,
			valueKind = MULTIPLIER_VALUE,
		},
	},
}

local function nextPurchaseStage(item: Item, isOwned: boolean, upgradeLevel: number): number
	local needsPurchase = item.purchasePriceCents ~= nil and not isOwned
	return if needsPurchase then BASE_PURCHASE_STAGE else upgradeLevel + 1
end

local function upgradeValueAt(item: Item, level: number): number
	local track = item.upgrade :: UpgradeTrack
	return track.baseValue + track.valuePerLevel * level
end

local function bloodCostAtStage(item: Item, stage: number): number
	local track = item.upgrade
	if stage == BASE_PURCHASE_STAGE or not track or stage < track.bloodFromLevel then
		return NO_BLOOD_COST
	end
	return BLOOD_BASE_COST + (stage - track.bloodFromLevel) * BLOOD_COST_PER_LEVEL
end

local function priceAtStage(item: Item, stage: number): number?
	if stage == BASE_PURCHASE_STAGE then
		return item.purchasePriceCents
	end
	local track = item.upgrade
	if not track or stage > track.maxLevel then
		return nil
	end
	local exactPriceCents = track.basePriceCents * track.priceGrowth ^ (stage - 1)
	return math.round(exactPriceCents / PRICE_STEP_CENTS) * PRICE_STEP_CENTS
end

return {
	TAG = "ShopItem",
	ITEM_ID_ATTRIBUTE = "ItemId",
	WRENCH_ITEM_ID = WRENCH_ITEM_ID,
	BATTERY_ITEM_ID = BATTERY_ITEM_ID,
	CRANK_ITEM_ID = CRANK_ITEM_ID,
	GEAR_ITEM_ID = GEAR_ITEM_ID,
	INERTIA_ITEM_ID = INERTIA_ITEM_ID,
	COMPUTER_ITEM_ID = COMPUTER_ITEM_ID,
	BRAIN_ITEM_ID = BRAIN_ITEM_ID,
	BOLT_ITEM_ID = BOLT_ITEM_ID,
	LOOSE_NUT_ITEM_ID = LOOSE_NUT_ITEM_ID,
	CROWBAR_ITEM_ID = CROWBAR_ITEM_ID,
	SODA_MACHINE_ITEM_ID = SODA_MACHINE_ITEM_ID,
	HEART_ITEM_ID = HEART_ITEM_ID,
	PROCESSING_COMPUTER_ITEM_ID = PROCESSING_COMPUTER_ITEM_ID,
	HAMMER_ITEM_ID = HAMMER_ITEM_ID,
	RED_MUG_ITEM_ID = RED_MUG_ITEM_ID,
	STAPLER_ITEM_ID = STAPLER_ITEM_ID,
	BASE_PURCHASE_STAGE = BASE_PURCHASE_STAGE,
	MULTIPLIER_VALUE = MULTIPLIER_VALUE,
	DURATION_VALUE = DURATION_VALUE,
	PERCENT_VALUE = PERCENT_VALUE,
	ITEMS = ITEMS,
	nextPurchaseStage = nextPurchaseStage,
	upgradeValueAt = upgradeValueAt,
	priceAtStage = priceAtStage,
	bloodCostAtStage = bloodCostAtStage,
}
