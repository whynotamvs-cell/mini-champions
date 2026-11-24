--!strict
-- Club upgrade purchase (docs/DATA_SCHEMA.md 6, level 3; docs/ECONOMY.md 3). Pure.
-- Upgrades are bought strictly in order (D11): only index == UpgradesOwned + 1 is accepted,
-- so a repeated request after a successful purchase is rejected automatically.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local CurrencyLogic = require(script.Parent.CurrencyLogic)
local RewardLogic = require(script.Parent.RewardLogic)

export type Reason = "not_next" | "not_enough" | "invalid_index"

export type Result = {
	index: number,
	upgradeId: string,
	price: number,
	balance: number,
	levelUpStars: number,
}

local PurchaseLogic = {}

function PurchaseLogic.apply(data: any, index: number): (boolean, Result | Reason)
	local upgrade = Economy.Upgrades[index]
	if upgrade == nil then
		return false, "invalid_index"
	end
	if index ~= data.Club.UpgradesOwned + 1 then
		return false, "not_next"
	end
	if not CurrencyLogic.debit(data, upgrade.Price) then
		return false, "not_enough"
	end
	data.Club.UpgradesOwned = index
	local _, _, levelUpStars = RewardLogic.addXP(data, Economy.UpgradePurchaseXP)
	return true,
		{
			index = index,
			upgradeId = upgrade.Id,
			price = upgrade.Price,
			balance = data.Stars,
			levelUpStars = levelUpStars,
		}
end

return PurchaseLogic
