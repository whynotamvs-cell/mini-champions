--!strict
-- Forward-only schema migrations (docs/DATA_SCHEMA.md 8).
-- MIGRATIONS[n] turns version n data into version n + 1. Pure functions, no yields.

export type Migration = (data: any) -> any
export type Status = "ok" | "newer" | "error"

local CURRENT_VERSION = 2

local MIGRATIONS: { [number]: Migration } = {
	-- v1 -> v2 (second track): a record for Keyboard Dash. Existing data is never touched.
	[1] = function(data: any): any
		local minigames = data.Minigames
		if type(minigames) ~= "table" then
			error("Minigames is not a table")
		end
		if minigames.KeyDash == nil then
			minigames.KeyDash = {
				Finishes = 0,
				BestTimeMs = 0,
				Medals = { Bronze = false, Silver = false, Gold = false },
			}
		end
		return data
	end,
}

local Migrations = {}

Migrations.CURRENT_VERSION = CURRENT_VERSION

-- Runs the chain on `data` (mutated in place). Returns:
--   "ok"    - data is now at `current`
--   "newer" - data is from a newer code version; data was NOT touched and must not be saved
--   "error" - a migration is missing or failed; data must not be used
function Migrations.run(data: any, current: number, migrations: { [number]: Migration }): (Status, any, string?)
	if type(data) ~= "table" then
		return "error", data, "data is not a table"
	end
	local version = data.SchemaVersion
	if version == nil then
		version = 1 -- profiles created from the v1 template always have it; treat absence as v1
	end
	if type(version) ~= "number" or version % 1 ~= 0 or version < 1 then
		return "error", data, `invalid SchemaVersion {tostring(version)}`
	end
	if version > current then
		return "newer", data, `data version {version} > code version {current}`
	end
	while version < current do
		local migrate = migrations[version]
		if migrate == nil then
			return "error", data, `missing migration {version} -> {version + 1}`
		end
		local ok, result = pcall(migrate, data)
		if not ok or type(result) ~= "table" then
			return "error", data, `migration {version} -> {version + 1} failed: {tostring(result)}`
		end
		data = result
		version += 1
		data.SchemaVersion = version
	end
	data.SchemaVersion = current
	return "ok", data, nil
end

function Migrations.migrate(data: any): (Status, any, string?)
	return Migrations.run(data, CURRENT_VERSION, MIGRATIONS)
end

return Migrations
