local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GrabConfig = require(ReplicatedStorage.Shared.GrabConfig)

local PlacedBodies = {}

local placedByPath: { [string]: Instance } = {}

function PlacedBodies.consumed(): { string }
	local paths = {}
	for path, body in placedByPath do
		if not body:IsDescendantOf(Workspace) then
			table.insert(paths, path)
		end
	end
	return paths
end

function PlacedBodies.restore(consumedPaths: { string })
	for _, path in consumedPaths do
		local body = placedByPath[path]
		if body and body:IsDescendantOf(Workspace) then
			body:Destroy()
		end
	end
end

function PlacedBodies.start()
	for _, body in CollectionService:GetTagged(GrabConfig.TAG) do
		if body:IsDescendantOf(Workspace) then
			placedByPath[body:GetFullName()] = body
		end
	end
end

return PlacedBodies
