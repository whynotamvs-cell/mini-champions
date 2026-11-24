--!strict
-- Default profile, schema v2 (docs/DATA_SCHEMA.md 4). Changing it requires a migration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local TEMPLATE: PlayerDataTypes.PlayerDataV2 = {
	SchemaVersion = 2,
	Stars = 0,
	LifetimeStars = 0,
	XP = 0,
	Tutorial = { Step = 0, Completed = false },
	Club = { UpgradesOwned = 0 },
	Minigames = {
		DeskDash = {
			Finishes = 0,
			BestTimeMs = 0,
			Medals = { Bronze = false, Silver = false, Gold = false },
		},
		KeyDash = {
			Finishes = 0,
			BestTimeMs = 0,
			Medals = { Bronze = false, Silver = false, Gold = false },
		},
	},
	RecentGrants = {},
	Settings = { MusicVolume = 0.6, SfxVolume = 0.8, Language = "auto", ReducedMotion = false },
	Meta = { FirstJoinUnix = 0, LastJoinUnix = 0, SessionCount = 0 },
}

return TEMPLATE
