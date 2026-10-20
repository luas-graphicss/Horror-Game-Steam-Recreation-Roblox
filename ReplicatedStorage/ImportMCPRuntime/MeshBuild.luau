local Limits=require(script.Parent.Limits)
local Codec=require(script.Parent.Codec)
local Partitioner=require(script.Parent.Partitioner)
local ImageBuild=require(script.Parent.ImageBuild)
local Yield=require(script.Parent.Yield)
local AssetService=game:GetService("AssetService")

local MeshBuild={}

local retained={}

local function bake(object,label,check)
	local ok,result,content=pcall(function() return AssetService:CreateDataModelContentAsync(Content.fromObject(object)) end)
	if check then check() end
	if ok and typeof(result)=="EnumItem" and result.Name=="Success" and typeof(content)=="Content" then
		return content,true
	end
	if ok and typeof(result)=="EnumItem" and result.Name~="Success" then
		error(label..": "..tostring(result).." / "..tostring(content),0)
	end
	return Content.fromObject(object),false
end

function MeshBuild.parts(root)
	if root:IsA("MeshPart") then return {root} end
	local parts={}
	for _,child in ipairs(root:GetChildren()) do
		if child:IsA("MeshPart") and child:GetAttribute("ImportMCP_Geometry")==true then parts[#parts+1]=child end
	end
	table.sort(parts,function(a,b) return (a:GetAttribute("ImportMCP_Chunk") or 1)<(b:GetAttribute("ImportMCP_Chunk") or 1) end)
	return parts
end

local function chunkCenter(group,ids)
	local low,high
	for _,id in ipairs(ids) do
		local position=Codec.readPosition(group,id)
		low=low and low:Min(position) or position
		high=high and high:Max(position) or position
	end
	return (low+high)*0.5
end

function MeshBuild.build(snapshot,options)
	options=options or {}
	local meta=snapshot.meta
	local function check()
		if options.check then options.check() end
	end
	local yield=options.yield or Yield.ticker(options.check)
	check()
	local model=Instance.new("Model")
	model.Name=options.name or meta.name
	model.WorldPivot=CFrame.new()
	local mesh,loosePart
	local report={chunks=0,triangles=0,vertices=0,textures=0,dropped=0}
	local ok,err=xpcall(function()
		local contents={}
		for index,texture in ipairs(snapshot.textures) do
			local content=ImageBuild.fromBytes(texture.bytes,{yield=yield,check=check})
			contents[index]=content
			report.textures+=1
			check()
		end
		local chunkIndex=0
		local singleChunk=#snapshot.groups==1
		for gi,group in ipairs(snapshot.groups) do
			local plan=Partitioner.split(group.vertexCount,group.triangleCount,function(ti) return Codec.readTriangle(group,ti) end,{yieldFn=yield})
			if #plan>1 then singleChunk=false end
			for ci,cluster in ipairs(plan) do
				check()
				chunkIndex+=1
				mesh=AssetService:CreateEditableMesh()
				assert(mesh,"EditableMesh indisponivel na submalha "..chunkIndex..".")
				local center=chunkCenter(group,cluster.vertices)
				local ids,uvIds,normalIds={},{},{}
				for n,id in ipairs(cluster.vertices) do
					local position,normal,uv=Codec.readVertex(group,id)
					ids[id]=mesh:AddVertex(position-center)
					uvIds[id]=mesh:AddUV(uv)
					normalIds[id]=normal.Magnitude>=0.5 and mesh:AddNormal(normal.Unit) or false
					if n%Limits.YIELD_EVERY==0 then yield() end
				end
				local added=0
				for n,ti in ipairs(cluster.triangles) do
					local a,b,c=Codec.readTriangle(group,ti)
					local faceOk,face=pcall(mesh.AddTriangle,mesh,ids[a],ids[b],ids[c])
					if faceOk and face then
						added+=1
						mesh:SetFaceUVs(face,{uvIds[a],uvIds[b],uvIds[c]})
						if normalIds[a] and normalIds[b] and normalIds[c] then
							mesh:SetFaceNormals(face,{normalIds[a],normalIds[b],normalIds[c]})
						end
					else
						report.dropped+=1
					end
					if n%Limits.YIELD_EVERY==0 then yield() end
				end
				assert(added>0,"Submalha "..chunkIndex.." sem triangulos validos.")
				local content,baked=bake(mesh,"Conversao da submalha "..chunkIndex,check)
				if baked then mesh:Destroy() else retained[#retained+1]=mesh end
				mesh=nil
				local collision=options.collisionByChunk and options.collisionByChunk[chunkIndex] or meta.collision
				loosePart=AssetService:CreateMeshPartAsync(content,{CollisionFidelity=Enum.CollisionFidelity[collision],RenderFidelity=Enum.RenderFidelity.Precise})
				check()
				assert(loosePart,"CreateMeshPartAsync nao retornou a submalha "..chunkIndex..".")
				local part=loosePart
				part.Name=singleChunk and model.Name or string.format("%s_%02d_%03d",group.name,gi,ci)
				part.Anchored=meta.anchored~=false
				part.CanCollide=meta.canCollide~=false
				part.CanQuery=true
				part.CanTouch=true
				part.CastShadow=true
				part.Color=group.color
				part.Transparency=group.transparency
				part.Material=Enum.Material.SmoothPlastic
				part.DoubleSided=group.doubleSided or meta.doubleSided==true
				local size=part.MeshSize
				part.Size=Vector3.new(math.max(size.X,0.001),math.max(size.Y,0.001),math.max(size.Z,0.001))
				part.CFrame=CFrame.new(center)
				if group.texture and contents[group.texture] then part.TextureContent=contents[group.texture] end
				part:SetAttribute("ImportMCP_Geometry",true)
				part:SetAttribute("ImportMCP_Chunk",chunkIndex)
				part:SetAttribute("ImportMCP_Group",gi)
				part:SetAttribute("ImportMCP_Triangles",added)
				part:SetAttribute("ImportMCP_Vertices",#cluster.vertices)
				part.Parent=model
				loosePart=nil
				report.chunks+=1
				report.triangles+=added
				report.vertices+=#cluster.vertices
			end
		end
		check()
		model:SetAttribute("ImportMCP_Chunks",chunkIndex)
	end,debug.traceback)
	if mesh then mesh:Destroy() end
	if not ok then
		if loosePart then loosePart:Destroy() end
		model:Destroy()
		error("ImportMCP: reconstrucao cancelada sem inserir geometria parcial. Confira Mesh/Image APIs e memoria. "..tostring(err),0)
	end
	return model,report
end

function MeshBuild.unwrap(model)
	local parts=MeshBuild.parts(model)
	if #parts==1 then
		local part=parts[1]
		for _,child in ipairs(model:GetChildren()) do
			if child~=part then child.Parent=part end
		end
		for name,value in pairs(model:GetAttributes()) do part:SetAttribute(name,value) end
		part.Parent=nil
		model:Destroy()
		return part
	end
	return model
end

return table.freeze(MeshBuild)
