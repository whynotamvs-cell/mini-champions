--!strict
-- Player data types. Schema v1, see docs/DATA_SCHEMA.md 4.

export type Medal = "Bronze" | "Silver" | "Gold"
export type Language = "auto" | "en" | "ru"

export type PlayerDataV1 = {
	SchemaVersion: number,
	Stars: number,
	LifetimeStars: number,
	XP: number,
	Tutorial: {
		Step: number,
		Completed: boolean,
	},
	Club: {
		UpgradesOwned: number,
	},
	Minigames: {
		DeskDash: {
			Finishes: number,
			BestTimeMs: number,
			Medals: {
				Bronze: boolean,
				Silver: boolean,
				Gold: boolean,
			},
		},
	},
	RecentGrants: { string },
	Settings: {
		MusicVolume: number,
		SfxVolume: number,
		Language: Language,
		ReducedMotion: boolean,
	},
	Meta: {
		FirstJoinUnix: number,
		LastJoinUnix: number,
		SessionCount: number,
	},
}

export type PlayerData = PlayerDataV1

-- What the client receives (docs/ARCHITECTURE.md 6.3). Display only; the server never reads it back.
export type ClientSnapshot = {
	Stars: number,
	Level: number,
	XPIntoLevel: number,
	XPForNext: number,
	ClubLevel: number,
	UpgradesOwned: number,
	Tutorial: { Step: number, Completed: boolean },
	DeskDash: {
		BestTimeMs: number,
		Medals: { Bronze: boolean, Silver: boolean, Gold: boolean },
	},
	Settings: {
		MusicVolume: number,
		SfxVolume: number,
		Language: Language,
		ReducedMotion: boolean,
	},
}

return {}
