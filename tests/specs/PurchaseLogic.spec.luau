--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)
local Services = ServerScriptService.Server.Services
local Template = require(Services.PlayerData.Template)
local PurchaseLogic = require(Services.Logic.PurchaseLogic)

local function withStars(stars: number): any
	local data = TableUtil.deepCopy(Template)
	data.Stars = stars
	return data
end

describe("PurchaseLogic.apply", function()
	it("buys the next upgrade, charging exactly its price (TEST_PLAN K-01)", function()
		local data = withStars(130)
		local ok, result = PurchaseLogic.apply(data, 1)
		expect(ok).toBe(true)
		expect(data.Stars).toBe(30)
		expect(data.Club.UpgradesOwned).toBe(1)
		expect((result :: any).upgradeId).toBe("sticky_banner")
		expect(data.XP).toBe(15)
	end)

	it("refuses without enough Stars and leaves the balance unchanged (K-02)", function()
		local data = withStars(99)
		local ok, reason = PurchaseLogic.apply(data, 1)
		expect(ok).toBe(false)
		expect(reason).toBe("not_enough")
		expect(data.Stars).toBe(99)
		expect(data.Club.UpgradesOwned).toBe(0)
	end)

	it("refuses anything but the next index (TEST_PLAN X-01)", function()
		local data = withStars(10_000)
		local ok, reason = PurchaseLogic.apply(data, 8)
		expect(ok).toBe(false)
		expect(reason).toBe("not_next")
		expect(data.Stars).toBe(10_000)
	end)

	it("a repeated request for the same index cannot charge twice", function()
		local data = withStars(1_000)
		expect((PurchaseLogic.apply(data, 1))).toBe(true)
		local ok, reason = PurchaseLogic.apply(data, 1)
		expect(ok).toBe(false)
		expect(reason).toBe("not_next")
		expect(data.Stars).toBe(900)
	end)

	it("rejects indexes outside 1..8", function()
		local data = withStars(10_000)
		for _, bad in { 0, 9, -1 } do
			expect((PurchaseLogic.apply(data, bad))).toBe(false)
		end
	end)

	it("buying all 8 costs 3 950 and gives club level 9 (K-03)", function()
		local data = withStars(3_950)
		for i = 1, 8 do
			expect((PurchaseLogic.apply(data, i))).toBe(true)
		end
		expect(data.Club.UpgradesOwned).toBe(8)
		-- Level-up bonuses from purchase XP are the only Stars left.
		expect(data.Stars).toBe(25 * 1)
	end)

	it("pays the level-up bonus when purchase XP crosses a level", function()
		local data = withStars(100)
		data.XP = 70
		local ok, result = PurchaseLogic.apply(data, 1)
		expect(ok).toBe(true)
		expect((result :: any).levelUpStars).toBe(25)
		expect(data.Stars).toBe(25)
	end)
end)

return nil
