--!strict
-- Results board of one server (docs/ARCHITECTURE.md 8): each player's best valid finish time
-- since this server started, fastest first, top MAX_ROWS. Session state only, never saved
-- (the personal record lives in the profile). Pure.

export type Entry = {
	userId: number,
	name: string,
	timeMs: number,
	medal: string,
}

local MAX_ROWS = 5
local MAX_NAME_LENGTH = 24

local BoardLogic = {}

BoardLogic.MaxRows = MAX_ROWS

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Adds a finish. A player appears once, with their best time. Returns true when the board
-- changed (the entry is now on it with a new or better time).
function BoardLogic.record(entries: { Entry }, userId: number, name: string, timeMs: number, medal: string): boolean
	if not isFinite(timeMs) or timeMs <= 0 or not isFinite(userId) then
		return false
	end
	-- At most MAX_NAME_LENGTH characters (not bytes), so a cut never splits a multi-byte character.
	local cleanName = "?"
	local length = utf8.len(name)
	if length ~= nil then
		cleanName = name
		if length > MAX_NAME_LENGTH then
			cleanName = string.sub(name, 1, (utf8.offset(name, MAX_NAME_LENGTH + 1) :: number) - 1)
		end
	end

	for i, existing in entries do
		if existing.userId == userId then
			if existing.timeMs <= timeMs then
				return false
			end
			table.remove(entries, i)
			break
		end
	end

	-- Insert after every entry that is faster or equal, so ties keep the earlier finisher first.
	local position = #entries + 1
	for i, existing in entries do
		if timeMs < existing.timeMs then
			position = i
			break
		end
	end
	if position > MAX_ROWS then
		return false
	end
	table.insert(entries, position, { userId = userId, name = cleanName, timeMs = timeMs, medal = medal })
	while #entries > MAX_ROWS do
		table.remove(entries)
	end
	return true
end

-- Plain copy for sending to clients.
function BoardLogic.snapshot(entries: { Entry }): { Entry }
	local out: { Entry } = {}
	for _, entry in entries do
		table.insert(out, { userId = entry.userId, name = entry.name, timeMs = entry.timeMs, medal = entry.medal })
	end
	return out
end

return BoardLogic
