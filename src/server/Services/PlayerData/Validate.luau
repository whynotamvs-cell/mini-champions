--!strict
-- Data validation (docs/DATA_SCHEMA.md 9).
--   Validate.repair(data) - after load: fixes values in place, returns a list of what was fixed.
--   Validate.issues(data) - before committing an update: returns problems, changes nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)

local Template = require(script.Parent.Template)

local LANGUAGES = { auto = true, en = true, ru = true }
local MAX_UPGRADES = #Economy.Upgrades
local MAX_TUTORIAL_STEP = 5
local BIG = 2 ^ 31

local Validate = {}

local function isFinite(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Each checker receives the parent table, key, issue list and repair flag.
type Ctx = { issues: { string }, repair: boolean }

local function ensureTable(ctx: Ctx, parent: any, key: string, template: any, path: string): any
	if type(parent[key]) ~= "table" then
		table.insert(ctx.issues, `{path}: not a table`)
		if ctx.repair then
			parent[key] = TableUtil.deepCopy(template)
		end
	end
	return parent[key]
end

local function integer(ctx: Ctx, t: any, key: string, min: number, max: number, path: string)
	local v = t[key]
	if not isFinite(v) then
		table.insert(ctx.issues, `{path}: not a finite number ({tostring(v)})`)
		if ctx.repair then
			t[key] = min
		end
	elseif v % 1 ~= 0 or v < min or v > max then
		table.insert(ctx.issues, `{path}: {v} not an integer in {min}..{max}`)
		if ctx.repair then
			t[key] = math.clamp(math.floor(v), min, max)
		end
	end
end

local function number(ctx: Ctx, t: any, key: string, min: number, max: number, default: number, path: string)
	local v = t[key]
	if not isFinite(v) then
		table.insert(ctx.issues, `{path}: not a finite number`)
		if ctx.repair then
			t[key] = default
		end
	elseif v < min or v > max then
		table.insert(ctx.issues, `{path}: {v} not in {min}..{max}`)
		if ctx.repair then
			t[key] = math.clamp(v, min, max)
		end
	end
end

local function boolean(ctx: Ctx, t: any, key: string, default: boolean, path: string)
	if type(t[key]) ~= "boolean" then
		table.insert(ctx.issues, `{path}: not a boolean`)
		if ctx.repair then
			t[key] = default
		end
	end
end

local function run(data: any, repair: boolean): { string }
	local ctx: Ctx = { issues = {}, repair = repair }
	if type(data) ~= "table" then
		return { "data: not a table" }
	end

	integer(ctx, data, "Stars", 0, Economy.Limits.MaxBalance, "Stars")
	integer(ctx, data, "LifetimeStars", 0, BIG, "LifetimeStars")
	integer(ctx, data, "XP", 0, BIG, "XP")

	local tutorial = ensureTable(ctx, data, "Tutorial", Template.Tutorial, "Tutorial")
	if type(tutorial) == "table" then
		integer(ctx, tutorial, "Step", 0, MAX_TUTORIAL_STEP, "Tutorial.Step")
		boolean(ctx, tutorial, "Completed", false, "Tutorial.Completed")
	end

	local club = ensureTable(ctx, data, "Club", Template.Club, "Club")
	if type(club) == "table" then
		integer(ctx, club, "UpgradesOwned", 0, MAX_UPGRADES, "Club.UpgradesOwned")
	end

	local pets = ensureTable(ctx, data, "Pets", Template.Pets, "Pets")
	if type(pets) == "table" then
		local owned = ensureTable(ctx, pets, "Owned", Template.Pets.Owned, "Pets.Owned")
		if type(owned) == "table" then
			for key, value in owned do
				if type(key) ~= "string" or Pets.ById[key] == nil or value ~= true then
					table.insert(ctx.issues, `Pets.Owned[{tostring(key)}]: not an owned pet`)
					if repair then
						owned[key] = nil
					end
				end
			end
			local equipped = pets.Equipped
			if equipped ~= "" and (type(equipped) ~= "string" or owned[equipped] ~= true) then
				table.insert(ctx.issues, "Pets.Equipped: not an owned pet")
				if repair then
					pets.Equipped = ""
				end
			end
		end
	end

	local shop = ensureTable(ctx, data, "Shop", Template.Shop, "Shop")
	if type(shop) == "table" then
		integer(ctx, shop, "SkipTokens", 0, Shop.MaxSkipTokens, "Shop.SkipTokens")
		boolean(ctx, shop, "SpringBoots", false, "Shop.SpringBoots")
		boolean(ctx, shop, "SpringOn", false, "Shop.SpringOn")
		if shop.SpringOn == true and shop.SpringBoots ~= true then
			table.insert(ctx.issues, "Shop.SpringOn: boots not owned")
			if repair then
				shop.SpringOn = false
			end
		end
		local owned = ensureTable(ctx, shop, "Owned", Template.Shop.Owned, "Shop.Owned")
		if type(owned) == "table" then
			for key, value in owned do
				local item = if type(key) == "string" then Shop.ById[key] else nil
				if item == nil or (item.Kind ~= "Trail" and item.Kind ~= "Finish") or value ~= true then
					table.insert(ctx.issues, `Shop.Owned[{tostring(key)}]: not a cosmetic owned flag`)
					if repair then
						owned[key] = nil
					end
				end
			end
			for slot, kind in { Trail = "Trail", Finish = "Finish" } do
				local id = shop[slot]
				if id ~= "" then
					local item = if type(id) == "string" then Shop.ById[id] else nil
					if item == nil or item.Kind ~= kind or owned[id] ~= true then
						table.insert(ctx.issues, `Shop.{slot}: not an owned {kind}`)
						if repair then
							shop[slot] = ""
						end
					end
				end
			end
		end
	end

	local minigames = ensureTable(ctx, data, "Minigames", Template.Minigames, "Minigames")
	if type(minigames) == "table" then
		for _, trackId in Tracks.Order do
			local track = Tracks.ById[trackId]
			local key = track.DataKey
			local template = (Template.Minigames :: any)[key]
			local dash = ensureTable(ctx, minigames, key, template, `Minigames.{key}`)
			if type(dash) == "table" then
				integer(ctx, dash, "Finishes", 0, BIG, `{key}.Finishes`)
				integer(ctx, dash, "BestTimeMs", 0, BIG, `{key}.BestTimeMs`)
				local best = dash.BestTimeMs
				if isFinite(best) and best > 0 and best < track.MinValidTimeMs then
					table.insert(ctx.issues, `{key}.BestTimeMs: {best} below MinValidTimeMs`)
					if repair then
						dash.BestTimeMs = 0
					end
				end
				local medals = ensureTable(ctx, dash, "Medals", template.Medals, `{key}.Medals`)
				if type(medals) == "table" then
					for _, medal in { "Bronze", "Silver", "Gold" } do
						boolean(ctx, medals, medal, false, `{key}.Medals.{medal}`)
					end
				end
			end
		end
	end

	local grants = ensureTable(ctx, data, "RecentGrants", Template.RecentGrants, "RecentGrants")
	if type(grants) == "table" then
		local valid: { string } = {}
		local bad = false
		for i, id in grants do
			if type(i) ~= "number" or type(id) ~= "string" or #id > Economy.Limits.GrantIdMaxLength then
				bad = true
			else
				table.insert(valid, id)
			end
		end
		if bad then
			table.insert(ctx.issues, "RecentGrants: invalid entries")
		end
		if #valid > Economy.Limits.RecentGrantsMax then
			table.insert(ctx.issues, `RecentGrants: {#valid} entries > {Economy.Limits.RecentGrantsMax}`)
			while #valid > Economy.Limits.RecentGrantsMax do
				table.remove(valid, 1)
			end
			bad = true
		end
		if bad and repair then
			data.RecentGrants = valid
		end
	end

	local settings = ensureTable(ctx, data, "Settings", Template.Settings, "Settings")
	if type(settings) == "table" then
		number(ctx, settings, "MusicVolume", 0, 1, Template.Settings.MusicVolume, "Settings.MusicVolume")
		number(ctx, settings, "SfxVolume", 0, 1, Template.Settings.SfxVolume, "Settings.SfxVolume")
		if type(settings.Language) ~= "string" or not LANGUAGES[settings.Language] then
			table.insert(ctx.issues, "Settings.Language: unsupported")
			if repair then
				settings.Language = "auto"
			end
		end
		boolean(ctx, settings, "ReducedMotion", false, "Settings.ReducedMotion")
		boolean(ctx, settings, "ShowPets", true, "Settings.ShowPets")
	end

	local meta = ensureTable(ctx, data, "Meta", Template.Meta, "Meta")
	if type(meta) == "table" then
		integer(ctx, meta, "FirstJoinUnix", 0, BIG * 4, "Meta.FirstJoinUnix")
		integer(ctx, meta, "LastJoinUnix", 0, BIG * 4, "Meta.LastJoinUnix")
		integer(ctx, meta, "SessionCount", 0, BIG, "Meta.SessionCount")
	end

	return ctx.issues
end

function Validate.repair(data: any): { string }
	return run(data, true)
end

function Validate.issues(data: any): { string }
	return run(data, false)
end

return Validate
