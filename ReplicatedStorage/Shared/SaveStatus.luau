local LOADING = "Loading"
local RESUMED = "Resumed"
local FRESH = "Fresh"
local OFFLINE = "Offline"

local SaveStatus = {
	LOADING = LOADING,
	RESUMED = RESUMED,
	FRESH = FRESH,
	OFFLINE = OFFLINE,
}

function SaveStatus.isReady(status: unknown): boolean
	return status == RESUMED or status == FRESH or status == OFFLINE
end

return SaveStatus
