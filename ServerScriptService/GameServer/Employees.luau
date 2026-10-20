local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local EmployeeConfig = require(ReplicatedStorage.Shared.EmployeeConfig)
local EmployeeRoster = require(ReplicatedStorage.Shared.EmployeeRoster)
local GrabConfig = require(ReplicatedStorage.Shared.GrabConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.PlayerAttributes)
local ProductionLineConfig = require(ReplicatedStorage.Shared.ProductionLineConfig)
local ProductionLineSlots = require(ReplicatedStorage.Shared.ProductionLineSlots)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)
local UpgradeEffects = require(ReplicatedStorage.Shared.UpgradeEffects)
local BoltLines = require(script.Parent.BoltLines)
local HeartLine = require(script.Parent.HeartLine)
local PlayerData = require(script.Parent.PlayerData)
local Ragdoll = require(ServerScriptService.SectorTwo.Ragdoll)

local RIG_TEMPLATE_NAME = "EmployeeRig"
local CONTAINER_NAME = "Employees"
local FIRST_WORK_DELAY = 1.5

type Employee = {
	owner: Player,
	line: Instance,
	area: string,
	idleArea: string,
	candidate: EmployeeRoster.Candidate,
	rig: Model,
	baseWorkInterval: number,
	nextWorkAt: number,
}

export type StaffRecord = {
	line: string,
	area: string,
	candidate: string,
}

export type BodyRecord = {
	name: string,
	pivot: CFrame,
}

local Employees = {}

local rigTemplate: Model
local container: Instance
local standHeight: number
local employees: { Employee } = {}

local function heightAboveFeet(model: Model): number
	local boxCFrame, boxSize = model:GetBoundingBox()
	return model:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
end

local function createRig(name: string, owner: Player, pivot: CFrame): Model
	local rig = rigTemplate:Clone()
	rig.Name = name
	rig:SetAttribute(EmployeeConfig.OWNER_ATTRIBUTE, owner.UserId)
	rig:AddTag(EmployeeConfig.TAG)
	rig:PivotTo(pivot)
	rig.Parent = container
	return rig
end

local function spawnRig(owner: Player, line: Instance, candidate: EmployeeRoster.Candidate): Model
	local stand = line:FindFirstChild(ProductionLineConfig.WORKER_STAND_NAME, true) :: Attachment
	return createRig(candidate.name, owner, stand.WorldCFrame * CFrame.new(0, standHeight, 0))
end

local function collapse(rig: Model)
	rig:SetAttribute(EmployeeConfig.KNOCKED_OUT_ATTRIBUTE, true)
	Ragdoll.enable(rig)
	rig:AddTag(GrabConfig.TAG)
end

local function recordStaff(owner: Player)
	local records: { StaffRecord } = {}
	for _, employee in employees do
		if employee.owner == owner then
			table.insert(records, { line = employee.line.Name, area = employee.area, candidate = employee.candidate.name })
		end
	end
	owner:SetAttribute(PlayerAttributes.STAFF, HttpService:JSONEncode(records))
end

local function workInterval(employee: Employee): number
	local staplerLevel = PlayerData.upgradeLevel(employee.owner, ShopCatalog.STAPLER_ITEM_ID)
	return employee.baseWorkInterval / UpgradeEffects.employeeSpeed(staplerLevel)
end

local function work(employee: Employee)
	if employee.area == ProductionLineConfig.BOLT_AREA then
		BoltLines.turn(employee.line, employee.owner)
	elseif employee.area == ProductionLineConfig.HEART_AREA then
		HeartLine.strike(employee.line, employee.owner)
	end
end

local function onHeartbeat()
	local now = os.clock()
	for _, employee in employees do
		if now >= employee.nextWorkAt then
			employee.nextWorkAt = now + workInterval(employee)
			work(employee)
		end
	end
end

local function vacate(employee: Employee)
	employee.line:SetAttribute(ProductionLineConfig.EMPLOYEE_ATTRIBUTE, nil)
	employee.line:SetAttribute(ProductionLineConfig.WORK_AREA_ATTRIBUTE, employee.idleArea)
end

local function dismissAll(owner: Player)
	for index = #employees, 1, -1 do
		local employee = employees[index]
		if employee.owner == owner then
			vacate(employee)
			employee.rig:Destroy()
			table.remove(employees, index)
		end
	end
end

local function findLine(name: string): Instance?
	for _, line in CollectionService:GetTagged(ProductionLineConfig.TAG) do
		if line.Name == name then
			return line
		end
	end
	return nil
end

local function isWorkArea(area: string): boolean
	return area == ProductionLineConfig.BOLT_AREA or area == ProductionLineConfig.HEART_AREA
end

function Employees.hire(owner: Player, line: Instance, area: string, candidate: EmployeeRoster.Candidate)
	local idleArea = line:GetAttribute(ProductionLineConfig.WORK_AREA_ATTRIBUTE) :: string
	line:SetAttribute(ProductionLineConfig.WORK_AREA_ATTRIBUTE, area)
	line:SetAttribute(ProductionLineConfig.EMPLOYEE_ATTRIBUTE, owner.UserId)
	table.insert(employees, {
		owner = owner,
		line = line,
		area = area,
		idleArea = idleArea,
		candidate = candidate,
		rig = spawnRig(owner, line, candidate),
		baseWorkInterval = EmployeeRoster.workInterval(candidate, area),
		nextWorkAt = os.clock() + FIRST_WORK_DELAY,
	})
	recordStaff(owner)
end

function Employees.knockOut(rig: Model)
	for index, employee in employees do
		if employee.rig == rig then
			table.remove(employees, index)
			vacate(employee)
			collapse(rig)
			recordStaff(employee.owner)
			return
		end
	end
end

function Employees.staffOf(player: Player): { StaffRecord }
	local encoded = player:GetAttribute(PlayerAttributes.STAFF)
	if typeof(encoded) ~= "string" then
		return {}
	end
	local isDecoded, records = pcall(HttpService.JSONDecode, HttpService, encoded)
	return if isDecoded and typeof(records) == "table" then records else {}
end

function Employees.restoreStaff(owner: Player, records: { StaffRecord })
	for _, record in records do
		local line = findLine(record.line)
		local candidate = EmployeeRoster.candidateNamed(record.candidate)
		if line and candidate and isWorkArea(record.area) and not ProductionLineSlots.isStaffed(line) then
			Employees.hire(owner, line, record.area, candidate)
		end
	end
end

function Employees.bodies(): { BodyRecord }
	local records: { BodyRecord } = {}
	for _, rig in container:GetChildren() do
		if rig:IsA("Model") and rig:GetAttribute(EmployeeConfig.KNOCKED_OUT_ATTRIBUTE) == true then
			table.insert(records, { name = rig.Name, pivot = rig:GetPivot() })
		end
	end
	return records
end

function Employees.restoreBodies(records: { BodyRecord }, holder: Player)
	for _, record in records do
		local rig = createRig(record.name, holder, record.pivot)
		rig:SetAttribute(GrabConfig.LAST_HOLDER_ATTRIBUTE, holder.UserId)
		collapse(rig)
	end
end

function Employees.start()
	rigTemplate = ServerStorage:WaitForChild(RIG_TEMPLATE_NAME) :: Model
	standHeight = heightAboveFeet(rigTemplate)
	container = Workspace:WaitForChild(CONTAINER_NAME)
	Players.PlayerRemoving:Connect(dismissAll)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return Employees
