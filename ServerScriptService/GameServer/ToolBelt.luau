local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAttributes = require(ReplicatedStorage.Shared.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ToolCatalog = require(ReplicatedStorage.Shared.ToolCatalog)
local PlayerData = require(script.Parent.PlayerData)
local RemoteThrottle = require(script.Parent.RemoteThrottle)

local EQUIP_REQUESTS_PER_SECOND = 10

local ToolBelt = {}

function ToolBelt.equip(player: Player, itemId: string)
	player:SetAttribute(PlayerAttributes.EQUIPPED_TOOL, itemId)
end

function ToolBelt.isEquipped(player: Player, itemId: string): boolean
	return player:GetAttribute(PlayerAttributes.EQUIPPED_TOOL) == itemId and PlayerData.ownsItem(player, itemId)
end

local function onEquipRequested(player: Player, itemId: unknown)
	if typeof(itemId) == "string" and ToolCatalog.isTool(itemId) and PlayerData.ownsItem(player, itemId) then
		ToolBelt.equip(player, itemId)
	end
end

function ToolBelt.start()
	RemoteThrottle.connect(Remotes.EquipTool, EQUIP_REQUESTS_PER_SECOND, onEquipRequested)
end

return ToolBelt
