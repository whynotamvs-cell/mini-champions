--!strict
-- Desk Dash runtime settings. Timing thresholds live in Config.Economy (single source of truth).

local Economy = require(script.Parent.Economy)

export type CheckpointDetection = "Touched" | "Poll"

local Dash = table.freeze({
	CheckpointCount = 4,
	CountdownSec = 3,

	TimeoutSec = Economy.DashTiming.TimeoutSec,
	MinValidTimeMs = Economy.DashTiming.MinValidTimeMs,

	-- Minimum time per segment: start->cp1, cp1->cp2, cp2->cp3, cp3->cp4, cp4->finish.
	-- ~70% of the segment length at walk speed for the gray-box track (tools/gen_world.py).
	-- Re-tune together with medal thresholds after 10 developer runs (ECONOMY.md 2.2).
	SegmentMinMs = table.freeze({ 5_000, 5_000, 6_000, 3_500, 2_500 }),

	-- Decision D13 is made in stage 1 by testing in Studio. "Poll" checks the HumanoidRootPart
	-- against zones every PollIntervalSec; "Touched" uses BasePart.Touched on the server.
	CheckpointDetection = "Poll" :: CheckpointDetection,
	PollIntervalSec = 0.1,

	-- Anti-cheat: max horizontal speed of the root part between polls, outside server teleports.
	-- Default WalkSpeed is 16; 60 leaves room for jumps and lag spikes.
	MaxHorizontalSpeed = 60,
	MinStepAllowanceStuds = 6,

	-- Root part below this world height during a run = fell off the track (desk top is at y = 1).
	FallResetY = 7,

	-- Seconds on the finish pad before the player is sent back to the hub.
	ReturnDelaySec = 4,
})

return Dash
