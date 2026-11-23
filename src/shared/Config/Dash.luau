--!strict
-- Obstacle track runtime settings shared by every track. Per-track values (checkpoint count,
-- segment minimums, fall height, medal limits) live in Config.Tracks; economy numbers in
-- Config.Economy.

export type CheckpointDetection = "Touched" | "Poll"

local Dash = table.freeze({
	CountdownSec = 3,

	-- Decision D13 is made in stage 1 by testing in Studio. "Poll" checks the HumanoidRootPart
	-- against zones every PollIntervalSec; "Touched" uses BasePart.Touched on the server.
	CheckpointDetection = "Poll" :: CheckpointDetection,
	PollIntervalSec = 0.1,

	-- Anti-cheat: max horizontal speed of the root part between polls, outside server teleports.
	-- Default WalkSpeed is 16; 60 leaves room for jumps and lag spikes.
	MaxHorizontalSpeed = 60,
	MinStepAllowanceStuds = 6,

	-- Seconds on the finish pad before the player is sent back to the start area.
	ReturnDelaySec = 4,
})

return Dash
