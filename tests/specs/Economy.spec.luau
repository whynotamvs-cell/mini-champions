--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)

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

describe("Config.Tracks", function()
	it("has one minimum per segment and their sum stays below MinValidTimeMs, for every track", function()
		for _, trackId in Tracks.Order do
			local track = Tracks.ById[trackId]
			expect(#track.SegmentMinMs).toBe(track.CheckpointCount + 1)
			local sum = 0
			for _, ms in track.SegmentMinMs do
				sum += ms
			end
			expect(sum).toBeLessThanOrEqual(track.MinValidTimeMs)
		end
	end)

	it("orders medal thresholds sensibly, for every track", function()
		for _, trackId in Tracks.Order do
			local t = Tracks.ById[trackId]
			expect(t.MinValidTimeMs).toBeLessThan(t.GoldMaxMs)
			expect(t.GoldMaxMs).toBeLessThan(t.SilverMaxMs)
			expect(t.SilverMaxMs).toBeLessThan(t.TimeoutSec * 1000)
		end
	end)

	it("lists every track once, with unique data keys, and the default exists", function()
		local keys: { [string]: boolean } = {}
		for _, trackId in Tracks.Order do
			local track = Tracks.ById[trackId]
			expect(track.Id).toBe(trackId)
			expect(keys[track.DataKey]).toBe(nil)
			keys[track.DataKey] = true
		end
		expect(Tracks.ById[Tracks.Default] ~= nil).toBe(true)
	end)

	it("only the first track is open from the start", function()
		expect(Tracks.ById.desk.RequiresTutorial).toBe(false)
		expect(Tracks.ById.keys.RequiresTutorial).toBe(true)
	end)
end)

return nil
