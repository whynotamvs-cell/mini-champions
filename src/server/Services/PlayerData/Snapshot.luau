--!strict
-- Builds the client snapshot (docs/ARCHITECTURE.md 6.3): only what the UI shows, nothing else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Formulas = require(ReplicatedStorage.Shared.Utilities.Formulas)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local Snapshot = {}

function Snapshot.build(data: PlayerDataTypes.PlayerData): PlayerDataTypes.ClientSnapshot
	local level, into, nextNeed = Formulas.levelInfo(data.XP)
	local dash = data.Minigames.DeskDash
	return {
		Stars = data.Stars,
		Level = level,
		XPIntoLevel = into,
		XPForNext = nextNeed,
		ClubLevel = Formulas.clubLevel(data.Club.UpgradesOwned),
		UpgradesOwned = data.Club.UpgradesOwned,
		Tutorial = { Step = data.Tutorial.Step, Completed = data.Tutorial.Completed },
		DeskDash = {
			BestTimeMs = dash.BestTimeMs,
			Medals = { Bronze = dash.Medals.Bronze, Silver = dash.Medals.Silver, Gold = dash.Medals.Gold },
		},
		Settings = {
			MusicVolume = data.Settings.MusicVolume,
			SfxVolume = data.Settings.SfxVolume,
			Language = data.Settings.Language,
			ReducedMotion = data.Settings.ReducedMotion,
		},
	}
end

return Snapshot
