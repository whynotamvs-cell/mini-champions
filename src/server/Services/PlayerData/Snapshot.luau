--!strict
-- Builds the client snapshot (docs/ARCHITECTURE.md 6.3): only what the UI shows, nothing else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Formulas = require(ReplicatedStorage.Shared.Utilities.Formulas)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local Snapshot = {}

function Snapshot.build(data: PlayerDataTypes.PlayerData): PlayerDataTypes.ClientSnapshot
	local level, into, nextNeed = Formulas.levelInfo(data.XP)
	local desk = data.Minigames.DeskDash
	local keys = data.Minigames.KeyDash
	return {
		Stars = data.Stars,
		Level = level,
		XPIntoLevel = into,
		XPForNext = nextNeed,
		ClubLevel = Formulas.clubLevel(data.Club.UpgradesOwned),
		UpgradesOwned = data.Club.UpgradesOwned,
		Tutorial = { Step = data.Tutorial.Step, Completed = data.Tutorial.Completed },
		DeskDash = {
			BestTimeMs = desk.BestTimeMs,
			Medals = { Bronze = desk.Medals.Bronze, Silver = desk.Medals.Silver, Gold = desk.Medals.Gold },
		},
		KeyDash = {
			BestTimeMs = keys.BestTimeMs,
			Medals = { Bronze = keys.Medals.Bronze, Silver = keys.Medals.Silver, Gold = keys.Medals.Gold },
		},
		Pets = { Owned = table.clone(data.Pets.Owned), Equipped = data.Pets.Equipped },
		Shop = {
			SkipTokens = data.Shop.SkipTokens,
			SpringBoots = data.Shop.SpringBoots,
			SpringOn = data.Shop.SpringOn,
			Owned = table.clone(data.Shop.Owned),
			Trail = data.Shop.Trail,
			Finish = data.Shop.Finish,
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
