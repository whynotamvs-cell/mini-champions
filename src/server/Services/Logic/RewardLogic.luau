--!strict
-- Idempotent reward application (docs/DATA_SCHEMA.md 6, docs/ECONOMY.md 6). Pure; runs inside
-- PlayerDataService:Update(), so check-and-write happens without a yield in between.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Formulas = require(ReplicatedStorage.Shared.Utilities.Formulas)

local CurrencyLogic = require(script.Parent.CurrencyLogic)

export type RewardSource = "DashRun" | "DashFirstMedal" | "Tutorial"

export type Line = { sku: string, stars: number }

export type Grant = {
	source: RewardSource,
	grantId: string,
	lines: { Line },
	xp: number,
}

export type Result = {
	starsAdded: number,
	xpAdded: number,
	levelBefore: number,
	levelAfter: number,
	levelUpStars: number,
	balance: number,
}

-- Analytics transaction type per source (docs/ECONOMY.md 8).
local TRANSACTION_TYPE: { [RewardSource]: string } = {
	DashRun = "Gameplay",
	DashFirstMedal = "Gameplay",
	Tutorial = "Onboarding",
}

local RewardLogic = {}

RewardLogic.TRANSACTION_TYPE = TRANSACTION_TYPE

local function isCount(n: any, max: number): boolean
	return type(n) == "number" and n == n and n >= 0 and n <= max and n % 1 == 0
end

function RewardLogic.validate(grant: any): (boolean, string?)
	if type(grant) ~= "table" then
		return false, "grant is not a table"
	end
	if TRANSACTION_TYPE[grant.source] == nil then
		return false, "unknown source"
	end
	if type(grant.grantId) ~= "string" or #grant.grantId == 0 or #grant.grantId > Economy.Limits.GrantIdMaxLength then
		return false, "invalid grantId"
	end
	if type(grant.lines) ~= "table" then
		return false, "invalid lines"
	end
	local total = 0
	for _, line in grant.lines do
		if
			type(line) ~= "table"
			or type(line.sku) ~= "string"
			or not isCount(line.stars, Economy.Limits.MaxSingleGrant)
		then
			return false, "invalid line"
		end
		total += line.stars
	end
	if total > Economy.Limits.MaxSingleGrant then
		return false, "grant exceeds MaxSingleGrant"
	end
	if not isCount(grant.xp, Economy.Limits.MaxSingleGrant) then
		return false, "invalid xp"
	end
	return true
end

function RewardLogic.total(grant: Grant): number
	local total = 0
	for _, line in grant.lines do
		total += line.stars
	end
	return total
end

-- Adds XP and pays LevelUpStars for every level gained (ECONOMY.md 2.4). Used by every XP source.
-- Returns level before, level after, Stars paid for levels.
function RewardLogic.addXP(data: any, xp: number): (number, number, number)
	local levelBefore = Formulas.levelFromXP(data.XP)
	data.XP += xp
	local levelAfter = Formulas.levelFromXP(data.XP)
	local levelUpStars = 0
	if levelAfter > levelBefore then
		levelUpStars = CurrencyLogic.credit(data, (levelAfter - levelBefore) * Economy.LevelUpStars)
	end
	return levelBefore, levelAfter, levelUpStars
end

-- `guard` runs first and may check/set a permanent one-time flag (e.g. Medals.Gold);
-- returning false aborts the grant with reason "already_granted".
-- Returns (true, Result) or (false, reason). On false, `data` must be discarded by the caller.
function RewardLogic.apply(data: any, grant: Grant, guard: ((data: any) -> boolean)?): (boolean, Result | string)
	local ok, reason = RewardLogic.validate(grant)
	if not ok then
		return false, reason or "invalid grant"
	end
	if table.find(data.RecentGrants, grant.grantId) then
		return false, "duplicate"
	end
	if guard and guard(data) == false then
		return false, "already_granted"
	end

	local starsAdded = CurrencyLogic.credit(data, RewardLogic.total(grant))
	local levelBefore, levelAfter, levelUpStars = RewardLogic.addXP(data, grant.xp)

	table.insert(data.RecentGrants, grant.grantId)
	while #data.RecentGrants > Economy.Limits.RecentGrantsMax do
		table.remove(data.RecentGrants, 1)
	end

	return true,
		{
			starsAdded = starsAdded,
			xpAdded = grant.xp,
			levelBefore = levelBefore,
			levelAfter = levelAfter,
			levelUpStars = levelUpStars,
			balance = data.Stars,
		}
end

return RewardLogic
