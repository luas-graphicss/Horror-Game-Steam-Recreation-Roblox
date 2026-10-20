local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WallEyeConfig = require(Shared:WaitForChild("WallEyeConfig"))

local REVEAL_DURATION = 2.5
local FULLY_CONCEALED = 1

type Concealment = {
	parts: { BasePart },
	amount: number,
	descendantConnection: RBXScriptConnection?,
}

local WallEyeReveal = {}

local function isAwake(model: Instance): boolean
	return model:GetAttribute(WallEyeConfig.AWAKE_ATTRIBUTE) == true
end

local function setConcealment(concealment: Concealment, amount: number)
	concealment.amount = amount
	for _, part in concealment.parts do
		part.LocalTransparencyModifier = amount
	end
end

local function track(concealment: Concealment, instance: Instance)
	if instance:IsA("BasePart") then
		table.insert(concealment.parts, instance)
		instance.LocalTransparencyModifier = concealment.amount
	end
end

local function conceal(model: Instance): Concealment
	local concealment: Concealment = { parts = {}, amount = FULLY_CONCEALED, descendantConnection = nil }
	for _, descendant in model:GetDescendants() do
		track(concealment, descendant)
	end
	concealment.descendantConnection = model.DescendantAdded:Connect(function(descendant: Instance)
		track(concealment, descendant)
	end)
	return concealment
end

local function reveal(concealment: Concealment)
	local startedAt = os.clock()
	local fadeConnection: RBXScriptConnection
	fadeConnection = RunService.RenderStepped:Connect(function()
		local progress = math.min((os.clock() - startedAt) / REVEAL_DURATION, 1)
		setConcealment(concealment, FULLY_CONCEALED - progress)
		if progress >= 1 then
			fadeConnection:Disconnect()
			if concealment.descendantConnection then
				concealment.descendantConnection:Disconnect()
			end
		end
	end)
end

local function revealWhenAwake(model: Instance, concealment: Concealment)
	local awakeConnection: RBXScriptConnection
	awakeConnection = model:GetAttributeChangedSignal(WallEyeConfig.AWAKE_ATTRIBUTE):Connect(function()
		if isAwake(model) then
			awakeConnection:Disconnect()
			reveal(concealment)
		end
	end)
end

local function bindEye(model: Instance, isNewborn: boolean)
	if isAwake(model) and not isNewborn then
		return
	end
	local concealment = conceal(model)
	if isAwake(model) then
		reveal(concealment)
	else
		revealWhenAwake(model, concealment)
	end
end

function WallEyeReveal.start()
	CollectionService:GetInstanceAddedSignal(WallEyeConfig.TAG):Connect(function(model: Instance)
		bindEye(model, true)
	end)
	for _, model in CollectionService:GetTagged(WallEyeConfig.TAG) do
		bindEye(model, false)
	end
end

return WallEyeReveal
