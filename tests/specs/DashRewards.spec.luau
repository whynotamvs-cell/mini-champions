--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)
local Services = ServerScriptService.Server.Services
local Template = require(Services.PlayerData.Template)
local RewardLogic = require(Services.Logic.RewardLogic)
local DashRewards = require(Services.Minigames.DashRewards)

describe("DashRewards.runGrant", function()
	it("pays 20 / 30 / 40 Stars for Bronze / Silver / Gold (ECONOMY.md 2.1)", function()
		expect(RewardLogic.total(DashRewards.runGrant("a", "Bronze"))).toBe(20)
		expect(RewardLogic.total(DashRewards.runGrant("a", "Silver"))).toBe(30)
		expect(RewardLogic.total(DashRewards.runGrant("a", "Gold"))).toBe(40)
		expect(DashRewards.runGrant("a", "Gold").xp).toBe(30)
		expect(DashRewards.runGrant("xyz", "Bronze").grantId).toBe("dash:xyz")
	end)
end)

describe("DashRewards first medals", function()
	it("a first Gold also awards first Silver and Bronze: 30 + 50 + 100 (TEST_PLAN D-08)", function()
		local grants = DashRewards.firstMedalGrants("Gold")
		expect(#grants).toBe(3)
		local total = 0
		for _, g in grants do
			total += RewardLogic.total(g.grant)
		end
		expect(total).toBe(180)
	end)

	it("each first medal pays once thanks to its flag", function()
		local data = TableUtil.deepCopy(Template)
		local first = DashRewards.firstMedalGrants("Bronze")[1]
		local ok1 = RewardLogic.apply(data, first.grant, DashRewards.firstMedalGuard("Bronze"))
		expect(ok1).toBe(true)
		expect(data.Minigames.DeskDash.Medals.Bronze).toBe(true)
		-- Even with the grantId evicted from RecentGrants, the flag blocks a second payout.
		data.RecentGrants = {}
		local ok2, reason = RewardLogic.apply(data, first.grant, DashRewards.firstMedalGuard("Bronze"))
		expect(ok2).toBe(false)
		expect(reason).toBe("already_granted")
		expect(data.Stars).toBe(30)
	end)
end)

describe("DashRewards.recordFinishGuard", function()
	it("counts finishes and keeps the best time", function()
		local data = TableUtil.deepCopy(Template)
		local guard1, best1 = DashRewards.recordFinishGuard(60_000)
		RewardLogic.apply(data, DashRewards.runGrant("1", "Silver"), guard1)
		expect(best1()).toBe(true)
		local guard2, best2 = DashRewards.recordFinishGuard(65_000)
		RewardLogic.apply(data, DashRewards.runGrant("2", "Silver"), guard2)
		expect(best2()).toBe(false)
		expect(data.Minigames.DeskDash.Finishes).toBe(2)
		expect(data.Minigames.DeskDash.BestTimeMs).toBe(60_000)
	end)
end)

return nil
