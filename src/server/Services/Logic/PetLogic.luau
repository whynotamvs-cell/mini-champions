--!strict
-- Buying and equipping pets (docs/ECONOMY.md 10). Pure; runs inside PlayerDataService:Update().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pets = require(ReplicatedStorage.Shared.Config.Pets)

local CurrencyLogic = require(script.Parent.CurrencyLogic)

local PetLogic = {}

-- Spends Stars on a pet. Returns (true) or (false, reason): "unknown", "owned", "no_stars".
function PetLogic.buy(data: any, petId: string): (boolean, string?)
	local pet = Pets.ById[petId]
	if pet == nil then
		return false, "unknown"
	end
	if data.Pets.Owned[petId] then
		return false, "owned"
	end
	if not CurrencyLogic.debit(data, pet.Price) then
		return false, "no_stars"
	end
	data.Pets.Owned[petId] = true
	return true, nil
end

-- Equips an owned pet, or clears the slot with Pets.ClearId.
function PetLogic.equip(data: any, petId: string): boolean
	if petId == Pets.ClearId then
		data.Pets.Equipped = ""
		return true
	end
	if Pets.ById[petId] == nil or not data.Pets.Owned[petId] then
		return false
	end
	data.Pets.Equipped = petId
	return true
end

return PetLogic
