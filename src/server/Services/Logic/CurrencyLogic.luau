--!strict
-- The only code that changes Stars. Pure: works on a data table inside PlayerDataService:Update().
-- CurrencyService owns Stars by owning this module (docs/ARCHITECTURE.md 1, principle 2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local CurrencyLogic = {}

local function isAmount(n: any): boolean
	return type(n) == "number" and n == n and n >= 0 and n % 1 == 0 and n <= Economy.Limits.MaxBalance
end

-- Adds up to `amount` Stars (balance is capped at MaxBalance). Returns the amount actually added.
function CurrencyLogic.credit(data: any, amount: number): number
	assert(isAmount(amount), `CurrencyLogic.credit: invalid amount {tostring(amount)}`)
	local before = data.Stars
	data.Stars = math.min(Economy.Limits.MaxBalance, before + amount)
	local added = data.Stars - before
	data.LifetimeStars += added
	return added
end

-- Removes exactly `amount` Stars if the balance allows it. Never goes below zero.
function CurrencyLogic.debit(data: any, amount: number): boolean
	assert(isAmount(amount), `CurrencyLogic.debit: invalid amount {tostring(amount)}`)
	if data.Stars < amount then
		return false
	end
	data.Stars -= amount
	return true
end

return CurrencyLogic
