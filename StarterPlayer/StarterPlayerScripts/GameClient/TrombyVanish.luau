local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local TrombyDialogue = require(script.Parent:WaitForChild("TrombyDialogue"))
local VanishWhenUnseen = require(script.Parent:WaitForChild("VanishWhenUnseen"))

local TrombyVanish = {}

local function dismiss()
	Remotes.DismissTromby:FireServer()
end

local function vanishOnceUnseen(tromby: Model)
	VanishWhenUnseen.watch(tromby, dismiss)
end

function TrombyVanish.start()
	TrombyDialogue.finished:Connect(vanishOnceUnseen)
end

return TrombyVanish
