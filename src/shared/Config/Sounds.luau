--!strict
-- Sound cues of the obstacle tracks. Every sound is an engine built-in (rbxasset://sounds/...), so
-- nothing is downloaded and there are no licence questions; each one was loaded in Studio and has a
-- real length (VERIFIED below). Tracks sound different by pitch and by sound choice: Desk Dash is
-- wooden and papery (thunks, snaps), Keyboard Dash is clicky and electronic (clicks, pings).
-- Volumes are relative; the player's Sfx volume (Settings) scales them through the "Sfx" SoundGroup.

export type Step = { id: string, speed: number, volume: number, delay: number }
export type Cues = {
	tick: { Step }, -- countdown 3-2-1, once per second
	go: { Step },
	jump: { Step },
	land: { Step },
	checkpoint: { Step },
	fall: { Step },
	finish: { Gold: { Step }, Silver: { Step }, Bronze: { Step } },
	rejected: { Step },
}

local PREFIX = "rbxasset://sounds/"

-- Checked 2026-11-24 in Studio: IsLoaded and TimeLength > 0 (length in seconds in the comment).
local Verified: { [string]: number } = table.freeze({
	[PREFIX .. "action_jump.mp3"] = 0.34,
	[PREFIX .. "action_jump_land.mp3"] = 0.26,
	[PREFIX .. "clickfast.wav"] = 0.29,
	[PREFIX .. "button.wav"] = 0.58,
	[PREFIX .. "electronicpingshort.wav"] = 0.72,
	[PREFIX .. "snap.mp3"] = 0.42,
	[PREFIX .. "switch.wav"] = 0.24,
	[PREFIX .. "SWITCH3.wav"] = 0.37,
	[PREFIX .. "kerplunk.wav"] = 0.37,
	[PREFIX .. "victory.wav"] = 1.31,
	[PREFIX .. "hit.wav"] = 0.84,
	[PREFIX .. "bass.mp3"] = 1.01,
})

local JUMP = PREFIX .. "action_jump.mp3"
local LAND = PREFIX .. "action_jump_land.mp3"
local CLICK = PREFIX .. "clickfast.wav"
local PING = PREFIX .. "electronicpingshort.wav"
local SNAP = PREFIX .. "snap.mp3"
local SWITCH = PREFIX .. "switch.wav"
local SWITCH3 = PREFIX .. "SWITCH3.wav"
local THUNK = PREFIX .. "kerplunk.wav"
local VICTORY = PREFIX .. "victory.wav"
local HIT = PREFIX .. "hit.wav"
local BASS = PREFIX .. "bass.mp3"

local function step(id: string, speed: number, volume: number, delay: number?): Step
	return { id = id, speed = speed, volume = volume, delay = delay or 0 }
end

local desk: Cues = {
	tick = { step(THUNK, 1.0, 0.7) },
	go = { step(SNAP, 1.15, 0.9), step(THUNK, 0.8, 0.6) },
	jump = { step(JUMP, 0.85, 0.5) },
	land = { step(LAND, 1.1, 0.4), step(THUNK, 1.6, 0.35) },
	checkpoint = { step(SWITCH3, 1.0, 0.8), step(SNAP, 1.6, 0.5, 0.12) },
	fall = { step(HIT, 0.7, 0.6) },
	finish = {
		Gold = { step(VICTORY, 1.0, 0.9), step(SNAP, 1.5, 0.6, 0.35) },
		Silver = { step(VICTORY, 0.92, 0.85) },
		Bronze = { step(VICTORY, 0.84, 0.8) },
	},
	rejected = { step(HIT, 0.6, 0.6) },
}

local keys: Cues = {
	tick = { step(SWITCH, 1.6, 0.7) },
	go = { step(PING, 1.4, 0.8), step(CLICK, 1.2, 0.6, 0.1) },
	jump = { step(CLICK, 1.35, 0.55) },
	land = { step(CLICK, 0.9, 0.5) },
	checkpoint = { step(PING, 1.25, 0.8), step(PING, 1.7, 0.5, 0.15) },
	fall = { step(BASS, 1.4, 0.5) },
	finish = {
		Gold = { step(VICTORY, 1.15, 0.9), step(PING, 1.6, 0.6, 0.3), step(PING, 2.0, 0.5, 0.5) },
		Silver = { step(VICTORY, 1.05, 0.85), step(PING, 1.5, 0.5, 0.3) },
		Bronze = { step(VICTORY, 0.95, 0.8) },
	},
	rejected = { step(BASS, 1.0, 0.55) },
}

local Sounds = table.freeze({
	Verified = Verified,
	Tracks = table.freeze({
		desk = desk,
		keys = keys,
	}),
})

return Sounds
