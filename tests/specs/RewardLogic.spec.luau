--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)
local Services = ServerScriptService.Server.Services
local Template = require(Services.PlayerData.Template)
local RewardLogic = require(Services.Logic.RewardLogic)
local CurrencyLogic = require(Services.Logic.CurrencyLogic)

local function fresh(): any
	return TableUtil.deepCopy(Template)
end

local function dashGrant(runId: string): RewardLogic.Grant
	return { source = "DashRun", grantId = `dash:{runId}`, lines = { { sku = "dash_finish", stars = 20 } }, xp = 20 }
end

describe("RewardLogic.apply", function()
	it("credits stars and XP and records the grantId", function()
		local data = fresh()
		local ok, result = RewardLogic.apply(data, dashGrant("a"))
		expect(ok).toBe(true)
		expect(data.Stars).toBe(20)
		expect(data.LifetimeStars).toBe(20)
		expect(data.XP).toBe(20)
		expect(data.RecentGrants).toEqual({ "dash:a" })
		expect((result :: any).starsAdded).toBe(20)
	end)

	it("treats a repeated grantId as a no-op", function()
		local data = fresh()
		RewardLogic.apply(data, dashGrant("a"))
		local ok, reason = RewardLogic.apply(data, dashGrant("a"))
		expect(ok).toBe(false)
		expect(reason).toBe("duplicate")
	end)

	it("lets a guard block a one-time reward whose flag is already set", function()
		local data = fresh()
		data.Minigames.DeskDash.Medals.Gold = true
		local grant: RewardLogic.Grant = {
			source = "DashFirstMedal",
			grantId = "medal:dash:gold",
			lines = { { sku = "dash_first_gold", stars = 100 } },
			xp = 0,
		}
		local ok, reason = RewardLogic.apply(data, grant, function(d)
			if d.Minigames.DeskDash.Medals.Gold then
				return false
			end
			d.Minigames.DeskDash.Medals.Gold = true
			return true
		end)
		expect(ok).toBe(false)
		expect(reason).toBe("already_granted")
	end)

	it("rejects grants over MaxSingleGrant, unknown sources and bad numbers", function()
		local data = fresh()
		local cases: { any } = {
			{ source = "DashRun", grantId = "x1", lines = { { sku = "a", stars = 501 } }, xp = 0 },
			{
				source = "DashRun",
				grantId = "x2",
				lines = { { sku = "a", stars = 300 }, { sku = "b", stars = 300 } },
				xp = 0,
			},
			{ source = "Cheat", grantId = "x3", lines = { { sku = "a", stars = 1 } }, xp = 0 },
			{ source = "DashRun", grantId = "x4", lines = { { sku = "a", stars = -5 } }, xp = 0 },
			{ source = "DashRun", grantId = "x5", lines = { { sku = "a", stars = 0 / 0 } }, xp = 0 },
			{ source = "DashRun", grantId = "x6", lines = { { sku = "a", stars = 1.5 } }, xp = 0 },
			{ source = "DashRun", grantId = string.rep("g", 65), lines = {}, xp = 0 },
		}
		for _, grant in cases do
			expect((RewardLogic.apply(data, grant))).toBe(false)
		end
		expect(data.Stars).toBe(0)
	end)

	it("pays +25 Stars per level gained", function()
		local data = fresh()
		data.XP = 70
		local ok, result = RewardLogic.apply(data, dashGrant("lvl"))
		expect(ok).toBe(true)
		expect((result :: any).levelBefore).toBe(1)
		expect((result :: any).levelAfter).toBe(2)
		expect((result :: any).levelUpStars).toBe(25)
		expect(data.Stars).toBe(45)
	end)

	it("keeps at most 50 recent grantIds", function()
		local data = fresh()
		for i = 1, 55 do
			RewardLogic.apply(data, { source = "DashRun", grantId = `dash:{i}`, lines = {}, xp = 0 })
		end
		expect(#data.RecentGrants).toBe(50)
		expect(data.RecentGrants[1]).toBe("dash:6")
	end)

	it("caps the balance at 1 000 000", function()
		local data = fresh()
		data.Stars = 999_990
		RewardLogic.apply(data, dashGrant("cap"))
		expect(data.Stars).toBe(1_000_000)
	end)
end)

describe("CurrencyLogic.debit", function()
	it("never goes below zero and leaves the balance unchanged on failure", function()
		local data = fresh()
		data.Stars = 99
		expect(CurrencyLogic.debit(data, 100)).toBe(false)
		expect(data.Stars).toBe(99)
		expect(CurrencyLogic.debit(data, 99)).toBe(true)
		expect(data.Stars).toBe(0)
	end)

	it("refuses invalid amounts", function()
		local data = fresh()
		expect(function()
			CurrencyLogic.debit(data, -1)
		end).toThrow()
		expect(function()
			CurrencyLogic.credit(data, 0 / 0)
		end).toThrow()
	end)
end)

describe("First session economy (ECONOMY.md 5, TEST_PLAN F-02)", function()
	it("first finish = 100 Stars; after first purchase and tutorial = 65 Stars, level 2", function()
		local data = fresh()
		RewardLogic.apply(data, dashGrant("run1"))
		RewardLogic.apply(data, {
			source = "DashFirstMedal",
			grantId = "medal:dash:bronze",
			lines = { { sku = "dash_first_bronze", stars = 30 } },
			xp = 0,
		})
		RewardLogic.apply(data, {
			source = "Tutorial",
			grantId = "tutorial:first_finish",
			lines = { { sku = "tutorial_first_finish", stars = 50 } },
			xp = 30,
		})
		expect(data.Stars).toBe(100)

		expect(CurrencyLogic.debit(data, 100)).toBe(true)
		data.XP += 15 -- UpgradePurchaseXP
		RewardLogic.apply(data, {
			source = "Tutorial",
			grantId = "tutorial:complete",
			lines = { { sku = "tutorial_complete", stars = 40 } },
			xp = 20,
		})
		expect(data.XP).toBe(85)
		expect(data.Stars).toBe(65)
	end)
end)

return nil
