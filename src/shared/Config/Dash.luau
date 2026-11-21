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
	-- Placeholder values; tune after the track is built (sum must stay below MinValidTimeMs).
	SegmentMinMs = table.freeze({ 5_000, 5_000, 5_000, 5_000, 5_000 }),

	-- Decision D13 is made in stage 1 by testing in Studio. "Poll" checks the HumanoidRootPart
	-- against zones every PollIntervalSec; "Touched" uses BasePart.Touched on the server.
	CheckpointDetection = "Poll" :: CheckpointDetection,
	PollIntervalSec = 0.1,

	-- Anti-cheat: horizontal distance the root part may move per poll tick outside server teleports.
	MaxHorizontalStepStuds = 8,

	-- Falling below this height (relative to the track) returns the player to the last checkpoint.
	FallResetHeight = -20,
})

return Dash
