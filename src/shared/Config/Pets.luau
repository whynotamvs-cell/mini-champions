--!strict
-- Desk pets (docs/ECONOMY.md 10): bought with Stars at a fixed price (no random drops), one can be
-- equipped and follows its owner. An equipped pet adds BonusPct percent to the Stars of every
-- finished run. Looks are built from simple parts by PetController from this table.

export type Pet = {
	Id: string,
	Price: number,
	BonusPct: number,
	-- Body colour {r, g, b} 0..255, relative size and the kind of "ears" it wears.
	Color: { number },
	Size: number,
	Kind: string, -- "bunny" | "pup" | "cat" | "dino" | "bug" | "dragon"
}

local function pet(id: string, price: number, bonus: number, color: { number }, size: number, kind: string): Pet
	return table.freeze({ Id = id, Price = price, BonusPct = bonus, Color = color, Size = size, Kind = kind }) :: Pet
end

local Items: { Pet } = {
	pet("paperclip_bug", 100, 2, { 190, 200, 215 }, 1.0, "bug"),
	pet("eraser_bunny", 250, 4, { 255, 150, 170 }, 1.05, "bunny"),
	pet("pencil_pup", 500, 6, { 255, 205, 70 }, 1.1, "pup"),
	pet("sticky_cat", 900, 8, { 255, 235, 110 }, 1.1, "cat"),
	pet("stapler_dino", 1500, 10, { 230, 70, 80 }, 1.25, "dino"),
	pet("compass_dragon", 3000, 15, { 120, 90, 230 }, 1.4, "dragon"),
}

local ById: { [string]: Pet } = {}
for _, entry in Items do
	ById[entry.Id] = entry
end

local Pets = {}

Pets.Items = table.freeze(Items)
Pets.ById = table.freeze(ById)
-- Equip id that clears the slot.
Pets.ClearId = "none"

-- Ids accepted by the PurchasePet / EquipPet remotes (EquipPet also takes ClearId).
function Pets.ids(): { string }
	local ids = {}
	for _, entry in Items do
		table.insert(ids, entry.Id)
	end
	return ids
end

-- Bonus Stars for a run that paid `baseStars`: whole Stars, rounded down, at least 1 when the pet
-- has any bonus and the run paid anything.
function Pets.bonusStars(petId: string?, baseStars: number): number
	local entry = if petId then ById[petId] else nil
	if entry == nil or baseStars <= 0 then
		return 0
	end
	return math.max(1, math.floor(baseStars * entry.BonusPct / 100))
end

return Pets
