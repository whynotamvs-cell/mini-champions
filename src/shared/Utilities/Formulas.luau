--!strict
-- Pure formulas derived from Config.Economy. No Roblox services, no side effects.

local Economy = require(script.Parent.Parent.Config.Economy)
local PlayerDataTypes = require(script.Parent.Parent.Types.PlayerData)

type Medal = PlayerDataTypes.Medal

local Formulas = {}

-- XP needed to go from `level` to `level + 1`.
function Formulas.xpToNext(level: number): number
	return Economy.Level.BaseXP + Economy.Level.PerLevelXP * level
end

-- Returns level, XP accumulated inside the current level, XP needed for the next level (0 at max level).
function Formulas.levelInfo(xp: number): (number, number, number)
	local remaining = if xp ~= xp or xp < 0 then 0 else math.floor(xp)
	local level = 1
	while level < Economy.Level.MaxLevel do
		local need = Formulas.xpToNext(level)
		if remaining < need then
			return level, remaining, need
		end
		remaining -= need
		level += 1
	end
	return Economy.Level.MaxLevel, remaining, 0
end

function Formulas.levelFromXP(xp: number): number
	local level = Formulas.levelInfo(xp)
	return level
end

-- Club level = upgrades owned + 1 (range 1..9).
function Formulas.clubLevel(upgradesOwned: number): number
	return upgradesOwned + 1
end

-- Medal for a valid finish time on a track (default: Desk Dash). Limits: Economy.Tracks[trackId].
function Formulas.medalForTime(timeMs: number, trackId: string?): Medal
	local timing = (Economy.Tracks :: any)[trackId or "desk"]
	if timing == nil then
		timing = Economy.DashTiming
	end
	if timeMs <= timing.GoldMaxMs then
		return "Gold" :: Medal
	elseif timeMs <= timing.SilverMaxMs then
		return "Silver" :: Medal
	end
	return "Bronze" :: Medal
end

-- Price of upgrade `index` (1-based), or nil when the index does not exist.
function Formulas.upgradePrice(index: number): number?
	local upgrade = Economy.Upgrades[index]
	return if upgrade then upgrade.Price else nil
end

return Formulas
