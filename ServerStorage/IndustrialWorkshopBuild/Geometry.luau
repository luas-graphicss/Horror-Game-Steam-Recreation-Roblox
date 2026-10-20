local AssetService = game:GetService("AssetService")
local Materialize = require(game.ServerStorage.ImportMCP.Main.Modules.Runtime.Materialize)
local Geometry = {}
local Builder = {}
Builder.__index = Builder
local TEXTURE_SCALE = 4
local YIELD_INTERVAL = 192
local MIN_AREA = 0.000001
local DEFAULT_SIDES = 24
local PALETTE = {
 Steel = Color3.fromRGB(79, 84, 82),
 Trim = Color3.fromRGB(112, 118, 115),
 Dark = Color3.fromRGB(35, 40, 41),
 Yellow = Color3.fromRGB(179, 137, 49),
 Red = Color3.fromRGB(138, 40, 33),
 Label = Color3.fromRGB(192, 196, 181)
}
local function projectedUv(position, normal)
 local absolute = Vector3.new(math.abs(normal.X), math.abs(normal.Y), math.abs(normal.Z))
 if absolute.Y >= absolute.X and absolute.Y >= absolute.Z then
  return Vector2.new(position.X, position.Z) / TEXTURE_SCALE
 elseif absolute.X >= absolute.Z then
  return Vector2.new(position.Z, position.Y) / TEXTURE_SCALE
 end
 return Vector2.new(position.X, position.Y) / TEXTURE_SCALE
end
function Geometry.new(name)
 return setmetatable({name = name, vertices = {}, normals = {}, uvs = {}, faces = {}, operations = 0}, Builder)
end
function Builder:triangle(a, b, c, outward, uvs, normals)
 local cross = (b - a):Cross(c - a)
 if cross.Magnitude < MIN_AREA then return end
 if outward and cross:Dot(outward) < 0 then
  b, c = c, b
  if uvs then uvs = {uvs[1], uvs[3], uvs[2]} end
  if normals then normals = {normals[1], normals[3], normals[2]} end
  cross = -cross
 end
 local normal = cross.Unit
 local start = #self.vertices
 for index, position in {a, b, c} do
  table.insert(self.vertices, position)
  table.insert(self.normals, normals and normals[index] or normal)
  table.insert(self.uvs, uvs and uvs[index] or projectedUv(position, normal))
 end
 table.insert(self.faces, {start + 1, start + 2, start + 3})
 self.operations += 1
 if self.operations % YIELD_INTERVAL == 0 then task.wait() end
end
function Builder:quad(a, b, c, d, outward, uvs, normals)
 self:triangle(a, b, c, outward, uvs and {uvs[1], uvs[2], uvs[3]}, normals and {normals[1], normals[2], normals[3]})
 self:triangle(a, c, d, outward, uvs and {uvs[1], uvs[3], uvs[4]}, normals and {normals[1], normals[3], normals[4]})
end
function Builder:box(frame, size, bevel)
 local half = {size.X / 2, size.Y / 2, size.Z / 2}
 local edge = math.clamp(bevel or 0, 0, math.min(half[1], half[2], half[3]) * 0.9)
 local function point(values)
  return frame:PointToWorldSpace(Vector3.new(values[1], values[2], values[3]))
 end
 local function direction(values)
  return frame:VectorToWorldSpace(Vector3.new(values[1], values[2], values[3]))
 end
 for axis = 1, 3 do
  local second = axis % 3 + 1
  local third = second % 3 + 1
  for _, sign in {-1, 1} do
   local corners = {}
   for _, signs in {{-1, -1}, {1, -1}, {1, 1}, {-1, 1}} do
    local values = {0, 0, 0}
    values[axis] = sign * half[axis]
    values[second] = signs[1] * (half[second] - edge)
    values[third] = signs[2] * (half[third] - edge)
    table.insert(corners, point(values))
   end
   local normal = {0, 0, 0}
   normal[axis] = sign
   self:quad(corners[1], corners[2], corners[3], corners[4], direction(normal))
  end
 end
 if edge == 0 then return end
 for axis = 1, 3 do
  local second = axis % 3 + 1
  local third = second % 3 + 1
  for _, firstSign in {-1, 1} do
   for _, secondSign in {-1, 1} do
    local corners = {}
    for _, setting in {{0, -1}, {1, -1}, {1, 1}, {0, 1}} do
     local values = {0, 0, 0}
     values[axis] = firstSign * (half[axis] - setting[1] * edge)
     values[second] = secondSign * (half[second] - (1 - setting[1]) * edge)
     values[third] = setting[2] * (half[third] - edge)
     table.insert(corners, point(values))
    end
    local normal = {0, 0, 0}
    normal[axis] = firstSign
    normal[second] = secondSign
    self:quad(corners[1], corners[2], corners[3], corners[4], direction(normal))
   end
  end
 end
 for _, x in {-1, 1} do
  for _, y in {-1, 1} do
   for _, z in {-1, 1} do
    local a = point({x * half[1], y * (half[2] - edge), z * (half[3] - edge)})
    local b = point({x * (half[1] - edge), y * half[2], z * (half[3] - edge)})
    local c = point({x * (half[1] - edge), y * (half[2] - edge), z * half[3]})
    self:triangle(a, b, c, direction({x, y, z}))
   end
  end
 end
