--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Dash = require(ReplicatedStorage.Shared.Config.Dash)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local DashRun = require(ServerScriptService.Server.Services.Minigames.DashRun)

local COUNTDOWN_MS = Dash.CountdownSec * 1000
local Desk = Tracks.ById.desk
local Keys = Tracks.ById.keys

-- Starts a run at t=0 and returns it in Running state at t=COUNTDOWN_MS.
local function running(): DashRun.Run
	local run = DashRun.new("r1", 0)
	DashRun.tick(run, COUNTDOWN_MS)
	return run
end

-- Passes all checkpoints with `segmentMs` between splits, returns the time of the last split.
local function passAll(run: DashRun.Run, segmentMs: number): number
	local t = COUNTDOWN_MS
	for i = 1, Desk.CheckpointCount do
		t += segmentMs
		DashRun.reachCheckpoint(run, i, t)
	end
	return t
end

describe("DashRun countdown", function()
	it("starts in Countdown and moves to Running after the countdown", function()
		local run = DashRun.new("r1", 0)
		expect(run.state).toBe("Countdown")
		expect(DashRun.tick(run, COUNTDOWN_MS - 1)).toBeNil()
		expect(DashRun.tick(run, COUNTDOWN_MS)).toBe("started")
		expect(run.state).toBe("Running")
		expect(run.startMs).toBe(COUNTDOWN_MS)
	end)

	it("is cancelled when the player leaves the start pad (TEST_PLAN D-03)", function()
		local run = DashRun.new("r1", 0)
		expect(DashRun.leaveStart(run)).toBe(true)
		expect(run.state).toBe("Cancelled")
		expect(DashRun.tick(run, COUNTDOWN_MS)).toBeNil()
	end)
end)

describe("DashRun checkpoints", function()
	it("accepts only the next checkpoint in order", function()
		local run = running()
		expect(DashRun.reachCheckpoint(run, 2, COUNTDOWN_MS + 1000)).toBe(false)
		expect(DashRun.reachCheckpoint(run, 1, COUNTDOWN_MS + 1000)).toBe(true)
		expect(DashRun.reachCheckpoint(run, 1, COUNTDOWN_MS + 2000)).toBe(false)
		expect(run.lastCheckpoint).toBe(1)
	end)

	it("refuses a finish with missing checkpoints (TEST_PLAN D-04)", function()
		local run = running()
		DashRun.reachCheckpoint(run, 1, COUNTDOWN_MS + 10_000)
		expect(DashRun.reachFinish(run, COUNTDOWN_MS + 60_000)).toBe("missing_checkpoint")
		expect(run.state).toBe("Running")
	end)
end)

