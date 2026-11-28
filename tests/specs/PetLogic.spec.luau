--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)
local Services = ServerScriptService.Server.Services
local DashRewards = require(Services.Minigames.DashRewards)
local PetLogic = require(Services.Logic.PetLogic)
local RewardLogic = require(Services.Logic.RewardLogic)
local Template = require(Services.PlayerData.Template)
local Validate = require(Services.PlayerData.Validate)

local function fresh(): any
	return TableUtil.deepCopy(Template)
end

describe("Config.Pets", function()
	it("has unique ids, rising prices and rising bonuses", function()
		local seen: { [string]: boolean } = {}
		local lastPrice, lastBonus = 0, 0
		for _, pet in Pets.Items do
			expect(seen[pet.Id]).toBeNil()
			seen[pet.Id] = true
			expect(pet.Price > lastPrice).toBe(true)
			expect(pet.BonusPct > lastBonus).toBe(true)
			lastPrice, lastBonus = pet.Price, pet.BonusPct
		end
	end)

	it("bonus Stars: whole numbers, at least 1, none without a pet", function()
		expect(Pets.bonusStars(nil, 50)).toBe(0)
		expect(Pets.bonusStars("", 50)).toBe(0)
		expect(Pets.bonusStars("paperclip_bug", 0)).toBe(0)
		expect(Pets.bonusStars("paperclip_bug", 20)).toBe(1) -- 2% of 20 rounds down to 0, but never less than 1
		expect(Pets.bonusStars("compass_dragon", 100)).toBe(15)
		expect(Pets.bonusStars("stapler_dino", 45)).toBe(4)
	end)
end)

describe("PetLogic.buy", function()
	it("spends exactly the price and owns the pet", function()
		local data = fresh()
		data.Stars = 300
		local ok = PetLogic.buy(data, "eraser_bunny")
		expect(ok).toBe(true)
		expect(data.Stars).toBe(50)
		expect(data.Pets.Owned.eraser_bunny).toBe(true)
		expect(#Validate.issues(data)).toBe(0)
	end)

	it("refuses without enough Stars, an unknown pet or a second purchase", function()
		local data = fresh()
		data.Stars = 99
		local ok, reason = PetLogic.buy(data, "paperclip_bug")
		expect(ok).toBe(false)
		expect(reason).toBe("no_stars")
		expect(data.Stars).toBe(99)
		expect((select(2, PetLogic.buy(data, "ghost")))).toBe("unknown")
		data.Stars = 500
		PetLogic.buy(data, "paperclip_bug")
		local ok2, reason2 = PetLogic.buy(data, "paperclip_bug")
		expect(ok2).toBe(false)
		expect(reason2).toBe("owned")
		expect(data.Stars).toBe(400)
	end)
end)

describe("PetLogic.equip", function()
	it("equips only owned pets and can clear the slot", function()
		local data = fresh()
		expect(PetLogic.equip(data, "pencil_pup")).toBe(false)
		data.Pets.Owned.pencil_pup = true
		expect(PetLogic.equip(data, "pencil_pup")).toBe(true)
		expect(data.Pets.Equipped).toBe("pencil_pup")
		expect(#Validate.issues(data)).toBe(0)
		expect(PetLogic.equip(data, Pets.ClearId)).toBe(true)
		expect(data.Pets.Equipped).toBe("")
		expect(PetLogic.equip(data, "nonsense")).toBe(false)
	end)

	it("Validate repairs an equipped pet that is not owned", function()
		local data = fresh()
		data.Pets.Equipped = "stapler_dino"
		data.Pets.Owned = { ghost = true }
		expect(#Validate.repair(data) > 0).toBe(true)
		expect(data.Pets.Equipped).toBe("")
		expect(data.Pets.Owned.ghost).toBeNil()
	end)
end)

describe("Pet bonus in the run reward", function()
	it("adds a pet_bonus line and stays one idempotent grant", function()
		local without = DashRewards.runGrant("r1", "Gold")
		local with = DashRewards.runGrant("r1", "Gold", nil, "compass_dragon")
		expect(RewardLogic.total(without)).toBe(40)
		expect(RewardLogic.total(with)).toBe(46) -- 15% of 40 = 6
		expect(with.grantId).toBe(without.grantId)
		local data = fresh()
		local ok = RewardLogic.apply(data, with)
		expect(ok).toBe(true)
		expect(data.Stars).toBe(46)
		local ok2, reason = RewardLogic.apply(data, with)
		expect(ok2).toBe(false)
		expect(reason).toBe("duplicate")
		expect(data.Stars).toBe(46)
	end)

	it("no pet means no bonus line", function()
		for _, line in DashRewards.runGrant("r2", "Bronze").lines do
			expect(line.sku == "pet_bonus").toBe(false)
		end
	end)
end)

return nil
