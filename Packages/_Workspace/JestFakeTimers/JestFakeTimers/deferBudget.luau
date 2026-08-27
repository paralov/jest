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

RunService.Heartbeat:Connect(function()
	deferredThisFrame = 0
end)

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

	deferredThisFrame += 1
	return realTask.defer(...)
end

return budgetedDefer