end
function Builder:lathe(frame, profile, sides)
 local count = sides or DEFAULT_SIDES
 for row = 1, #profile do
  local nextRow = row % #profile + 1
  local current = profile[row]
  local following = profile[nextRow]
  local dy = following[1] - current[1]
  local dr = following[2] - current[2]
  for column = 0, count - 1 do
   local angle = column * math.pi * 2 / count
   local nextAngle = (column + 1) * math.pi * 2 / count
   local function vertex(sample, theta)
    return frame:PointToWorldSpace(Vector3.new(math.cos(theta) * sample[2], sample[1], math.sin(theta) * sample[2]))
   end
   local function normal(theta)
    local value = Vector3.new(dy * math.cos(theta), -dr, dy * math.sin(theta))
    return frame:VectorToWorldSpace(value.Magnitude > 0 and value.Unit or Vector3.yAxis)
   end
   local n1, n2 = normal(angle), normal(nextAngle)
   self:quad(vertex(current, angle), vertex(current, nextAngle), vertex(following, nextAngle), vertex(following, angle), n1 + n2, nil, {n1, n2, n2, n1})
  end
 end
end
function Builder:ring(frame, outerRadius, innerRadius, height, sides)
 local half = height / 2
 self:lathe(frame, {{-half, outerRadius}, {half, outerRadius}, {half, innerRadius}, {-half, innerRadius}}, sides)
end
function Builder:rod(startPoint, endPoint, radius, sides)
 local delta = endPoint - startPoint
 local up = delta.Unit
 local reference = math.abs(up.Z) < 0.95 and Vector3.zAxis or Vector3.xAxis
 local right = up:Cross(reference).Unit
 local back = right:Cross(up).Unit
 local frame = CFrame.fromMatrix((startPoint + endPoint) / 2, right, up, back)
 self:ring(frame, radius, 0, delta.Magnitude, sides or 12)
