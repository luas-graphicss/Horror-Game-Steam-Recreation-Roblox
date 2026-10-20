local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BODY_TAG = "SectorTwoContinuousBody"
local HEART_TAG = "SectorTwoCardiacMaterial"
local bodies = {}
local materialBindings = {}

local function bindBody(body)
	if bodies[body] or not body:IsDescendantOf(Workspace) then return end
	local skin = body:FindFirstChild("ContinuousSkin")
	local pelvis = body:FindFirstChild("LowerTorso")
	if not skin or not skin:IsA("Model") or not pelvis or not pelvis:IsA("BasePart") then return end
	local entries = {}
	for _, bone in skin:GetDescendants() do
		if bone:IsA("Bone") then
			local proxy = body:FindFirstChild(bone.Name)
			local offset = bone:GetAttribute("PhysicsToBind")
			if proxy and proxy:IsA("BasePart") and typeof(offset) == "CFrame" then
				local depth = 0
				local parent = bone.Parent
				while parent and parent:IsA("Bone") do
					depth += 1
					parent = parent.Parent
				end
				table.insert(entries, {bone = bone, proxy = proxy, offset = offset, depth = depth})
			end
		end
	end
	if #entries ~= 15 then return end
	table.sort(entries, function(a, b) return a.depth < b.depth end)
	bodies[body] = {skin = skin, pelvis = pelvis, entries = entries}
end

local function removeBody(body)
	bodies[body] = nil
end

local function unbindMaterial(heart)
	local connections = materialBindings[heart]
	if not connections then return end
	for _, connection in connections do connection:Disconnect() end
	materialBindings[heart] = nil
end

local function bindMaterial(heart)
	if materialBindings[heart] or not heart:IsDescendantOf(Workspace) then return end
	local appearance = heart:FindFirstChild("CardiacTissue")
	local sources = heart:FindFirstChild("MaterialSources")
	if not appearance or not sources then return end
	local normal = sources:FindFirstChild("HeartNormal")
	local roughness = sources:FindFirstChild("HeartRoughness")
	if not normal or not roughness then return end
	local function apply()
		if not heart.Parent then return end
		if heart:GetAttribute("ImportMCP_Status") ~= "Ready"
			or normal:GetAttribute("ImportMCP_Status") ~= "Ready"
			or roughness:GetAttribute("ImportMCP_Status") ~= "Ready" then return end
		appearance.ColorMapContent = heart.TextureContent
		appearance.NormalMapContent = normal.ImageContent
		appearance.RoughnessMapContent = roughness.ImageContent
	end
	materialBindings[heart] = {
		heart:GetAttributeChangedSignal("ImportMCP_Status"):Connect(apply),
		normal:GetAttributeChangedSignal("ImportMCP_Status"):Connect(apply),
		roughness:GetAttributeChangedSignal("ImportMCP_Status"):Connect(apply),
	}
	apply()
end

CollectionService:GetInstanceAddedSignal(BODY_TAG):Connect(bindBody)
CollectionService:GetInstanceRemovedSignal(BODY_TAG):Connect(removeBody)
CollectionService:GetInstanceAddedSignal(HEART_TAG):Connect(bindMaterial)
CollectionService:GetInstanceRemovedSignal(HEART_TAG):Connect(unbindMaterial)

for _, body in CollectionService:GetTagged(BODY_TAG) do bindBody(body) end
for _, heart in CollectionService:GetTagged(HEART_TAG) do bindMaterial(heart) end

RunService.PreRender:Connect(function()
	for body, state in bodies do
		if not body:IsDescendantOf(Workspace) or not state.pelvis.Parent or not state.skin.Parent then
			bodies[body] = nil
			continue
		end
		state.skin:PivotTo(state.pelvis.CFrame)
		for _, entry in state.entries do
			local bone = entry.bone
			local parent = bone.Parent
			if not parent or not entry.proxy.Parent then continue end
			local parentWorld = if parent:IsA("Bone") then parent.TransformedWorldCFrame else parent.CFrame
			local targetWorld = entry.proxy.CFrame * entry.offset
			bone.Transform = bone.CFrame:Inverse() * parentWorld:Inverse() * targetWorld
		end
	end
end)
