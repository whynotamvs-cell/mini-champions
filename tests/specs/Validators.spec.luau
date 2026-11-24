--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Validators = require(ReplicatedStorage.Shared.Net.Validators)

describe("Validators.integer", function()
	local index = Validators.integer(1, 8)

	it("accepts integers in range", function()
		expect((index(1))).toBe(true)
		expect((index(8))).toBe(true)
	end)

	it("rejects out of range, fractions, NaN, infinity and huge numbers", function()
		for _, bad in { 0, 9, -1, 1.5, 0 / 0, math.huge, -math.huge, 2 ^ 53 } do
			expect((index(bad))).toBe(false)
		end
	end)

	it("rejects other types", function()
		for _, bad in { "1", true, {}, { 1 } } :: { any } do
			expect((index(bad))).toBe(false)
		end
		expect((index(nil))).toBe(false)
	end)

	it("treats -0 as 0", function()
		expect((Validators.integer(0, 8)(-0))).toBe(true)
	end)
end)

describe("Validators.string and enumString", function()
	it("rejects long strings and invalid utf8", function()
		local s = Validators.string(4)
		expect((s("abcd"))).toBe(true)
		expect((s("abcde"))).toBe(false)
		expect((s("\255\254"))).toBe(false)
	end)

	it("accepts only listed values", function()
		local e = Validators.enumString({ "en", "ru", "auto" })
		expect((e("ru"))).toBe(true)
		expect((e("xx"))).toBe(false)
		expect((e(string.rep("a", 10_000)))).toBe(false)
		expect((e(1))).toBe(false)
	end)
end)

describe("Validators.tuple", function()
	local purchase = Validators.tuple(Validators.integer(1, 8))

	it("requires the exact argument count", function()
		expect((purchase(1, 3))).toBe(true)
		expect((purchase(0))).toBe(false)
		expect((purchase(2, 3, 4))).toBe(false)
	end)

	it("reports which argument failed", function()
		local ok, reason = purchase(1, "3")
		expect(ok).toBe(false)
		expect(reason).toContain("arg 1")
	end)

	it("none() accepts no arguments only", function()
		expect((Validators.none(0))).toBe(true)
		expect((Validators.none(1, nil))).toBe(false)
	end)
end)

return nil
