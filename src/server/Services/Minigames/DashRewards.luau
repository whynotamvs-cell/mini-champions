--!strict
-- Builds the grants for a valid Desk Dash finish (docs/ECONOMY.md 2.1). Pure.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Formulas = require(ReplicatedStorage.Shared.Utilities.Formulas)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local RewardLogic = require(script.Parent.Parent.Logic.RewardLogic)

type Medal = PlayerDataTypes.Medal
type Grant = RewardLogic.Grant

export type FirstMedal = { medal: Medal, grant: Grant }

local DashRewards = {}

-- Keyed by string: luau-lsp 1.70 rejects singleton-union keys in indexers.
local MEDAL_RANK: { [string]: number } = { Bronze = 1, Silver = 2, Gold = 3 }
local TIERS: { Medal } = { "Bronze" :: Medal, "Silver" :: Medal, "Gold" :: Medal }

-- The per-run grant: finish + medal bonus (repeats every run).
function DashRewards.runGrant(runId: string, medal: Medal): Grant
	local d = Economy.Dash
	local lines = { { sku = "dash_finish", stars = d.FinishStars } }
	local xp = d.FinishXP
	if medal == "Silver" then
		table.insert(lines, { sku = "dash_medal_silver", stars = d.SilverBonusStars })
		xp += d.SilverBonusXP
	elseif medal == "Gold" then
		table.insert(lines, { sku = "dash_medal_gold", stars = d.GoldBonusStars })
		xp += d.GoldBonusXP
	end
	return { source = "DashRun", grantId = `dash:{runId}`, lines = lines, xp = xp }
end

-- One-time grants for every medal tier reached for the first time. A first Gold also
-- awards first Silver and first Bronze (ECONOMY.md 2.1).
function DashRewards.firstMedalGrants(medal: Medal): { FirstMedal }
	local d = Economy.Dash
	local amounts: { [string]: number } =
		{ Bronze = d.FirstBronzeStars, Silver = d.FirstSilverStars, Gold = d.FirstGoldStars }
	local result: { FirstMedal } = {}
	for _, tier in TIERS do
		if MEDAL_RANK[tier] <= MEDAL_RANK[medal] then
			local lower = string.lower(tier)
			local entry: FirstMedal = {
				medal = tier :: Medal,
				grant = {
					source = "DashFirstMedal",
					grantId = `medal:dash:{lower}`,
					lines = { { sku = `dash_first_{lower}`, stars = amounts[tier] } },
					xp = 0,
				},
			}
			table.insert(result, entry)
		end
	end
	return result
end

-- Guard for a first-medal grant: aborts if the medal flag is already set, otherwise sets it.
function DashRewards.firstMedalGuard(medal: Medal): (data: any) -> boolean
	return function(data: any): boolean
		local medals = data.Minigames.DeskDash.Medals
		if medals[medal] then
			return false
		end
		medals[medal] = true
		return true
	end
end

-- Guard for the run grant: records the finish and the personal best in the same update.
-- `isNewBest` is set through the returned getter.
function DashRewards.recordFinishGuard(timeMs: number): ((data: any) -> boolean, () -> boolean)
	local newBest = false
	return function(data: any): boolean
		local dash = data.Minigames.DeskDash
		dash.Finishes += 1
		if dash.BestTimeMs == 0 or timeMs < dash.BestTimeMs then
			dash.BestTimeMs = timeMs
			newBest = true
		end
		return true
	end, function(): boolean
		return newBest
	end
end

DashRewards.medalForTime = Formulas.medalForTime

return DashRewards
