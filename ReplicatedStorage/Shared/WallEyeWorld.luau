local SOCKET_NAME = "Socket"
local ROAM_VOLUME_NAME = "RoamVolume"
local EYE_REST_NAME = "EyeRest"
local CORD_MOUTH_NAME = "CordMouth"
local CORD_SINK_NAME = "CordSink"
local EYE_MODEL_NAME = "Eye"
local NEST_MODEL_NAME = "Nest"
local CORD_MODEL_NAME = "Cord"
local RIG_ROOT_NAME = "RootPart"
local SCLERA_NAME = "Sclera"
local IRIS_NAME = "Iris"
local CORNEA_NAME = "Cornea"
local PUPIL_NAME = "Pupil"
local MUSCLES_NAME = "Muscles"
local NEST_FLESH_NAME = "NestFlesh"
local NEST_THROAT_NAME = "NestThroat"
local NEST_VEINS_NAME = "NestVeins"
local CORD_MESH_NAME = "Cord"

export type Instances = {
	model: Model,
	socket: BasePart,
	roamVolume: BasePart,
	eyeRest: Attachment,
	cordMouth: Attachment,
	cordSink: Attachment,
	eye: Model,
	sclera: BasePart,
	iris: BasePart,
	cornea: BasePart,
	pupil: BasePart,
	muscles: BasePart,
	nestRoot: BasePart,
	nestFlesh: BasePart,
	nestThroat: BasePart,
	nestVeins: BasePart,
	cordRoot: BasePart,
	cord: BasePart,
}

export type EyeParts = {
	eye: Model,
	sclera: BasePart,
	iris: BasePart,
	cornea: BasePart,
	pupil: BasePart,
	muscles: BasePart,
}

local WallEyeWorld = {}

function WallEyeWorld.resolveEye(holder: Instance): EyeParts
	local eye = holder:WaitForChild(EYE_MODEL_NAME) :: Model
	return {
		eye = eye,
		sclera = eye:WaitForChild(SCLERA_NAME) :: BasePart,
		iris = eye:WaitForChild(IRIS_NAME) :: BasePart,
		cornea = eye:WaitForChild(CORNEA_NAME) :: BasePart,
		pupil = eye:WaitForChild(PUPIL_NAME) :: BasePart,
		muscles = eye:WaitForChild(MUSCLES_NAME) :: BasePart,
	}
end

function WallEyeWorld.resolve(model: Model): Instances
	local socket = model:WaitForChild(SOCKET_NAME) :: BasePart
	local eyeParts = WallEyeWorld.resolveEye(model)
	local nest = model:WaitForChild(NEST_MODEL_NAME)
	local cord = model:WaitForChild(CORD_MODEL_NAME)
	return {
		model = model,
		socket = socket,
		roamVolume = model:WaitForChild(ROAM_VOLUME_NAME) :: BasePart,
		eyeRest = socket:WaitForChild(EYE_REST_NAME) :: Attachment,
		cordMouth = socket:WaitForChild(CORD_MOUTH_NAME) :: Attachment,
		cordSink = socket:WaitForChild(CORD_SINK_NAME) :: Attachment,
		eye = eyeParts.eye,
		sclera = eyeParts.sclera,
		iris = eyeParts.iris,
		cornea = eyeParts.cornea,
		pupil = eyeParts.pupil,
		muscles = eyeParts.muscles,
		nestRoot = nest:WaitForChild(RIG_ROOT_NAME) :: BasePart,
		nestFlesh = nest:WaitForChild(NEST_FLESH_NAME) :: BasePart,
		nestThroat = nest:WaitForChild(NEST_THROAT_NAME) :: BasePart,
		nestVeins = nest:WaitForChild(NEST_VEINS_NAME) :: BasePart,
		cordRoot = cord:WaitForChild(RIG_ROOT_NAME) :: BasePart,
		cord = cord:WaitForChild(CORD_MESH_NAME) :: BasePart,
	}
end

function WallEyeWorld.findSclera(model: Instance): BasePart?
	local eye = model:FindFirstChild(EYE_MODEL_NAME)
	local sclera = eye and eye:FindFirstChild(SCLERA_NAME)
	return if sclera and sclera:IsA("BasePart") then sclera else nil
end

function WallEyeWorld.findSocket(model: Instance): BasePart?
	local socket = model:FindFirstChild(SOCKET_NAME)
	return if socket and socket:IsA("BasePart") then socket else nil
end

return WallEyeWorld
