--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)
local Services = ServerScriptService.Server.Services
local Template = require(Services.PlayerData.Template)
local RewardLogic = require(Services.Logic.RewardLogic)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
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

describe("DashRewards on the keys track", function()
	local Keys = Tracks.ById.keys

	it("pays the same stars but under its own SKUs", function()
		local grant = DashRewards.runGrant("run-k", "Gold", Keys)
		expect(grant.lines[1].sku).toBe("keys_finish")
		expect(grant.lines[2].sku).toBe("keys_medal_gold")
		expect(grant.lines[1].stars).toBe(DashRewards.runGrant("run-d", "Gold").lines[1].stars)
	end)

	it("first medals have their own grant ids and flags per track", function()
		local data = TableUtil.deepCopy(Template) :: any
		local desk = DashRewards.firstMedalGrants("Bronze")
		local keys = DashRewards.firstMedalGrants("Bronze", Keys)
		expect(desk[1].grant.grantId).toBe("medal:dash:bronze")
		expect(keys[1].grant.grantId).toBe("medal:keys:bronze")
		expect(DashRewards.firstMedalGuard("Bronze", Keys)(data)).toBe(true)
		expect(data.Minigames.KeyDash.Medals.Bronze).toBe(true)
		expect(data.Minigames.DeskDash.Medals.Bronze).toBe(false) -- the other track is untouched
		expect(DashRewards.firstMedalGuard("Bronze", Keys)(data)).toBe(false) -- once per track
		expect(DashRewards.firstMedalGuard("Bronze")(data)).toBe(true) -- desk still gets its own
	end)

	it("records finishes and the best time on the right track only", function()
		local data = TableUtil.deepCopy(Template) :: any
		local guard, isNewBest = DashRewards.recordFinishGuard(48_000, Keys)
		expect(guard(data)).toBe(true)
		expect(isNewBest()).toBe(true)
		expect(data.Minigames.KeyDash.Finishes).toBe(1)
		expect(data.Minigames.KeyDash.BestTimeMs).toBe(48_000)
		expect(data.Minigames.DeskDash.Finishes).toBe(0)
		expect(data.Minigames.DeskDash.BestTimeMs).toBe(0)
	end)

	it("medals follow each track's own limits", function()
		expect(DashRewards.medalForTime(47_000, "keys")).toBe("Silver") -- gold <= 46 s on keys
		expect(DashRewards.medalForTime(47_000, "desk")).toBe("Gold") -- gold <= 49 s on desk
		expect(DashRewards.medalForTime(47_000)).toBe("Gold") -- default is desk
	end)
end)

return nil
