--!nonstrict
-- Checks src/localization/UI.csv against the code (TEST_PLAN.md 2, "Localization"):
--   * every row has non-empty en and ru,
--   * {params} are the same in en and ru,
--   * every key literal used in src/ exists, plus generated keys (upgrade names, medals).
-- Returns a list of problems (empty = OK).

local fs = require("@lune/fs")

local LocalizationCheck = {}

-- Minimal RFC 4180 CSV parser (quoted fields, doubled quotes, commas inside quotes).
local function parseCsv(text)
	local rows, row, field, i, inQuotes = {}, {}, {}, 1, false
	while i <= #text do
		local c = string.sub(text, i, i)
		if inQuotes then
			if c == '"' then
				if string.sub(text, i + 1, i + 1) == '"' then
					table.insert(field, '"')
					i += 1
				else
					inQuotes = false
				end
			else
				table.insert(field, c)
			end
		elseif c == '"' then
			inQuotes = true
		elseif c == "," then
			table.insert(row, table.concat(field))
			field = {}
		elseif c == "\n" then
			table.insert(row, table.concat(field))
			table.insert(rows, row)
			row, field = {}, {}
		elseif c ~= "\r" then
			table.insert(field, c)
		end
		i += 1
	end
	if #field > 0 or #row > 0 then
		table.insert(row, table.concat(field))
		table.insert(rows, row)
	end
	return rows
end

local function params(s)
	local found = {}
	for name in string.gmatch(s, "{(%w+)}") do
		table.insert(found, name)
	end
	table.sort(found)
	return table.concat(found, ",")
end

local function luauFiles(dir, out)
	for _, entry in fs.readDir(dir) do
		local full = `{dir}/{entry}`
		if fs.isDir(full) then
			-- Vendor: third-party code. PlayerData: uses data paths like "Settings.MusicVolume"
			-- in log messages, which look like keys but are not UI text.
			if entry ~= "Vendor" and entry ~= "PlayerData" then
				luauFiles(full, out)
			end
		elseif string.sub(entry, -5) == ".luau" then
			table.insert(out, full)
		end
	end
	return out
end

-- Key prefixes used by our localization keys; other dotted strings are not keys.
local PREFIXES = { "Error", "UI", "HUD", "Dash", "Club", "Tutorial", "Emote", "Settings" }

local function isKeyLiteral(s)
	local prefix = string.match(s, "^(%u%a+)%.")
	return prefix ~= nil and table.find(PREFIXES, prefix) ~= nil and string.find(s, "^[%w%._]+$") ~= nil
end

function LocalizationCheck.run()
	local problems = {}
	local rows = parseCsv(fs.readFile("src/localization/UI.csv"))
	local header = rows[1]
	local col = {}
	for i, name in header do
		col[name] = i
	end
	for _, needed in { "Key", "Source", "en", "ru" } do
		if col[needed] == nil then
			table.insert(problems, `UI.csv: missing column {needed}`)
		end
	end
	if #problems > 0 then
		return problems
	end

	local keys = {}
	for r = 2, #rows do
		local row = rows[r]
		local key = row[col.Key]
		if key ~= nil and key ~= "" and #row ~= #header then
			-- A stray comma outside quotes shifts every later column (Rojo then refuses the file).
			table.insert(problems, `{key}: {#row} columns, expected {#header} (quote text with commas)`)
		end
		if key ~= nil and key ~= "" then
			if keys[key] then
				table.insert(problems, `UI.csv: duplicate key {key}`)
			end
			keys[key] = true
			local en, ru = row[col.en] or "", row[col.ru] or ""
			if en == "" then
				table.insert(problems, `{key}: empty en`)
			end
			if ru == "" then
				table.insert(problems, `{key}: empty ru`)
			end
			if params(en) ~= params(ru) then
				table.insert(problems, `{key}: params differ en[{params(en)}] ru[{params(ru)}]`)
			end
		end
	end

	-- Literal keys in code.
	for _, file in luauFiles("src", {}) do
		local source = fs.readFile(file)
		for literal in string.gmatch(source, '"([%w%._]+)"') do
			if isKeyLiteral(literal) and not keys[literal] then
				table.insert(problems, `{file}: key "{literal}" not in UI.csv`)
			end
		end
	end

	-- Generated keys.
	local economy = fs.readFile("src/shared/Config/Economy.luau")
	for id in string.gmatch(economy, 'Id = "([%w_]+)"') do
		local key = `Club.Upgrade.{id}.Name`
		if not keys[key] then
			table.insert(problems, `generated key {key} not in UI.csv`)
		end
	end
	local shopSource = fs.readFile("src/shared/Config/Shop.luau")
	for id in string.gmatch(shopSource, 'item%("([%w_]+)"') do
		if not keys[`Shop.Item.{id}.Name`] then
			table.insert(problems, `generated key Shop.Item.{id}.Name not in UI.csv`)
		end
	end
	local petsSource = fs.readFile("src/shared/Config/Pets.luau")
	for id in string.gmatch(petsSource, 'pet%("([%w_]+)"') do
		if not keys[`Pets.Item.{id}.Name`] then
			table.insert(problems, `generated key Pets.Item.{id}.Name not in UI.csv`)
		end
	end
	for n = 1, 5 do
		if not keys[`Loading.Tip.{n}`] then
			table.insert(problems, `generated key Loading.Tip.{n} not in UI.csv`)
		end
	end
	for _, medal in { "Gold", "Silver", "Bronze" } do
		if not keys[`Dash.Medal.{medal}`] then
			table.insert(problems, `generated key Dash.Medal.{medal} not in UI.csv`)
		end
	end

	return problems
end

return LocalizationCheck
