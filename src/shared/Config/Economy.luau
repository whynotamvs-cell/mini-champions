--!strict
-- Economy numbers. This file and docs/ECONOMY.md MUST change together, in the same commit.

-- Medal limits and anti-cheat minimums per track, in ms (ECONOMY.md 2.2). Gold <= GoldMaxMs,
-- Silver <= SilverMaxMs, anything faster than MinValidTimeMs is rejected.
local DeskTiming = table.freeze({
	GoldMaxMs = 43_000,
	SilverMaxMs = 54_000,
	MinValidTimeMs = 26_000,
	TimeoutSec = 180,
})
local KeysTiming = table.freeze({
	GoldMaxMs = 41_000,
	SilverMaxMs = 52_000,
	MinValidTimeMs = 25_000,
	TimeoutSec = 180,
})

local Economy = table.freeze({
	CurrencyName = "Stars",

	-- ECONOMY.md 2.1
	Dash = table.freeze({
		FinishStars = 20,
		FinishXP = 20,
		SilverBonusStars = 10,
		SilverBonusXP = 5,
		GoldBonusStars = 20,
		GoldBonusXP = 10,
		FirstBronzeStars = 30,
		FirstSilverStars = 50,
		FirstGoldStars = 100,
	}),

	-- ECONOMY.md 2.2 (starting values, tune after the track is built). One entry per track
	-- (Config.Tracks); DashTiming is the Desk Dash entry, kept under its old name.
	Tracks = table.freeze({
		desk = DeskTiming,
		keys = KeysTiming,
	}),
	DashTiming = DeskTiming,

	-- ECONOMY.md 2.3
	Tutorial = table.freeze({
		FirstFinishStars = 50,
		FirstFinishXP = 30,
		CompleteStars = 40,
		CompleteXP = 20,
	}),

	-- ECONOMY.md 2.4, 2.5
	LevelUpStars = 25,
	UpgradePurchaseXP = 15,

	-- ECONOMY.md 3: bought strictly in this order (decision D11)
	Upgrades = table.freeze({
		table.freeze({ Id = "sticky_banner", Price = 100 }),
		table.freeze({ Id = "pencil_fence", Price = 150 }),
		table.freeze({ Id = "eraser_benches", Price = 250 }),
		table.freeze({ Id = "book_stand", Price = 350 }),
		table.freeze({ Id = "ruler_scoreboard", Price = 500 }),
		table.freeze({ Id = "paperclip_trophies", Price = 650 }),
		table.freeze({ Id = "lamp_floodlight", Price = 850 }),
		table.freeze({ Id = "pencil_cup_tower", Price = 1_100 }),
	}),

	-- ECONOMY.md 4: XP to next level = BaseXP + PerLevelXP * currentLevel
	Level = table.freeze({
		BaseXP = 50,
		PerLevelXP = 25,
		MaxLevel = 20,
	}),

	-- ECONOMY.md 6
	Limits = table.freeze({
		MaxBalance = 1_000_000,
		MaxSingleGrant = 500,
		RecentGrantsMax = 50,
		GrantIdMaxLength = 64,
	}),
})

return Economy
