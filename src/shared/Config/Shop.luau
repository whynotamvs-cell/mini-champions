--!strict
-- Paid items (docs/ECONOMY.md 9). Nothing here changes records or medals: a run with help
-- (skip, spring) is finished without a medal or a record (docs/ARCHITECTURE.md 8.5).
--
-- RobloxId is the Developer Product id (Consumable, StarsPack, Trail, Finish) or the Game Pass id
-- (Pass). 0 means "not created in Creator Hub yet": the item is shown as "Soon" and cannot be bought.
-- The owner fills the ids after creating the products; prices are set in Creator Hub, not here.

export type Kind = "Consumable" | "Pass" | "StarsPack" | "Trail" | "Finish"

export type Item = {
	Id: string,
	Kind: Kind,
	RobloxId: number,
	-- StarsPack only: Stars credited per purchase.
	Stars: number?,
	-- Trail / Finish: colour as {r, g, b} 0..255 (a table so it stays plain data).
	Color: { number }?,
}

-- Ids of the TEST experience "Mini Champions [TEST]" (universe 10778182955). The release experience
-- has its own products: create them there and replace these numbers (docs/PUBLISHING.md 6).
local IDS: { [string]: number } = {
	skip = 3737346186,
	spring = 2099095830,
	stars_small = 3737346277,
	stars_medium = 3737346283,
	stars_large = 3737346290,
	trail_rainbow = 3737346305,
	trail_stars = 3737346320,
	trail_fire = 3737346330,
	finish_gold = 3737346344,
	finish_rainbow = 3737346353,
}

local function item(id: string, kind: Kind, extra: { [string]: any }?): Item
	local result: any = { Id = id, Kind = kind, RobloxId = IDS[id] or 0 }
	if extra then
		for key, value in extra do
			result[key] = value
		end
	end
	return table.freeze(result) :: Item
end

local Items: { Item } = {
	item("skip", "Consumable"),
	item("spring", "Pass"),
	item("stars_small", "StarsPack", { Stars = 100 }),
	item("stars_medium", "StarsPack", { Stars = 550 }),
	item("stars_large", "StarsPack", { Stars = 1200 }),
	item("trail_rainbow", "Trail", { Color = { 255, 120, 200 } }),
	item("trail_stars", "Trail", { Color = { 255, 215, 90 } }),
	item("trail_fire", "Trail", { Color = { 255, 110, 40 } }),
	item("finish_gold", "Finish", { Color = { 255, 205, 60 } }),
	item("finish_rainbow", "Finish", { Color = { 120, 220, 255 } }),
}

local ById: { [string]: Item } = {}
for _, entry in Items do
	ById[entry.Id] = entry
end

local Shop = {}

Shop.Items = table.freeze(Items)
Shop.ById = table.freeze(ById)

-- Jump height of a player with Spring Boots on (R15 default is 7.2).
Shop.SpringJumpHeight = 15
-- Most unused skips a player can hold.
Shop.MaxSkipTokens = 99
-- Equip ids that clear a slot.
Shop.ClearTrail = "none_trail"
Shop.ClearFinish = "none_finish"

-- All ids accepted by the EquipCosmetic remote.
function Shop.equipIds(): { string }
	local ids = { Shop.ClearTrail, Shop.ClearFinish }
	for _, entry in Items do
		if entry.Kind == "Trail" or entry.Kind == "Finish" then
			table.insert(ids, entry.Id)
		end
	end
	return ids
end

-- Looks an item up by its Creator Hub id, among the products of one family: a Game Pass id and a
-- Developer Product id may be equal numbers, so the caller says which one it holds.
function Shop.findByRobloxId(robloxId: number, isPass: boolean): Item?
	if robloxId == 0 then
		return nil
	end
	for _, entry in Items do
		if entry.RobloxId == robloxId and (entry.Kind == "Pass") == isPass then
			return entry
		end
	end
	return nil
end

return Shop
