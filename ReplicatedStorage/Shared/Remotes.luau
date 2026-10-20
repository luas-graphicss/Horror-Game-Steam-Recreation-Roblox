local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTES_FOLDER_NAME = "Remotes"
local PURCHASE_ITEM_NAME = "PurchaseItem"
local TIGHTEN_BOLT_NAME = "TightenBolt"
local SET_CRANKING_NAME = "SetCranking"
local ANSWER_PHONE_NAME = "AnswerPhone"
local TALK_TO_TROMBY_NAME = "TalkToTromby"
local DISMISS_TROMBY_NAME = "DismissTromby"
local OPEN_SECTOR_DOOR_NAME = "OpenSectorDoor"
local EQUIP_TOOL_NAME = "EquipTool"
local PRY_EYE_NAME = "PryEye"
local GRAB_BODY_NAME = "GrabBody"
local RELEASE_BODY_NAME = "ReleaseBody"
local STRIKE_HEART_NAME = "StrikeHeart"
local UNLOCK_HIRING_NAME = "UnlockHiring"
local HIRE_EMPLOYEE_NAME = "HireEmployee"
local STRIKE_EMPLOYEE_NAME = "StrikeEmployee"
local TALK_TO_TROMBY_WATCHER_NAME = "TalkToTrombyWatcher"
local ANSWER_TROMBY_WATCHER_NAME = "AnswerTrombyWatcher"
local DISMISS_TROMBY_WATCHER_NAME = "DismissTrombyWatcher"
local BEGIN_SHIFT_NAME = "BeginShift"
local CHANGE_SETTING_NAME = "ChangeSetting"

local folder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME)

return {
	PurchaseItem = folder:WaitForChild(PURCHASE_ITEM_NAME) :: RemoteEvent,
	TightenBolt = folder:WaitForChild(TIGHTEN_BOLT_NAME) :: RemoteEvent,
	SetCranking = folder:WaitForChild(SET_CRANKING_NAME) :: RemoteEvent,
	AnswerPhone = folder:WaitForChild(ANSWER_PHONE_NAME) :: RemoteEvent,
	TalkToTromby = folder:WaitForChild(TALK_TO_TROMBY_NAME) :: RemoteEvent,
	DismissTromby = folder:WaitForChild(DISMISS_TROMBY_NAME) :: RemoteEvent,
	OpenSectorDoor = folder:WaitForChild(OPEN_SECTOR_DOOR_NAME) :: RemoteEvent,
	EquipTool = folder:WaitForChild(EQUIP_TOOL_NAME) :: RemoteEvent,
	PryEye = folder:WaitForChild(PRY_EYE_NAME) :: RemoteEvent,
	GrabBody = folder:WaitForChild(GRAB_BODY_NAME) :: RemoteEvent,
	ReleaseBody = folder:WaitForChild(RELEASE_BODY_NAME) :: RemoteEvent,
	StrikeHeart = folder:WaitForChild(STRIKE_HEART_NAME) :: RemoteEvent,
	UnlockHiring = folder:WaitForChild(UNLOCK_HIRING_NAME) :: RemoteEvent,
	HireEmployee = folder:WaitForChild(HIRE_EMPLOYEE_NAME) :: RemoteEvent,
	StrikeEmployee = folder:WaitForChild(STRIKE_EMPLOYEE_NAME) :: RemoteEvent,
	TalkToTrombyWatcher = folder:WaitForChild(TALK_TO_TROMBY_WATCHER_NAME) :: RemoteEvent,
	AnswerTrombyWatcher = folder:WaitForChild(ANSWER_TROMBY_WATCHER_NAME) :: RemoteEvent,
	DismissTrombyWatcher = folder:WaitForChild(DISMISS_TROMBY_WATCHER_NAME) :: RemoteEvent,
	BeginShift = folder:WaitForChild(BEGIN_SHIFT_NAME) :: RemoteEvent,
	ChangeSetting = folder:WaitForChild(CHANGE_SETTING_NAME) :: RemoteEvent,
}
