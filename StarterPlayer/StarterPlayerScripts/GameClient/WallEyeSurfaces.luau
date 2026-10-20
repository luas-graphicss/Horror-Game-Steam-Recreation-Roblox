local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WallEyeConfig = require(Shared:WaitForChild("WallEyeConfig"))
local WallEyeWorld = require(Shared:WaitForChild("WallEyeWorld"))

local TEXTURES_NAME = "WallEyeTextures"
local TEXTURE_TIMEOUT = 90
local TEXTURE_POLL_INTERVAL = 0.25
local SURFACE_SUFFIX = "Surface"
local EYE_MATERIAL = "Eye"
local IRIS_MATERIAL = "Iris"
local FLESH_MATERIAL = "Flesh"
local NERVE_MATERIAL = "Nerve"
local MAP_SUFFIXES = {
	ColorMap = "_Color",
	NormalMap = "_Normal",
	RoughnessMap = "_Roughness",
}
local PARTS_BY_MATERIAL: { [string]: (WallEyeWorld.Instances) -> { BasePart } } = {
	[EYE_MATERIAL] = function(world)
		return { world.sclera }
	end,
	[IRIS_MATERIAL] = function(world)
		return { world.iris }
	end,
	[FLESH_MATERIAL] = function(world)
		return { world.muscles, world.nestFlesh, world.nestThroat, world.nestVeins }
	end,
	[NERVE_MATERIAL] = function(world)
		return { world.cord }
	end,
}
local LOOSE_EYE_PARTS_BY_MATERIAL: { [string]: (WallEyeWorld.EyeParts) -> { BasePart } } = {
	[EYE_MATERIAL] = function(eye)
		return { eye.sclera }
	end,
	[IRIS_MATERIAL] = function(eye)
		return { eye.iris }
	end,
	[FLESH_MATERIAL] = function(eye)
		return { eye.muscles }
	end,
}
local EYE_TAGS = { WallEyeConfig.TAG, WallEyeConfig.LOOSE_EYE_TAG }

type SurfaceMaps = { [string]: Content }

local WallEyeSurfaces = {}

local loadedMaps: { [string]: SurfaceMaps } = {}

local function hasContent(content: Content): boolean
	return content.SourceType ~= Enum.ContentSourceType.None
end

local function awaitTexture(holder: Instance, name: string): Content?
	local decal = holder:WaitForChild(name, TEXTURE_TIMEOUT)
	if not decal or not decal:IsA("Decal") then
		return nil
	end
	local deadline = os.clock() + TEXTURE_TIMEOUT
	while not hasContent(decal.TextureContent) do
		if os.clock() > deadline then
			return nil
		end
		task.wait(TEXTURE_POLL_INTERVAL)
	end
	return decal.TextureContent
end

local function toEditableImageContent(content: Content): Content
	if content.SourceType == Enum.ContentSourceType.Object then
		return content
	end
	local image = AssetService:CreateEditableImageAsync(content)
	assert(image, "sem memoria disponivel para EditableImage")
	return Content.fromObject(image)
end

local function loadMaps(holder: Instance, materialName: string): SurfaceMaps?
	local maps = {}
	for key, suffix in MAP_SUFFIXES do
		local textureName = materialName .. suffix
		local content = awaitTexture(holder, textureName)
		if not content then
			warn(`WallEyeSurfaces: textura {textureName} indisponivel; mantendo a cor base.`)
			return nil
		end
		local ok, result = pcall(toEditableImageContent, content)
		if not ok then
			warn(`WallEyeSurfaces: falha ao preparar {textureName}: {result}`)
			return nil
		end
		maps[key] = result
	end
	return maps
end

local function dressPart(part: BasePart, materialName: string, maps: SurfaceMaps)
	local ok, result = pcall(AssetService.CreateSurfaceAppearanceAsync, AssetService, maps)
	if not ok then
		warn(`WallEyeSurfaces: falha ao montar {materialName} em {part.Name}: {result}`)
		return
	end
	local surface = result :: SurfaceAppearance
	surface.Name = materialName .. SURFACE_SUFFIX
	surface.Parent = part
end

local function partsToDress(eye: Model, materialName: string): { BasePart }
	if eye:HasTag(WallEyeConfig.LOOSE_EYE_TAG) then
		local pickParts = LOOSE_EYE_PARTS_BY_MATERIAL[materialName]
		return if pickParts then pickParts(WallEyeWorld.resolveEye(eye)) else {}
	end
	return PARTS_BY_MATERIAL[materialName](WallEyeWorld.resolve(eye))
end

local function dressEye(instance: Instance, materialName: string)
	local maps = loadedMaps[materialName]
	if not maps or not instance:IsA("Model") then
		return
	end
	for _, part in partsToDress(instance, materialName) do
		dressPart(part, materialName, maps)
	end
end

local function onEyeAdded(instance: Instance)
	for materialName in loadedMaps do
		task.spawn(dressEye, instance, materialName)
	end
end

local function prepareMaterial(holder: Instance, materialName: string)
	local maps = loadMaps(holder, materialName)
	if not maps then
		return
	end
	loadedMaps[materialName] = maps
	for _, tag in EYE_TAGS do
		for _, eye in CollectionService:GetTagged(tag) do
			task.spawn(dressEye, eye, materialName)
		end
	end
end

function WallEyeSurfaces.start()
	local holder = ReplicatedStorage:WaitForChild(TEXTURES_NAME)
	for _, tag in EYE_TAGS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(onEyeAdded)
	end
	for materialName in PARTS_BY_MATERIAL do
		task.spawn(prepareMaterial, holder, materialName)
	end
end

return WallEyeSurfaces
