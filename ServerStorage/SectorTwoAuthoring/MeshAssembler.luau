local HttpService = game:GetService("HttpService")
local ImportModules = game.ServerStorage.ImportMCP.Main.Modules
local Base64 = require(ImportModules.Runtime.Base64)
local Api = require(game.ServerStorage.ImportMCP.MCP)
local FLOAT_BYTES = 4
local VERTEX_COMPONENTS = 8
local VERTEX_STRIDE = FLOAT_BYTES * VERTEX_COMPONENTS
local COMPONENT_FLOAT = 5126
local COMPONENT_INDEX = 5125
local FULL_UV = {0, 0, 1, 1}
local MeshAssembler = {}
function MeshAssembler.group(name)
	return {name = name, vertices = {}, indices = {}}
end
function MeshAssembler.quad(group, a, b, c, d, uvRectangle)
	local normal = (b - a):Cross(c - a).Unit
	local uv = uvRectangle or FULL_UV
	local coordinates = {{uv[1], uv[4]}, {uv[3], uv[4]}, {uv[3], uv[2]}, {uv[1], uv[2]}}
	local start = #group.vertices
	for index, position in {a, b, c, d} do
		table.insert(group.vertices, {position.X, position.Y, position.Z, normal.X, normal.Y, normal.Z, coordinates[index][1], coordinates[index][2]})
	end
	for _, index in {0, 1, 2, 0, 2, 3} do
		table.insert(group.indices, start + index)
	end
end
function MeshAssembler.box(group, frame, size, uvRectangle)
	local half = size / 2
	local function point(x, y, z)
		return frame:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
	end
	local faces = {
		{{-1, -1, 1}, {1, -1, 1}, {1, 1, 1}, {-1, 1, 1}},
		{{1, -1, -1}, {-1, -1, -1}, {-1, 1, -1}, {1, 1, -1}},
		{{1, -1, 1}, {1, -1, -1}, {1, 1, -1}, {1, 1, 1}},
		{{-1, -1, -1}, {-1, -1, 1}, {-1, 1, 1}, {-1, 1, -1}},
		{{-1, 1, 1}, {1, 1, 1}, {1, 1, -1}, {-1, 1, -1}},
		{{-1, -1, -1}, {1, -1, -1}, {1, -1, 1}, {-1, -1, 1}},
	}
	for _, face in faces do
		local corners = {}
		for _, corner in face do
			table.insert(corners, point(corner[1], corner[2], corner[3]))
		end
		MeshAssembler.quad(group, corners[1], corners[2], corners[3], corners[4], uvRectangle)
	end
end
function MeshAssembler.triangle(group, a, b, c, uvRectangle)
	local normal = (b - a):Cross(c - a).Unit
	local uv = uvRectangle or FULL_UV
	local coordinates = {{uv[1], uv[4]}, {uv[3], uv[4]}, {(uv[1] + uv[3]) / 2, uv[2]}}
	local start = #group.vertices
	for index, position in {a, b, c} do
		table.insert(group.vertices, {position.X, position.Y, position.Z, normal.X, normal.Y, normal.Z, coordinates[index][1], coordinates[index][2]})
		table.insert(group.indices, start + index - 1)
	end
end
function MeshAssembler.taper(group, frame, bottom, top, height, uvRectangle)
	local lower = {}
	local upper = {}
	for _, corner in {{-1, 1}, {1, 1}, {1, -1}, {-1, -1}} do
		table.insert(lower, frame:PointToWorldSpace(Vector3.new(corner[1] * bottom.X / 2, -height / 2, corner[2] * bottom.Y / 2)))
		table.insert(upper, frame:PointToWorldSpace(Vector3.new(corner[1] * top.X / 2, height / 2, corner[2] * top.Y / 2)))
	end
	MeshAssembler.quad(group, upper[1], upper[2], upper[3], upper[4], uvRectangle)
	MeshAssembler.quad(group, lower[4], lower[3], lower[2], lower[1], uvRectangle)
	for index = 1, 4 do
		local nextIndex = index % 4 + 1
		MeshAssembler.quad(group, lower[index], lower[nextIndex], upper[nextIndex], upper[index], uvRectangle)
	end
