--!strict
-- The six preset emotes (docs/ARCHITECTURE.md 7). Players only ever send an emote ID; the text
-- shown above the head comes from the localization key, so every viewer reads their own language.
-- No free text and no icons from outside: each emote is a coloured bubble with its name.

export type Emote = {
	Id: string,
	Key: string, -- localization key of the display name
	Color: { number }, -- RGB 0..255 (plain numbers so the config loads outside Roblox too)
}

local ITEMS: { Emote } = {
	{ Id = "wave", Key = "Emote.Wave", Color = { 255, 196, 64 } },
	{ Id = "cheer", Key = "Emote.Cheer", Color = { 255, 120, 96 } },
	{ Id = "clap", Key = "Emote.Clap", Color = { 120, 190, 255 } },
	{ Id = "thumbs_up", Key = "Emote.ThumbsUp", Color = { 110, 210, 140 } },
	{ Id = "gg", Key = "Emote.GoodGame", Color = { 190, 150, 255 } },
	{ Id = "race", Key = "Emote.LetsRace", Color = { 255, 160, 200 } },
}

local ids: { string } = {}
local byId: { [string]: Emote } = {}
for _, item in ITEMS do
	table.insert(ids, item.Id)
	byId[item.Id] = item
end

local Emotes = table.freeze({
	Items = table.freeze(ITEMS),
	Ids = table.freeze(ids),
	ById = table.freeze(byId),
	-- Server rate limit is 1 emote per CooldownSec per player (TEST_PLAN X-05).
	CooldownSec = 2,
	-- How long the bubble stays above the head.
	ShowSec = 3,
})

return Emotes
