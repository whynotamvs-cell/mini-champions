--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Dash = require(ReplicatedStorage.Shared.Config.Dash)

describe("Config.Economy", function()
	it("has 8 upgrades whose prices sum to 3 950", function()
		expect(#Economy.Upgrades).toBe(8)
		local total = 0
		for _, upgrade in Economy.Upgrades do
			expect(upgrade.Price).toBeGreaterThan(0)
			total += upgrade.Price
		end
		expect(total).toBe(3_950)
	end)

	it("has unique upgrade ids", function()
		local seen: { [string]: boolean } = {}
		for _, upgrade in Economy.Upgrades do
			expect(seen[upgrade.Id]).toBeNil()
			seen[upgrade.Id] = true
		end
	end)

	it("keeps every single grant within MaxSingleGrant", function()
		local limit = Economy.Limits.MaxSingleGrant
		for _, value in Economy.Dash do
			expect(value).toBeLessThanOrEqual(limit)
		end
		for _, value in Economy.Tutorial do
			expect(value).toBeLessThanOrEqual(limit)
		end
		expect(Economy.LevelUpStars).toBeLessThanOrEqual(limit)
	end)

	it("makes the first finish pay exactly the first upgrade price (ECONOMY.md 2.3)", function()
		local firstFinish = Economy.Dash.FinishStars + Economy.Dash.FirstBronzeStars + Economy.Tutorial.FirstFinishStars
		expect(firstFinish).toBe(Economy.Upgrades[1].Price)
	end)

	it("orders medal thresholds sensibly", function()
		local t = Economy.DashTiming
		expect(t.MinValidTimeMs).toBeLessThan(t.GoldMaxMs)
		expect(t.GoldMaxMs).toBeLessThan(t.SilverMaxMs)
		expect(t.SilverMaxMs).toBeLessThan(t.TimeoutSec * 1000)
	end)
end)

describe("Config.Dash", function()
	it("has one minimum per segment and their sum stays below MinValidTimeMs", function()
		expect(#Dash.SegmentMinMs).toBe(Dash.CheckpointCount + 1)
		local sum = 0
		for _, ms in Dash.SegmentMinMs do
			sum += ms
		end
		expect(sum).toBeLessThanOrEqual(Dash.MinValidTimeMs)
	end)
end)

return nil