describe("DashRun finish and reward", function()
	it("a normal run finishes valid and can be rewarded exactly once", function()
		local run = running()
		local t = passAll(run, 12_000)
		expect(DashRun.reachFinish(run, t + 10_000)).toBe("valid")
		expect(run.timeMs).toBe(Desk.CheckpointCount * 12_000 + 10_000)
		expect(DashRun.markRewarded(run)).toBe(true)
		expect(DashRun.markRewarded(run)).toBe(false)
		expect(DashRun.reachFinish(run, t + 11_000)).toBe("ignored")
	end)

	it("rejects a run faster than MinValidTimeMs (TEST_PLAN X-08)", function()
		local run = running()
		-- Every segment is just above its own minimum, but the whole run is below MinValidTimeMs.
		local t = COUNTDOWN_MS
		for i = 1, Desk.CheckpointCount do
			t += Desk.SegmentMinMs[i] + 500
			DashRun.reachCheckpoint(run, i, t)
		end
		expect(DashRun.reachFinish(run, t + Desk.SegmentMinMs[#Desk.SegmentMinMs] + 500)).toBe("rejected")
		expect(run.rejectReason).toBe("too_fast")
		expect(DashRun.markRewarded(run)).toBe(false)
	end)

	it("rejects a run with a too-fast segment even if the total is fine", function()
		local run = running()
		local t = COUNTDOWN_MS
		t += 100 -- teleported to checkpoint 1
		DashRun.reachCheckpoint(run, 1, t)
		for i = 2, Desk.CheckpointCount do
			t += 15_000
			DashRun.reachCheckpoint(run, i, t)
		end
		expect(DashRun.reachFinish(run, t + 10_000)).toBe("rejected")
		expect(run.rejectReason).toBe("segment_1_too_fast")
	end)

	it("rejects a run marked suspicious (position jump, TEST_PLAN X-07)", function()
		local run = running()
		DashRun.markSuspicious(run)
		local t = passAll(run, 12_000)
		expect(DashRun.reachFinish(run, t + 10_000)).toBe("rejected")
		expect(run.rejectReason).toBe("suspicious_movement")
	end)
end)

describe("DashRun abandon and timeout", function()
	it("times out after TimeoutSec (TEST_PLAN D-06)", function()
		local run = running()
		expect(DashRun.tick(run, COUNTDOWN_MS + Desk.TimeoutSec * 1000)).toBeNil()
		expect(DashRun.tick(run, COUNTDOWN_MS + Desk.TimeoutSec * 1000 + 1)).toBe("timeout")
		expect(run.state).toBe("Abandoned")
		expect(DashRun.markRewarded(run)).toBe(false)
	end)

	it("abandons on leave or restart and never rewards (TEST_PLAN D-05)", function()
		local run = running()
		expect(DashRun.abandon(run, "left")).toBe(true)
		expect(run.state).toBe("Abandoned")
		expect(DashRun.abandon(run, "left")).toBe(false)
		expect(DashRun.reachFinish(run, 99_999)).toBe("ignored")
	end)
end)

describe("DashRun helpers", function()
	it("inBox tests an axis-aligned box", function()
		expect(DashRun.inBox(1, 1, 1, 0, 0, 0, 4, 4, 4)).toBe(true)
		expect(DashRun.inBox(2.1, 0, 0, 0, 0, 0, 4, 4, 4)).toBe(false)
	end)

	it("maxStep has a floor and scales with time", function()
		expect(DashRun.maxStep(0.01)).toBe(Dash.MinStepAllowanceStuds)
		expect(DashRun.maxStep(1)).toBe(Dash.MaxHorizontalSpeed)
	end)
end)

describe("DashRun with several tracks", function()
	it("a run keeps the limits of its own track", function()
		local run = DashRun.new("k1", 0, Keys)
		expect(run.track.Id).toBe("keys")
		DashRun.tick(run, COUNTDOWN_MS)
		local t = COUNTDOWN_MS
		for i = 1, Keys.CheckpointCount do
			t += Keys.SegmentMinMs[i] + 500
			expect(DashRun.reachCheckpoint(run, i, t)).toBe(true)
		end
		-- Keys.MinValidTimeMs is a little lower than Desk's: a run of exactly that time is valid ...
		local finishAt = COUNTDOWN_MS + Keys.MinValidTimeMs + 500
		expect(DashRun.reachFinish(run, finishAt)).toBe("valid")
	end)

	it("the same time is too fast on Desk Dash", function()
		local run = DashRun.new("d1", 0, Desk)
		DashRun.tick(run, COUNTDOWN_MS)
		local t = COUNTDOWN_MS
		for i = 1, Desk.CheckpointCount do
			t += Desk.SegmentMinMs[i] + 500
			DashRun.reachCheckpoint(run, i, t)
		end
		local finishAt = COUNTDOWN_MS + Keys.MinValidTimeMs + 500
		expect(Keys.MinValidTimeMs).toBeLessThan(Desk.MinValidTimeMs)
		expect(DashRun.reachFinish(run, finishAt)).toBe("rejected")
		expect(run.rejectReason).toBe("too_fast")
	end)

	it("defaults to Desk Dash when no track is given", function()
		expect(DashRun.new("x", 0).track.Id).toBe("desk")
	end)

	it("rejects a too-fast segment on the keys track by its own minimum", function()
		local run = DashRun.new("k2", 0, Keys)
		DashRun.tick(run, COUNTDOWN_MS)
		local t = COUNTDOWN_MS + 1_000 -- first segment far below Keys.SegmentMinMs[1]
		DashRun.reachCheckpoint(run, 1, t)
		for i = 2, Keys.CheckpointCount do
			t += 20_000
			DashRun.reachCheckpoint(run, i, t)
		end
		expect(DashRun.reachFinish(run, t + 20_000)).toBe("rejected")
		expect(run.rejectReason).toBe("segment_1_too_fast")
	end)
end)

return nil
