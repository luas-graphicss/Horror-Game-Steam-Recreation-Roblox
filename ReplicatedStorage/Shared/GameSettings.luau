export type Definition = {
	attribute: string,
	label: string,
	min: number,
	max: number,
	default: number,
	step: number,
}

local VOLUME = "Volume"
local SENSITIVITY = "Sensitivity"
local FIELD_OF_VIEW = "FieldOfView"

local DEFINITIONS: { [string]: Definition } = {
	[VOLUME] = {
		attribute = "SettingVolume",
		label = "Volume",
		min = 0,
		max = 1,
		default = 1,
		step = 0.05,
	},
	[SENSITIVITY] = {
		attribute = "SettingSensitivity",
		label = "Sensibilidade do mouse",
		min = 0.2,
		max = 2,
		default = 1,
		step = 0.05,
	},
	[FIELD_OF_VIEW] = {
		attribute = "SettingFieldOfView",
		label = "Campo de visÃ£o",
		min = 60,
		max = 100,
		default = 70,
		step = 1,
	},
}

local GameSettings = {
	VOLUME = VOLUME,
	SENSITIVITY = SENSITIVITY,
	FIELD_OF_VIEW = FIELD_OF_VIEW,
	ORDER = { VOLUME, SENSITIVITY, FIELD_OF_VIEW },
	DEFINITIONS = DEFINITIONS,
}

function GameSettings.sanitize(name: string, value: unknown): number?
	local definition = DEFINITIONS[name]
	if not definition or typeof(value) ~= "number" or value ~= value then
		return nil
	end
	local stepped = math.round(value / definition.step) * definition.step
	return math.clamp(stepped, definition.min, definition.max)
end

function GameSettings.read(owner: Instance, name: string): number
	local definition = DEFINITIONS[name]
	local value = owner:GetAttribute(definition.attribute)
	return if typeof(value) == "number" then value else definition.default
end

function GameSettings.format(name: string, value: number): string
	if name == VOLUME then
		return string.format("%d%%", math.round(value * 100))
	elseif name == SENSITIVITY then
		return string.format("%.2fx", value)
	end
	return string.format("%dÂ°", math.round(value))
end

return GameSettings
