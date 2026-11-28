--!strict
-- Builds the grants for a valid track finish (docs/ECONOMY.md 2.1). Pure. Rewards are the same on
-- every track; SKUs, grant ids and the record being updated follow the track (Config.Tracks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local Formulas = require(ReplicatedStorage.Shared.Utilities.Formulas)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local RewardLogic = require(script.Parent.Parent.Logic.RewardLogic)

type Medal = PlayerDataTypes.Medal
type Grant = RewardLogic.Grant

export type FirstMedal = { medal: Medal, grant: Grant }

local DashRewards = {}

local function trackOrDefault(track: Tracks.Track?): Tracks.Track
	return track or Tracks.ById[Tracks.Default]
end

-- Keyed by string: luau-lsp 1.70 rejects singleton-union keys in indexers.
local MEDAL_RANK: { [string]: number } = { Bronze = 1, Silver = 2, Gold = 3 }
local TIERS: { Medal } = { "Bronze" :: Medal, "Silver" :: Medal, "Gold" :: Medal }

-- The per-run grant: finish + medal bonus (repeats every run).
-- An equipped pet adds a bonus line (a percentage of the Stars above), so the bonus is part of the
-- same idempotent grant.
function DashRewards.runGrant(runId: string, medal: Medal, track: Tracks.Track?, petId: string?): Grant
	local d = Economy.Dash
	local prefix = trackOrDefault(track).SkuPrefix
	local lines = { { sku = `{prefix}_finish`, stars = d.FinishStars } }
	local xp = d.FinishXP
	if medal == "Silver" then
		table.insert(lines, { sku = `{prefix}_medal_silver`, stars = d.SilverBonusStars })
		xp += d.SilverBonusXP
	elseif medal == "Gold" then
		table.insert(lines, { sku = `{prefix}_medal_gold`, stars = d.GoldBonusStars })
		xp += d.GoldBonusXP
	end
	local base = 0
	for _, line in lines do
		base += line.stars
	end
	local bonus = Pets.bonusStars(petId, base)
	if bonus > 0 then
		table.insert(lines, { sku = "pet_bonus", stars = bonus })
	end
	return { source = "DashRun", grantId = `dash:{runId}`, lines = lines, xp = xp }
end

-- One-time grants for every medal tier reached for the first time. A first Gold also
-- awards first Silver and first Bronze (ECONOMY.md 2.1).
function DashRewards.firstMedalGrants(medal: Medal, track: Tracks.Track?): { FirstMedal }
	local d = Economy.Dash
	local prefix = trackOrDefault(track).SkuPrefix
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
					grantId = `medal:{prefix}:{lower}`,
					lines = { { sku = `{prefix}_first_{lower}`, stars = amounts[tier] } },
					xp = 0,
				},
			}
			table.insert(result, entry)
		end
	end
	return result
end

-- Guard for a first-medal grant: aborts if the medal flag is already set, otherwise sets it.
function DashRewards.firstMedalGuard(medal: Medal, track: Tracks.Track?): (data: any) -> boolean
	local dataKey = trackOrDefault(track).DataKey
	return function(data: any): boolean
		local medals = data.Minigames[dataKey].Medals
		if medals[medal] then
			return false
		end
		medals[medal] = true
		return true
	end
end

-- Guard for the run grant: records the finish and the personal best in the same update.
-- `isNewBest` is set through the returned getter.
function DashRewards.recordFinishGuard(timeMs: number, track: Tracks.Track?): ((data: any) -> boolean, () -> boolean)
	local dataKey = trackOrDefault(track).DataKey
	local newBest = false
	return function(data: any): boolean
		local dash = data.Minigames[dataKey]
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

-- medalForTime(timeMs, trackId?) uses the limits of that track.
DashRewards.medalForTime = Formulas.medalForTime

return DashRewards
