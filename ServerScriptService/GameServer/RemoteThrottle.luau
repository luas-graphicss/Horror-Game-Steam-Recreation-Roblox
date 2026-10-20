local Players = game:GetService("Players")

type Bucket = {
	tokens: number,
	refilledAt: number,
}

local RemoteThrottle = {}

local bucketsPerRemote: { { [Player]: Bucket } } = {}

local function admits(buckets: { [Player]: Bucket }, player: Player, requestsPerSecond: number): boolean
	local now = os.clock()
	local capacity = math.max(requestsPerSecond, 1)
	local bucket = buckets[player] or { tokens = capacity, refilledAt = now }
	bucket.tokens = math.min(bucket.tokens + (now - bucket.refilledAt) * requestsPerSecond, capacity)
	bucket.refilledAt = now
	buckets[player] = bucket
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function forget(player: Player)
	for _, buckets in bucketsPerRemote do
		buckets[player] = nil
	end
end

function RemoteThrottle.connect(remote: RemoteEvent, requestsPerSecond: number, handler: (Player, ...any) -> ())
	local buckets: { [Player]: Bucket } = {}
	table.insert(bucketsPerRemote, buckets)
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if admits(buckets, player, requestsPerSecond) then
			handler(player, ...)
		end
	end)
end

function RemoteThrottle.start()
	Players.PlayerRemoving:Connect(forget)
end

return RemoteThrottle
