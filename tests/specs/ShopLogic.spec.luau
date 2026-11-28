--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)
local Services = ServerScriptService.Server.Services
local ShopLogic = require(Services.Logic.ShopLogic)
local Template = require(Services.PlayerData.Template)
local Validate = require(Services.PlayerData.Validate)

local function fresh(): any
	return TableUtil.deepCopy(Template)
end

describe("Config.Shop", function()
	it("has unique ids and known kinds", function()
		local seen: { [string]: boolean } = {}
		for _, item in Shop.Items do
			expect(seen[item.Id]).toBeNil()
			seen[item.Id] = true
			expect(Shop.ById[item.Id]).toBe(item)
		end
		expect(Shop.ById.skip.Kind).toBe("Consumable")
		expect(Shop.ById.spring.Kind).toBe("Pass")
	end)

	it("sells nothing without a Creator Hub id (id 0 = not for sale)", function()
		expect(Shop.findByRobloxId(0, false)).toBeNil()
		expect(Shop.findByRobloxId(0, true)).toBeNil()
	end)

	it("lists the equip ids: every cosmetic plus both clears, no other products", function()
		local ids = Shop.equipIds()
		expect(table.find(ids, Shop.ClearTrail) ~= nil).toBe(true)
		expect(table.find(ids, Shop.ClearFinish) ~= nil).toBe(true)
		expect(table.find(ids, "trail_fire") ~= nil).toBe(true)
		expect(table.find(ids, "skip")).toBeNil()
	end)
end)

describe("ShopLogic.applyProduct", function()
	it("a skip adds one token and is idempotent by receipt", function()
		local data = fresh()
		local ok = ShopLogic.applyProduct(data, Shop.ById.skip, "shop:1")
		expect(ok).toBe(true)
		expect(data.Shop.SkipTokens).toBe(1)
		local ok2, reason = ShopLogic.applyProduct(data, Shop.ById.skip, "shop:1")
		expect(ok2).toBe(false)
		expect(reason).toBe("duplicate")
		expect(data.Shop.SkipTokens).toBe(1)
		ShopLogic.applyProduct(data, Shop.ById.skip, "shop:2")
		expect(data.Shop.SkipTokens).toBe(2)
	end)

	it("never refuses a paid skip at the cap: tokens stay at the maximum", function()
		local data = fresh()
		data.Shop.SkipTokens = Shop.MaxSkipTokens
		local ok = ShopLogic.applyProduct(data, Shop.ById.skip, "shop:cap")
		expect(ok).toBe(true)
		expect(data.Shop.SkipTokens).toBe(Shop.MaxSkipTokens)
	end)

	it("a Stars pack credits exactly its Stars once", function()
		local data = fresh()
		ShopLogic.applyProduct(data, Shop.ById.stars_small, "shop:s1")
		ShopLogic.applyProduct(data, Shop.ById.stars_small, "shop:s1")
		expect(data.Stars).toBe(100)
		expect(data.LifetimeStars).toBe(100)
		ShopLogic.applyProduct(data, Shop.ById.stars_large, "shop:s2")
		expect(data.Stars).toBe(1300)
	end)

	it("a cosmetic becomes owned and the data stays valid", function()
		local data = fresh()
		ShopLogic.applyProduct(data, Shop.ById.trail_fire, "shop:t1")
		expect(data.Shop.Owned.trail_fire).toBe(true)
		expect(#Validate.issues(data)).toBe(0)
	end)

	it("refuses the Game Pass as a product", function()
		local ok, reason = ShopLogic.applyProduct(fresh(), Shop.ById.spring, "shop:p")
		expect(ok).toBe(false)
		expect(reason).toBe("not a product")
	end)

	it("receipt ids fit the grant id limit", function()
		expect(#ShopLogic.receiptGrantId(string.rep("9", 200)) <= 64).toBe(true)
	end)
end)

describe("ShopLogic skips, spring and equipping", function()
	it("useSkip spends a token and fails without one", function()
		local data = fresh()
		expect(ShopLogic.useSkip(data)).toBe(false)
		data.Shop.SkipTokens = 2
		expect(ShopLogic.useSkip(data)).toBe(true)
		expect(data.Shop.SkipTokens).toBe(1)
	end)

	it("spring is switched on only by an owner and goes off when ownership ends", function()
		local data = fresh()
		expect(ShopLogic.setSpring(data, true)).toBe(false)
		ShopLogic.setSpringOwned(data, true)
		expect(ShopLogic.setSpring(data, true)).toBe(true)
		expect(data.Shop.SpringOn).toBe(true)
		ShopLogic.setSpringOwned(data, false)
		expect(data.Shop.SpringOn).toBe(false)
	end)

	it("equips only owned cosmetics of the right slot, and can clear them", function()
		local data = fresh()
		expect(ShopLogic.equip(data, "trail_fire")).toBe(false)
		data.Shop.Owned.trail_fire = true
		data.Shop.Owned.finish_gold = true
		expect(ShopLogic.equip(data, "trail_fire")).toBe(true)
		expect(ShopLogic.equip(data, "finish_gold")).toBe(true)
		expect(data.Shop.Trail).toBe("trail_fire")
		expect(data.Shop.Finish).toBe("finish_gold")
		expect(#Validate.issues(data)).toBe(0)
		expect(ShopLogic.equip(data, Shop.ClearTrail)).toBe(true)
		expect(data.Shop.Trail).toBe("")
		expect(ShopLogic.equip(data, "nonsense")).toBe(false)
		expect(ShopLogic.equip(data, "skip")).toBe(false)
	end)

	it("Validate repairs impossible shop data", function()
		local data = fresh()
		data.Shop.SpringOn = true
		data.Shop.Trail = "trail_fire"
		data.Shop.Owned = { trail_fire = false, ghost = true }
		data.Shop.SkipTokens = 5000
		local fixed = Validate.repair(data)
		expect(#fixed > 0).toBe(true)
		expect(data.Shop.SpringOn).toBe(false)
		expect(data.Shop.Trail).toBe("")
		expect(data.Shop.Owned.ghost).toBeNil()
		expect(data.Shop.SkipTokens).toBe(Shop.MaxSkipTokens)
		expect(#Validate.issues(data)).toBe(0)
	end)
end)

return nil
