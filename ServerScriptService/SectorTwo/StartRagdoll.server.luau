local Ragdoll = require(script.Parent.Ragdoll)
local RIG_PATH = {"MetalBox", "SectorTwo", "Props", "BodyRig"}
local LOAD_TIMEOUT = 15
local rig = workspace
for _, name in RIG_PATH do
	rig = rig:WaitForChild(name, LOAD_TIMEOUT)
	assert(rig, "The sector two ragdoll was not loaded")
end
Ragdoll.enable(rig)
