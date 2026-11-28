--!strict
-- Pets: buying with Stars, equipping, and publishing the equipped pet as a player attribute so every
-- client can show it (PetController). The server owns ownership and the balance; the Stars bonus of
-- an equipped pet is added to run rewards in ObstacleDash (DashRewards.runGrant).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Validators = require(ReplicatedStorage.Shared.Net.Validators)

local Net = require(script.Parent.Parent.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local PetLogic = require(script.Parent.Logic.PetLogic)

export type PurchaseResponse = { ok: boolean, reason: string? }

local PetService = {}

local function publish(player: Player)
	local data = PlayerDataService:Get(player)
	player:SetAttribute("Pet", if data then data.Pets.Equipped else "")
end

function PetService:Purchase(player: Player, petId: string): PurchaseResponse
	local failure: string? = nil
	local committed = PlayerDataService:Update(player, function(data): boolean?
		local ok, reason = PetLogic.buy(data, petId)
		if not ok then
			failure = reason
			return false
		end
		-- A new pet goes on straight away: that is what the player wants to see.
		PetLogic.equip(data, petId)
		return true
	end)
	if not committed then
		return { ok = false, reason = failure or "failed" }
	end
	PlayerDataService:SaveNow(player)
	local after = PlayerDataService:Get(player)
	local pet = Pets.ById[petId]
	TelemetryService:Economy(player, "Sink", pet.Price, if after then after.Stars else 0, "Pet", petId)
	publish(player)
	return { ok = true }
end

function PetService:Init()
	Net.onServerInvoke("PurchasePet", {
		rate = { count = 2, per = 1 },
		validate = Validators.tuple(Validators.enumString(Pets.ids())),
	}, function(player: Player, petId: string): PurchaseResponse
		return PetService:Purchase(player, petId)
	end)

	local equipIds = Pets.ids()
	table.insert(equipIds, Pets.ClearId)
	Net.onServerEvent("EquipPet", {
		rate = { count = 3, per = 2 },
		validate = Validators.tuple(Validators.enumString(equipIds)),
	}, function(player: Player, petId: string)
		PlayerDataService:Update(player, function(data): boolean?
			return PetLogic.equip(data, petId)
		end)
		publish(player)
	end)

	PlayerDataService.Loaded:Connect(publish)
end

function PetService:Start() end

return PetService
