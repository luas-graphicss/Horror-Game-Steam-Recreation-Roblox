local Players = game:GetService("Players")

local WORK_GRACE_PERIOD = 3

local WorkActivity = {}

local lastWorkedAt: { [Player]: number } = {}

local function forget(player: Player)
	lastWorkedAt[player] = nil
end

function WorkActivity.record(player: Player)
	lastWorkedAt[player] = os.clock()
end

function WorkActivity.isWorking(player: Player): boolean
	local workedAt = lastWorkedAt[player]
	return workedAt ~= nil and os.clock() - workedAt <= WORK_GRACE_PERIOD
end

function WorkActivity.start()
	Players.PlayerRemoving:Connect(forget)
end

return WorkActivity
