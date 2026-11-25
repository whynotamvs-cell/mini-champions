--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Formulas = require(ReplicatedStorage.Shared.Utilities.Formulas)

describe("Formulas.levelInfo", function()
	it("starts at level 1 with 75 XP to go", function()
		local level, into, nextNeed = Formulas.levelInfo(0)
		expect(level).toBe(1)
		expect(into).toBe(0)
		expect(nextNeed).toBe(75)
	end)

	it("stays at level 1 at 74 XP and reaches level 2 at 75", function()
		expect(Formulas.levelFromXP(74)).toBe(1)
		expect(Formulas.levelFromXP(75)).toBe(2)
	end)

	it("matches the cumulative table in ECONOMY.md 4", function()
		expect(Formulas.levelFromXP(175)).toBe(3)
		expect(Formulas.levelFromXP(450)).toBe(5)
		expect(Formulas.levelFromXP(1_575)).toBe(10)
		expect(Formulas.levelFromXP(5_699)).toBe(19)
		expect(Formulas.levelFromXP(5_700)).toBe(20)
	end)

	it("caps at level 20 and keeps extra XP", function()
		local level, into, nextNeed = Formulas.levelInfo(6_000)
		expect(level).toBe(20)
		expect(into).toBe(300)
		expect(nextNeed).toBe(0)
	end)

	it("treats negative and NaN XP as zero", function()
		expect(Formulas.levelFromXP(-10)).toBe(1)
		expect(Formulas.levelFromXP(0 / 0)).toBe(1)
	end)
end)

describe("Formulas.clubLevel", function()
	it("is upgrades owned + 1", function()
		expect(Formulas.clubLevel(0)).toBe(1)
		expect(Formulas.clubLevel(8)).toBe(9)
	end)
end)

describe("Formulas.medalForTime", function()
	it("gives Gold up to and including 55 000 ms", function()
		expect(Formulas.medalForTime(49_000)).toBe("Gold")
		expect(Formulas.medalForTime(49_001)).toBe("Silver")
	end)

	it("gives Silver up to and including 70 000 ms, Bronze after", function()
		expect(Formulas.medalForTime(62_000)).toBe("Silver")
		expect(Formulas.medalForTime(62_001)).toBe("Bronze")
		expect(Formulas.medalForTime(179_000)).toBe("Bronze")
	end)
end)

describe("Formulas.upgradePrice", function()
	it("returns prices by index and nil outside 1..8", function()
		expect(Formulas.upgradePrice(1)).toBe(100)
		expect(Formulas.upgradePrice(8)).toBe(1_100)
		expect(Formulas.upgradePrice(0)).toBeNil()
		expect(Formulas.upgradePrice(9)).toBeNil()
	end)
end)

return nil
