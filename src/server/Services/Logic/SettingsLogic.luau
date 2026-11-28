--!strict
-- Pure settings update logic (docs/ARCHITECTURE.md 6.1 UpdateSettings, TEST_PLAN X-06).
-- The client sends a table of changes; only the five known keys with valid values get through,
-- volumes are clamped to 0..1, everything else is dropped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

export type Changes = {
	MusicVolume: number?,
	SfxVolume: number?,
	Language: PlayerDataTypes.Language?,
	ReducedMotion: boolean?,
	ShowPets: boolean?,
}

local LANGUAGES: { [string]: boolean } = { auto = true, en = true, ru = true }

local SettingsLogic = {}

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function volume(value: any): number?
	if not isFinite(value) then
		return nil
	end
	local clamped = math.clamp(value, 0, 1)
	return math.floor(clamped * 100 + 0.5) / 100
end

-- Returns only the valid changes found in `input` (never errors, never mutates `input`).
function SettingsLogic.sanitize(input: any): Changes
	local out: Changes = {}
	if type(input) ~= "table" then
		return out
	end
	local music = volume(rawget(input, "MusicVolume"))
	if music ~= nil then
		out.MusicVolume = music
	end
	local sfx = volume(rawget(input, "SfxVolume"))
	if sfx ~= nil then
		out.SfxVolume = sfx
	end
	local language = rawget(input, "Language")
	if type(language) == "string" and LANGUAGES[language] then
		out.Language = language :: any
	end
	local reduced = rawget(input, "ReducedMotion")
	if type(reduced) == "boolean" then
		out.ReducedMotion = reduced
	end
	local showPets = rawget(input, "ShowPets")
	if type(showPets) == "boolean" then
		out.ShowPets = showPets
	end
	return out
end

function SettingsLogic.isEmpty(changes: Changes): boolean
	return next(changes :: any) == nil
end

-- Writes the changes into data.Settings.
function SettingsLogic.apply(data: PlayerDataTypes.PlayerData, changes: Changes)
	local settings = data.Settings
	if changes.MusicVolume ~= nil then
		settings.MusicVolume = changes.MusicVolume
	end
	if changes.SfxVolume ~= nil then
		settings.SfxVolume = changes.SfxVolume
	end
	if changes.Language ~= nil then
		settings.Language = changes.Language
	end
	if changes.ReducedMotion ~= nil then
		settings.ReducedMotion = changes.ReducedMotion
	end
	if changes.ShowPets ~= nil then
		settings.ShowPets = changes.ShowPets
	end
end

return SettingsLogic
