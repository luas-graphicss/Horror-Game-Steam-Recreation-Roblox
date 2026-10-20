local UserInputService = game:GetService("UserInputService")

local PRIMARY_INPUT_TYPES = {
	[Enum.UserInputType.MouseButton1] = true,
}
local PRIMARY_KEY_CODES = {
	[Enum.KeyCode.ButtonR2] = true,
}

local triggeredEvent = Instance.new("BindableEvent")
local pressedEvent = Instance.new("BindableEvent")
local heldInputs: { [EnumItem | InputObject]: boolean } = {}

local PrimaryAction = {
	triggered = triggeredEvent.Event,
	pressed = pressedEvent.Event,
}

local function holdKeyOf(input: InputObject): (EnumItem | InputObject)?
	if PRIMARY_INPUT_TYPES[input.UserInputType] then
		return input.UserInputType
	elseif PRIMARY_KEY_CODES[input.KeyCode] then
		return input.KeyCode
	elseif input.UserInputType == Enum.UserInputType.Touch then
		return input
	end
	return nil
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	local holdKey = holdKeyOf(input)
	if gameProcessed or holdKey == nil then
		return
	end
	heldInputs[holdKey] = true
	pressedEvent:Fire()
	if input.UserInputType ~= Enum.UserInputType.Touch then
		triggeredEvent:Fire()
	end
end

local function onInputEnded(input: InputObject)
	local holdKey = holdKeyOf(input)
	if holdKey ~= nil then
		heldInputs[holdKey] = nil
	end
end

local function onTouchTapInWorld(_position: Vector2, processedByUI: boolean)
	if not processedByUI then
		triggeredEvent:Fire()
	end
end

local function onWindowFocusReleased()
	table.clear(heldInputs)
end

function PrimaryAction.isHeld(): boolean
	return next(heldInputs) ~= nil
end

function PrimaryAction.start()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.TouchTapInWorld:Connect(onTouchTapInWorld)
	UserInputService.WindowFocusReleased:Connect(onWindowFocusReleased)
end

return PrimaryAction
