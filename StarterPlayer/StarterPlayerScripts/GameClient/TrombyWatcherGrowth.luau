local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrombyWatcherConfig = require(Shared:WaitForChild("TrombyWatcherConfig"))

local GROWTH_DURATION = 1.4

local TrombyWatcherGrowth = {}

local restScales: { [Instance]: number } = {}
local growthConnections: { [Instance]: RBXScriptConnection } = {}

local function grownScale(watcher: Model): number
	local contributions = watcher:GetAttribute(TrombyWatcherConfig.CONTRIBUTIONS_ATTRIBUTE)
	local exponent = if typeof(contributions) == "number" then contributions else 0
	return restScales[watcher] * TrombyWatcherConfig.GROWTH_PER_CONTRIBUTION ^ exponent
end

local function grow(watcher: Model)
	local fromScale = watcher:GetScale()
	local toScale = grownScale(watcher)
	local startedAt = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local progress = math.min((os.clock() - startedAt) / GROWTH_DURATION, 1)
		local eased = TweenService:GetValue(progress, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		watcher:ScaleTo(fromScale + (toScale - fromScale) * eased)
		if progress >= 1 then
			connection:Disconnect()
		end
	end)
end

local function bind(instance: Instance)
	if not instance:IsA("Model") or growthConnections[instance] then
		return
	end
	restScales[instance] = instance:GetScale()
	instance:ScaleTo(grownScale(instance))
	growthConnections[instance] = instance:GetAttributeChangedSignal(TrombyWatcherConfig.CONTRIBUTIONS_ATTRIBUTE):Connect(function()
		grow(instance)
	end)
end

local function unbind(instance: Instance)
	local connection = growthConnections[instance]
	if connection then
		connection:Disconnect()
	end
	growthConnections[instance] = nil
	restScales[instance] = nil
end

function TrombyWatcherGrowth.start()
	CollectionService:GetInstanceAddedSignal(TrombyWatcherConfig.TAG):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(TrombyWatcherConfig.TAG):Connect(unbind)
	for _, watcher in CollectionService:GetTagged(TrombyWatcherConfig.TAG) do
		bind(watcher)
	end
end

return TrombyWatcherGrowth
