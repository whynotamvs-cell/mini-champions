--!strict
-- Sound cues of the obstacle tracks. Each track has one "sprite": a single audio file with every cue
-- back to back, synthesized by tools/gen_sounds.py (own work: no samples, no third-party audio). The
-- game plays a cue by starting the sound at the cue's offset and stopping it after its length.
-- Desk Dash is warm marimba/wood, Keyboard Dash is bright triangle beeps and clean key clicks.
--
-- Until a sprite is uploaded and its asset id is set below, that track is silent (no sounds at all
-- rather than harsh stand-ins). Upload assets/audio/<track>.wav as an Audio asset, then paste the id.
-- SLOTS must match tools/gen_sounds.py.

export type Cue = { start: number, length: number, volume: number }
export type Cues = {
	tick: Cue, -- countdown 3-2-1, once per second
	go: Cue,
	jump: Cue,
	land: Cue,
	checkpoint: Cue,
	fall: Cue,
	finishBronze: Cue,
	finishSilver: Cue,
	finishGold: Cue,
	rejected: Cue,
}

export type Sprite = {
	asset: string, -- "rbxassetid://<id>" once uploaded; "" = silent
	cues: Cues,
}

local function cue(start: number, length: number, volume: number): Cue
	return { start = start, length = length, volume = volume }
end

-- Offsets and lengths in seconds (tools/gen_sounds.py SLOTS) and relative loudness. The clean
-- synthesized files are fairly quiet (peaks 0.1-0.6 of full scale), so volumes sit above 1.
local function cues(): Cues
	return {
		tick = cue(0.0, 0.30, 1.4),
		go = cue(0.5, 0.55, 1.6),
		jump = cue(1.2, 0.25, 1.5),
		land = cue(1.7, 0.25, 1.4),
		checkpoint = cue(2.2, 0.60, 1.6),
		fall = cue(3.0, 0.50, 1.4),
		finishBronze = cue(3.8, 1.00, 1.7),
		finishSilver = cue(5.0, 1.30, 1.7),
		finishGold = cue(6.5, 1.90, 1.7),
		rejected = cue(8.6, 0.60, 1.4),
	}
end

local Sounds = table.freeze({
	Tracks = table.freeze({
		desk = table.freeze({ asset = "", cues = table.freeze(cues()) }) :: Sprite,
		keys = table.freeze({ asset = "", cues = table.freeze(cues()) }) :: Sprite,
	}),
	CueNames = table.freeze({
		"tick",
		"go",
		"jump",
		"land",
		"checkpoint",
		"fall",
		"finishBronze",
		"finishSilver",
		"finishGold",
		"rejected",
	}),
	-- Longest sprite in seconds (a cue must end inside it).
	SpriteSeconds = 9.4,
})

return Sounds