end
function MeshAssembler.ellipsoid(group, frame, size, segments, rings, uvRectangle)
	local half = size / 2
	local function point(ring, segment)
		local latitude = math.pi * ring / rings
		local longitude = math.pi * 2 * segment / segments
		return frame:PointToWorldSpace(Vector3.new(half.X * math.sin(latitude) * math.cos(longitude), half.Y * math.cos(latitude), half.Z * math.sin(latitude) * math.sin(longitude)))
	end
	for ring = 0, rings - 1 do
		for segment = 0, segments - 1 do
			local a, b = point(ring, segment), point(ring, segment + 1)
			local c, d = point(ring + 1, segment + 1), point(ring + 1, segment)
			if ring == 0 then
				MeshAssembler.triangle(group, a, c, d, uvRectangle)
			elseif ring == rings - 1 then
				MeshAssembler.triangle(group, a, b, c, uvRectangle)
			else
				MeshAssembler.quad(group, a, b, c, d, uvRectangle)
			end
		end
	end
end
function MeshAssembler.document(groups)
	local document = {asset = {version = "2.0", generator = "SectorTwoStudioAuthoring"}, scene = 0, scenes = {{nodes = {}}}, nodes = {}, meshes = {}, buffers = {}, bufferViews = {}, accessors = {}}
	local function accessor(view, offset, componentType, count, shape, minimum, maximum)
		local index = #document.accessors
		table.insert(document.accessors, {bufferView = view, byteOffset = offset, componentType = componentType, count = count, type = shape, min = minimum, max = maximum})
		return index
	end
	for _, group in groups do
		assert(#group.vertices > 0 and #group.indices > 0, "Grupo vazio: " .. group.name)
		local vertexBytes = #group.vertices * VERTEX_STRIDE
		local indexBytes = #group.indices * FLOAT_BYTES
		local data = buffer.create(vertexBytes + indexBytes)
		local minimum = {math.huge, math.huge, math.huge}
		local maximum = {-math.huge, -math.huge, -math.huge}
		for index, vertex in group.vertices do
			for component, value in vertex do
				buffer.writef32(data, (index - 1) * VERTEX_STRIDE + (component - 1) * FLOAT_BYTES, value)
				if component <= 3 then
					minimum[component] = math.min(minimum[component], value)
					maximum[component] = math.max(maximum[component], value)
				end
			end
		end
		for index, value in group.indices do
			buffer.writeu32(data, vertexBytes + (index - 1) * FLOAT_BYTES, value)
		end
		local bufferIndex = #document.buffers
		table.insert(document.buffers, {byteLength = buffer.len(data), uri = "data:application/octet-stream;base64," .. Base64.encode(data)})
		local vertexView = #document.bufferViews
		table.insert(document.bufferViews, {buffer = bufferIndex, byteOffset = 0, byteLength = vertexBytes, byteStride = VERTEX_STRIDE})
		local indexView = #document.bufferViews
		table.insert(document.bufferViews, {buffer = bufferIndex, byteOffset = vertexBytes, byteLength = indexBytes})
		local position = accessor(vertexView, 0, COMPONENT_FLOAT, #group.vertices, "VEC3", minimum, maximum)
		local normal = accessor(vertexView, FLOAT_BYTES * 3, COMPONENT_FLOAT, #group.vertices, "VEC3")
		local uv = accessor(vertexView, FLOAT_BYTES * 6, COMPONENT_FLOAT, #group.vertices, "VEC2")
		local indices = accessor(indexView, 0, COMPONENT_INDEX, #group.indices, "SCALAR")
		local meshIndex = #document.meshes
		table.insert(document.meshes, {name = group.name, primitives = {{attributes = {POSITION = position, NORMAL = normal, TEXCOORD_0 = uv}, indices = indices}}})
		table.insert(document.scenes[1].nodes, #document.nodes)
		table.insert(document.nodes, {name = group.name, mesh = meshIndex})
	end
	return HttpService:JSONEncode(document)
end
function MeshAssembler.queue(groups, name, parent)
	return Api.import({text = MeshAssembler.document(groups), fileName = name .. ".gltf", name = name, persist = "asset", fallback = false, mode = "queue", target = {parent = parent, class = "Model"}, options = {split = "node", center = false, ground = false, anchored = true, canCollide = false, expect = {parts = #groups, noChunks = true}}})
end
return table.freeze(MeshAssembler)
