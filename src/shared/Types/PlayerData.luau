--!strict
-- Player data types. Schema v5, see docs/DATA_SCHEMA.md 4.

export type Medal = "Bronze" | "Silver" | "Gold"
export type Language = "auto" | "en" | "ru"

-- Best time and medals of one track (Profile.Data.Minigames.<Track.DataKey>).
export type TrackRecord = {
	Finishes: number,
	BestTimeMs: number,
	Medals: {
		Bronze: boolean,
		Silver: boolean,
		Gold: boolean,
	},
}

-- Paid items the player holds (Profile.Data.Shop, docs/DATA_SCHEMA.md 4).
export type ShopData = {
	SkipTokens: number,
	SpringBoots: boolean, -- owns the Game Pass (re-checked on join)
	SpringOn: boolean, -- wants the boots on right now
	Owned: { [string]: boolean }, -- cosmetic item id -> owned
	Trail: string, -- equipped trail item id, "" for none
	Finish: string, -- equipped finish effect item id, "" for none
}

-- Owned pets (Profile.Data.Pets, docs/DATA_SCHEMA.md 4).
export type PetsData = {
	Owned: { [string]: boolean },
	Equipped: string, -- "" for none
}

export type PlayerDataV5 = {
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
		DeskDash: TrackRecord,
		KeyDash: TrackRecord,
	},
	Shop: ShopData,
	Pets: PetsData,
	RecentGrants: { string },
	Settings: {
		MusicVolume: number,
		SfxVolume: number,
		Language: Language,
		ReducedMotion: boolean,
		ShowPets: boolean, -- show the pets of other players
	},
	Meta: {
		FirstJoinUnix: number,
		LastJoinUnix: number,
		SessionCount: number,
	},
}

export type PlayerData = PlayerDataV5

-- What the client receives (docs/ARCHITECTURE.md 6.3). Display only; the server never reads it back.
export type ClientSnapshot = {
	Stars: number,
	Level: number,
	XPIntoLevel: number,
	XPForNext: number,
	ClubLevel: number,
	UpgradesOwned: number,
	Tutorial: { Step: number, Completed: boolean },
	DeskDash: { BestTimeMs: number, Medals: { Bronze: boolean, Silver: boolean, Gold: boolean } },
	KeyDash: { BestTimeMs: number, Medals: { Bronze: boolean, Silver: boolean, Gold: boolean } },
	Pets: { Owned: { [string]: boolean }, Equipped: string },
	Shop: {
		SkipTokens: number,
		SpringBoots: boolean,
		SpringOn: boolean,
		Owned: { [string]: boolean },
		Trail: string,
		Finish: string,
	},
	Settings: {
		MusicVolume: number,
		SfxVolume: number,
		Language: Language,
		ReducedMotion: boolean,
		ShowPets: boolean,
	},
}

return {}
