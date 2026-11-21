--!strict
-- Grants Stars and XP idempotently by grantId (docs/DATA_SCHEMA.md 6). The single entry point
-- for every source of Stars; logs one economy event per line plus the level-up bonus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)

local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local RewardLogic = require(script.Parent.Logic.RewardLogic)

export type Grant = RewardLogic.Grant
export type Result = RewardLogic.Result

local RewardService = {}

-- Fired after a committed grant: (player, grant, result). Handlers must not yield.
RewardService.Granted = Signal.new() :: Signal.Signal<Player, Grant, Result>

function RewardService:Init() end
function RewardService:Start() end

-- Returns the result when committed, or nil and a reason ("duplicate", "already_granted", ...).
-- `guard` may check and set a permanent one-time flag in the same atomic update.
function RewardService:Grant(
	player: Player,
	grant: Grant,
	guard: ((data: any) -> boolean)?,
	saveNow: boolean?
): (Result?, string?)
	local result: Result? = nil
	local failure: string? = nil
	local committed = PlayerDataService:Update(player, function(data): boolean?
		local ok, value = RewardLogic.apply(data, grant, guard)
		if not ok then
			failure = value :: string
			return false
		end
		result = value :: Result
		return true
	end)

	if not committed or result == nil then
		local reason = failure or "not committed"
		if reason ~= "duplicate" and reason ~= "already_granted" then
			warn(`[RewardService] grant {grant.grantId} for {player.UserId} rejected: {reason}`)
		end
		return nil, reason
	end

	local transactionType = RewardLogic.TRANSACTION_TYPE[grant.source]
	-- Ending balance per line: reconstruct the running balance in order.
	local running = result.balance - result.levelUpStars - result.starsAdded
	for _, line in grant.lines do
		running += line.stars
		TelemetryService:Economy(player, "Source", line.stars, running, transactionType, line.sku)
	end
	if result.levelUpStars > 0 then
		TelemetryService:Economy(player, "Source", result.levelUpStars, result.balance, "Gameplay", "level_up")
	end

	if saveNow then
		PlayerDataService:SaveNow(player)
	end

	RewardService.Granted:Fire(player, grant, result)
	return result, nil
end

return RewardService
