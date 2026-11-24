--!strict
-- The obstacle tracks (docs/ARCHITECTURE.md 8). Everything that differs between tracks lives here;
-- medal limits and timeouts live in Config.Economy (single source of truth for numbers).
--
--   Id         short id used in events and remotes
--   DataKey    the table in Profile.Data.Minigames that keeps this track's record and medals
--   WorldName  the Model under Workspace.DeskWorld that holds Geometry, Zones and Spawns
--   SkuPrefix  prefix of analytics SKUs and reward ids ("dash_finish", "keys_finish", ...)
--   Progression  AnalyticsService progression path
--   NameKey    localization key of the display name
--   RequiresTutorial  locked until Tutorial.Completed

local Economy = require(script.Parent.Economy)

export type Track = {
	Id: string,
	DataKey: string,
	WorldName: string,
	SkuPrefix: string,
	Progression: string,
	NameKey: string,
	RequiresTutorial: boolean,
	CheckpointCount: number,
	-- Minimum time per segment: start->cp1, cp1->cp2, ... cp4->finish (anti-cheat, ~55% of the walking
	-- time at WalkSpeed 16 over the walking distance printed by tools/gen_world.py). Re-tune together with the medal limits after developer runs.
	SegmentMinMs: { number },
	-- A root part below this height during a run = fell off the track (desk top root is ~4).
	FallResetY: number,
	GoldMaxMs: number,
	SilverMaxMs: number,
	MinValidTimeMs: number,
	TimeoutSec: number,
}

local function build(spec: {
	Id: string,
	DataKey: string,
	WorldName: string,
	SkuPrefix: string,
	Progression: string,
	NameKey: string,
	RequiresTutorial: boolean,
	SegmentMinMs: { number },
}): Track
	local timing = (Economy.Tracks :: any)[spec.Id]
	return table.freeze({
		Id = spec.Id,
		DataKey = spec.DataKey,
		WorldName = spec.WorldName,
		SkuPrefix = spec.SkuPrefix,
		Progression = spec.Progression,
		NameKey = spec.NameKey,
		RequiresTutorial = spec.RequiresTutorial,
		CheckpointCount = #spec.SegmentMinMs - 1,
		SegmentMinMs = table.freeze(spec.SegmentMinMs),
		FallResetY = 11,
		GoldMaxMs = timing.GoldMaxMs,
		SilverMaxMs = timing.SilverMaxMs,
		MinValidTimeMs = timing.MinValidTimeMs,
		TimeoutSec = timing.TimeoutSec,
	})
end

local desk = build({
	Id = "desk",
	DataKey = "DeskDash",
	WorldName = "DeskDash",
	SkuPrefix = "dash",
	Progression = "DeskDash",
	NameKey = "Track.DeskName",
	RequiresTutorial = false,
	SegmentMinMs = { 3_000, 3_500, 3_000, 4_500, 2_000 },
})

local keys = build({
	Id = "keys",
	DataKey = "KeyDash",
	WorldName = "KeyDash",
	SkuPrefix = "keys",
	Progression = "KeyDash",
	NameKey = "Track.KeysName",
	RequiresTutorial = true,
	SegmentMinMs = { 3_000, 3_000, 4_500, 2_500, 2_000 },
})

local Tracks = table.freeze({
	Order = table.freeze({ "desk", "keys" }),
	ById = table.freeze({
		desk = desk,
		keys = keys,
	}),
	Default = "desk",
})

return Tracks
