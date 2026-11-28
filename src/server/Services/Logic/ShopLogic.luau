--!strict
-- Applying paid items to player data (docs/ECONOMY.md 9). Pure; runs inside PlayerDataService:Update().
-- Every purchase is idempotent by receipt: a receipt id seen before changes nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)

local CurrencyLogic = require(script.Parent.CurrencyLogic)

local ShopLogic = {}

local function remember(data: any, grantId: string)
	table.insert(data.RecentGrants, grantId)
	while #data.RecentGrants > Economy.Limits.RecentGrantsMax do
		table.remove(data.RecentGrants, 1)
	end
end

-- Receipt ids become "shop:<PurchaseId>", cut to GrantIdMaxLength.
function ShopLogic.receiptGrantId(purchaseId: string): string
	return string.sub(`shop:{purchaseId}`, 1, Economy.Limits.GrantIdMaxLength)
end

-- Grants a Developer Product. Returns (true) when applied, (false, "duplicate") when this receipt
-- was already applied, (false, reason) otherwise (data must then be discarded).
function ShopLogic.applyProduct(data: any, item: Shop.Item, grantId: string): (boolean, string?)
	if item.Kind == "Pass" then
		return false, "not a product"
	end
	if table.find(data.RecentGrants, grantId) then
		return false, "duplicate"
	end
	local shop = data.Shop
	if item.Kind == "Consumable" then
		-- Never refuse paid goods: at the cap the player keeps the maximum and the receipt is consumed.
		shop.SkipTokens = math.min(Shop.MaxSkipTokens, shop.SkipTokens + 1)
	elseif item.Kind == "StarsPack" then
		CurrencyLogic.credit(data, item.Stars or 0)
	elseif item.Kind == "Trail" or item.Kind == "Finish" then
		shop.Owned[item.Id] = true
	else
		return false, "unknown kind"
	end
	remember(data, grantId)
	return true, nil
end

-- Owning the Game Pass is a fact about the Roblox account; the caller checked it with Roblox.
function ShopLogic.setSpringOwned(data: any, owned: boolean)
	data.Shop.SpringBoots = owned
	if not owned then
		data.Shop.SpringOn = false
	end
end

function ShopLogic.setSpring(data: any, on: boolean): boolean
	if on and not data.Shop.SpringBoots then
		return false
	end
	data.Shop.SpringOn = on
	return true
end

-- Spends one skip. False when the player has none.
function ShopLogic.useSkip(data: any): boolean
	if data.Shop.SkipTokens <= 0 then
		return false
	end
	data.Shop.SkipTokens -= 1
	return true
end

-- Equips an owned cosmetic, or clears a slot with Shop.ClearTrail / Shop.ClearFinish.
function ShopLogic.equip(data: any, id: string): boolean
	local shop = data.Shop
	if id == Shop.ClearTrail then
		shop.Trail = ""
		return true
	elseif id == Shop.ClearFinish then
		shop.Finish = ""
		return true
	end
	local item = Shop.ById[id]
	if item == nil or not shop.Owned[id] then
		return false
	end
	if item.Kind == "Trail" then
		shop.Trail = id
		return true
	elseif item.Kind == "Finish" then
		shop.Finish = id
		return true
	end
	return false
end

return ShopLogic
