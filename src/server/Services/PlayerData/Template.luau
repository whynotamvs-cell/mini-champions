--!strict
-- Default profile, schema v5 (docs/DATA_SCHEMA.md 4). Changing it requires a migration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local TEMPLATE: PlayerDataTypes.PlayerDataV5 = {
	SchemaVersion = 5,
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
	Shop = { SkipTokens = 0, SpringBoots = false, SpringOn = false, Owned = {}, Trail = "", Finish = "" },
	Pets = { Owned = {}, Equipped = "" },
	RecentGrants = {},
	Settings = { MusicVolume = 0.6, SfxVolume = 0.8, Language = "auto", ReducedMotion = false, ShowPets = true },
	Meta = { FirstJoinUnix = 0, LastJoinUnix = 0, SessionCount = 0 },
}

return TEMPLATE
