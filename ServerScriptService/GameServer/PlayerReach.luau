local PlayerCapture = require(script.Parent.PlayerCapture)
local SectorAccess = require(script.Parent.SectorAccess)

local PlayerReach = {}

function PlayerReach.isWithin(player: Player, position: Vector3, range: number): boolean
	if PlayerCapture.isCaptured(player) then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local rootPart = humanoid.RootPart
	return rootPart ~= nil and (rootPart.Position - position).Magnitude <= range and SectorAccess.isReachable(position)
end

return PlayerReach