end
function Builder:extrude(frame, polygon, depth)
 local back = -depth / 2
 local front = depth / 2
 local center = Vector2.zero
 for _, point in polygon do center += point end
 center /= #polygon
 local function world(point, z)
  return frame:PointToWorldSpace(Vector3.new(point.X, point.Y, z))
 end
 for index, point in polygon do
  local nextPoint = polygon[index % #polygon + 1]
  self:triangle(world(center, front), world(point, front), world(nextPoint, front), frame.ZVector)
  self:triangle(world(center, back), world(nextPoint, back), world(point, back), -frame.ZVector)
  local outward = frame:VectorToWorldSpace(Vector3.new(nextPoint.Y - point.Y, point.X - nextPoint.X, 0))
  self:quad(world(point, back), world(nextPoint, back), world(nextPoint, front), world(point, front), outward)
 end
end
function Builder:sweep(path, radius, thickness, sides)
 local count = sides or DEFAULT_SIDES
 local inner = radius - thickness
 local rings = {}
 for index, center in path do
  local tangent
  if index == 1 then tangent = path[2] - center
  elseif index == #path then tangent = center - path[index - 1]
  else tangent = path[index + 1] - path[index - 1] end
  tangent = tangent.Unit
  local u = Vector3.zAxis
  local v = tangent:Cross(u).Unit
  rings[index] = {center = center, tangent = tangent, u = u, v = v}
 end
 local function point(ring, angle, r)
  return ring.center + (ring.u * math.cos(angle) + ring.v * math.sin(angle)) * r
 end
 local distance = 0
 for row = 1, #rings - 1 do
  local first, second = rings[row], rings[row + 1]
  local nextDistance = distance + (second.center - first.center).Magnitude
  for column = 0, count - 1 do
   local a = column * math.pi * 2 / count
   local b = (column + 1) * math.pi * 2 / count
   for _, layer in {{radius, 1}, {inner, -1}} do
    local r, sign = layer[1], layer[2]
    local na = (point(first, a, 1) - first.center) * sign
    local nb = (point(first, b, 1) - first.center) * sign
    local nc = (point(second, b, 1) - second.center) * sign
    local nd = (point(second, a, 1) - second.center) * sign
    local uvs = {Vector2.new(a * r, distance) / TEXTURE_SCALE, Vector2.new(b * r, distance) / TEXTURE_SCALE, Vector2.new(b * r, nextDistance) / TEXTURE_SCALE, Vector2.new(a * r, nextDistance) / TEXTURE_SCALE}
    self:quad(point(first, a, r), point(first, b, r), point(second, b, r), point(second, a, r), na + nb + nc + nd, uvs, {na, nb, nc, nd})
   end
  end
  distance = nextDistance
 end
 for _, index in {1, #rings} do
  local ring = rings[index]
  local normal = ring.tangent * (index == 1 and -1 or 1)
  for column = 0, count - 1 do
   local a = column * math.pi * 2 / count
   local b = (column + 1) * math.pi * 2 / count
   self:quad(point(ring, a, radius), point(ring, b, radius), point(ring, b, inner), point(ring, a, inner), normal)
  end
 end
end
function Builder:holeTile(center, width, depth, thickness, radius)
 local sides = 32
 local bottom = center.Y - thickness
 for index = 0, sides - 1 do
  local a = index * math.pi * 2 / sides
  local b = (index + 1) * math.pi * 2 / sides
  local function corners(angle)
   local x, z = math.cos(angle), math.sin(angle)
   local scale = math.min(width / 2 / math.max(math.abs(x), MIN_AREA), depth / 2 / math.max(math.abs(z), MIN_AREA))
   return Vector3.new(center.X + x * radius, center.Y, center.Z + z * radius), Vector3.new(center.X + x * scale, center.Y, center.Z + z * scale)
  end
  local ia, oa = corners(a)
  local ib, ob = corners(b)
  self:quad(ia, ib, ob, oa, Vector3.yAxis)
  local lower = Vector3.new(0, -thickness, 0)
  self:quad(ia + lower, oa + lower, ob + lower, ib + lower, -Vector3.yAxis)
  self:quad(ia, ia + lower, ib + lower, ib, Vector3.new(center.X, center.Y, center.Z) - (ia + ib) / 2)
  self:quad(oa, ob, ob + lower, oa + lower, (oa + ob) / 2 - center)
 end
end
function Geometry.applyStyle(part, style)
 part:SetAttribute("WorkshopMaterial", style)
 local folder = script.Parent:FindFirstChild("Materials")
 local surface = folder and folder:FindFirstChild(style)
 if surface then
  surface:Clone().Parent = part
  part.Color = Color3.new(1, 1, 1)
 else
  part.Color = PALETTE[style] or PALETTE.Steel
 end
 part.Material = style == "Dark" and Enum.Material.SmoothPlastic or Enum.Material.Metal
end
function Builder:commit(parent, style)
 assert(#self.faces > 0, "Empty geometry")
 assert(not parent:FindFirstChild(self.name), "Geometry already exists: " .. self.name)
 local minimum = Vector3.new(math.huge, math.huge, math.huge)
 local maximum = -minimum
 for _, position in self.vertices do
  minimum = Vector3.new(math.min(minimum.X, position.X), math.min(minimum.Y, position.Y), math.min(minimum.Z, position.Z))
  maximum = Vector3.new(math.max(maximum.X, position.X), math.max(maximum.Y, position.Y), math.max(maximum.Z, position.Z))
 end
 local center = (minimum + maximum) / 2
 local mesh = AssetService:CreateEditableMesh()
 assert(mesh, "EditableMesh memory unavailable")
 local vertices, normals, uvs = {}, {}, {}
 for index, position in self.vertices do
  vertices[index] = mesh:AddVertex(position - center)
  normals[index] = mesh:AddNormal(self.normals[index])
  uvs[index] = mesh:AddUV(self.uvs[index])
  if index % YIELD_INTERVAL == 0 then task.wait() end
 end
 for index, face in self.faces do
  local a, b, c = face[1], face[2], face[3]
  local id = mesh:AddTriangle(vertices[a], vertices[b], vertices[c])
  mesh:SetFaceNormals(id, {normals[a], normals[b], normals[c]})
  mesh:SetFaceUVs(id, {uvs[a], uvs[b], uvs[c]})
  if index % YIELD_INTERVAL == 0 then task.wait() end
 end
 local ok, assetId = pcall(Materialize.upload, mesh, Enum.AssetType.Mesh, self.name, {attempts = 1})
 if not ok then mesh:Destroy() error(Materialize.errorText(assetId), 0) end
 local part = Materialize.meshPart(assetId, {CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Precise}, nil, 20)
 mesh:Destroy()
 part.Name = self.name
 part.CFrame = CFrame.new(center)
 part.Anchored = true
 part.CanCollide = false
 part.CanTouch = false
 part.CanQuery = true
 part.CastShadow = true
 part:SetAttribute("VertexCount", #self.vertices)
 part:SetAttribute("TriangleCount", #self.faces)
 Geometry.applyStyle(part, style)
 Materialize.mark(part, "Mesh", {assetId})
 part.Parent = parent
 return {name = self.name, assetId = assetId, triangles = #self.faces, size = tostring(part.Size)}
end
function Geometry.part(parent, name, frame, size, style, collision)
 assert(not parent:FindFirstChild(name), "Part already exists: " .. name)
 local part = Instance.new("Part")
 part.Name = name
 part.Size = size
 part.CFrame = frame
 part.Anchored = true
 part.CanCollide = collision == true
 part.CanTouch = false
 part.TopSurface = Enum.SurfaceType.Smooth
 part.BottomSurface = Enum.SurfaceType.Smooth
 part.Color = PALETTE[style] or PALETTE.Steel
 part.Material = style == "Dark" and Enum.Material.SmoothPlastic or Enum.Material.Metal
 part:SetAttribute("WorkshopMaterial", style)
 part.Parent = parent
 return part
end
return table.freeze(Geometry)
