--!strict
-- Desk Dash run state machine (docs/ARCHITECTURE.md 8.1). Pure: no Roblox APIs, times in ms
-- from the server clock passed in by the caller. Every transition is synchronous.
--
--   Countdown --left start--> Cancelled
--   Countdown --countdown done--> Running
--   Running --checkpoint last+1--> Running
--   Running --finish with all checkpoints--> Finished (valid or not)
--   Running --timeout / leave / restart--> Abandoned
--   Finished(valid) --markRewarded (once)--> Rewarded
--   Finished(invalid) --> Rejected

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Dash = require(ReplicatedStorage.Shared.Config.Dash)

export type State = "Countdown" | "Running" | "Finished" | "Rewarded" | "Rejected" | "Abandoned" | "Cancelled"

export type Run = {
	runId: string,
	state: State,
	countdownStartMs: number,
	startMs: number?,
	lastCheckpoint: number,
	lastSplitMs: number,
	segmentMs: { number },
	timeMs: number?,
	suspicious: boolean,
	rejectReason: string?,
	abandonReason: string?,
}

export type FinishOutcome = "valid" | "rejected" | "missing_checkpoint" | "ignored"

local DashRun = {}

function DashRun.new(runId: string, nowMs: number): Run
	return {
		runId = runId,
		state = "Countdown",
		countdownStartMs = nowMs,
		startMs = nil,
		lastCheckpoint = 0,
		lastSplitMs = 0,
		segmentMs = {},
		timeMs = nil,
		suspicious = false,
		rejectReason = nil,
		abandonReason = nil,
	}
end

function DashRun.isActive(run: Run): boolean
	return run.state == "Countdown" or run.state == "Running"
end

-- Player stepped off the start pad during the countdown.
function DashRun.leaveStart(run: Run): boolean
	if run.state ~= "Countdown" then
		return false
	end
	run.state = "Cancelled"
	return true
end

-- Advances time-based transitions. Returns "started", "timeout" or nil.
function DashRun.tick(run: Run, nowMs: number): string?
	if run.state == "Countdown" and nowMs - run.countdownStartMs >= Dash.CountdownSec * 1000 then
		run.state = "Running"
		run.startMs = nowMs
		run.lastSplitMs = nowMs
		return "started"
	elseif run.state == "Running" and run.startMs and nowMs - run.startMs > Dash.TimeoutSec * 1000 then
		run.state = "Abandoned"
		run.abandonReason = "timeout"
		return "timeout"
	end
	return nil
end

-- Only lastCheckpoint + 1 counts; anything else is ignored (no skipping, no going back).
function DashRun.reachCheckpoint(run: Run, index: number, nowMs: number): boolean
	if run.state ~= "Running" or index ~= run.lastCheckpoint + 1 or index > Dash.CheckpointCount then
		return false
	end
	table.insert(run.segmentMs, nowMs - run.lastSplitMs)
	run.lastSplitMs = nowMs
	run.lastCheckpoint = index
	return true
end

function DashRun.markSuspicious(run: Run)
	if DashRun.isActive(run) then
		run.suspicious = true
	end
end

function DashRun.reachFinish(run: Run, nowMs: number): FinishOutcome
	if run.state ~= "Running" or run.startMs == nil then
		return "ignored"
	end
	if run.lastCheckpoint < Dash.CheckpointCount then
		return "missing_checkpoint"
	end
	table.insert(run.segmentMs, nowMs - run.lastSplitMs)
	run.timeMs = nowMs - run.startMs
	run.state = "Finished"

	local reason: string? = nil
	if run.suspicious then
		reason = "suspicious_movement"
	elseif (run.timeMs :: number) < Dash.MinValidTimeMs then
		reason = "too_fast"
	else
		for i, ms in run.segmentMs do
			local min = Dash.SegmentMinMs[i]
			if min and ms < min then
				reason = `segment_{i}_too_fast`
				break
			end
		end
	end

	if reason then
		run.state = "Rejected"
		run.rejectReason = reason
		return "rejected"
	end
	return "valid"
end

-- The only way to a reward: exactly once, and only from a valid finish.
function DashRun.markRewarded(run: Run): boolean
	if run.state ~= "Finished" then
		return false
	end
	run.state = "Rewarded"
	return true
end

function DashRun.abandon(run: Run, reason: string): boolean
	if not DashRun.isActive(run) then
		return false
	end
	run.state = if run.state == "Countdown" then "Cancelled" else "Abandoned"
	run.abandonReason = reason
	return true
end

-- Axis-aligned point-in-box test for unrotated zones.
function DashRun.inBox(
	px: number,
	py: number,
	pz: number,
	cx: number,
	cy: number,
	cz: number,
	sx: number,
	sy: number,
	sz: number
): boolean
	return math.abs(px - cx) <= sx / 2 and math.abs(py - cy) <= sy / 2 and math.abs(pz - cz) <= sz / 2
end

-- Horizontal movement allowed between two polls `dtSec` apart.
function DashRun.maxStep(dtSec: number): number
	return math.max(Dash.MinStepAllowanceStuds, Dash.MaxHorizontalSpeed * dtSec)
end

return DashRun
