--!nonstrict
-- ROBLOX NOTE: no upstream
-- PARALOV deviation from upstream jest-lua.

local RunService = game:GetService("RunService")

local realTask = task

--[[
	Roblox drops any `task.defer` chained more than 80 resumption cycles deep
	inside one frame. It logs an engine error, and the callback never runs, so
	the thread that awaited it hangs until the test times out. That budget is
	global to the frame, and only a real yield clears it, so a run of specs that
	never yields spends one shared budget between them.

	The margin below 80 covers the defers Jest itself makes, which this counter
	does not see.
]]
local BUDGET_PER_FRAME = 70

local deferredThisFrame = 0
local resetConnection: RBXScriptConnection? = nil

--[[
	`task.defer` for the environment Jest gives the code under test. Over budget,
	the work moves to the next frame: `task.delay(0, ...)` resumes at the next
	Heartbeat, where the budget is fresh.

	The count is of calls, not of chain depth, so it over-estimates. That spends
	a frame earlier than the engine demands, and never later.
]]
local function budgetedDefer(...)
	if deferredThisFrame >= BUDGET_PER_FRAME then
		return realTask.delay(0, ...)
	end

	-- `:Once`, so the reset closes its own connection: this module has no
	-- teardown hook to disconnect from, and a frame that spends no budget needs
	-- no reset. Heartbeat is the only frame signal available -- `time()` and
	-- `DistributedGameTime` both stay at zero while the runner's DataModel is
	-- not running.
	if resetConnection == nil then
		resetConnection = RunService.Heartbeat:Once(function()
			deferredThisFrame = 0
			resetConnection = nil
		end)
	end

	deferredThisFrame += 1
	return realTask.defer(...)
end

return budgetedDefer
