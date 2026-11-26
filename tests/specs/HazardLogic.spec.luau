--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local HazardLogic = require(ReplicatedStorage.Shared.Utilities.HazardLogic)

describe("HazardLogic.laserOn", function()
	it("is on for onSec of every period", function()
		expect(HazardLogic.laserOn(0, 3, 1, 0)).toBe(true)
		expect(HazardLogic.laserOn(0.99, 3, 1, 0)).toBe(true)
		expect(HazardLogic.laserOn(1, 3, 1, 0)).toBe(false)
		expect(HazardLogic.laserOn(2.99, 3, 1, 0)).toBe(false)
		expect(HazardLogic.laserOn(3, 3, 1, 0)).toBe(true)
	end)

	it("shifts with the phase", function()
		expect(HazardLogic.laserOn(0, 3, 1, 1.5)).toBe(false)
		expect(HazardLogic.laserOn(1.5, 3, 1, 1.5)).toBe(true)
	end)

	it("is off for a broken period", function()
		expect(HazardLogic.laserOn(5, 0, 1, 0)).toBe(false)
	end)
end)

describe("HazardLogic.secondsUntilOn", function()
	it("counts down to the next pulse", function()
		expect(HazardLogic.secondsUntilOn(0.5, 3, 1, 0)).toBe(0)
		expect(HazardLogic.secondsUntilOn(1, 3, 1, 0)).toBe(2)
		expect(HazardLogic.secondsUntilOn(2.5, 3, 1, 0)).toBe(0.5)
	end)
end)

describe("HazardLogic hit tests", function()
	it("box: inside, near edge (pad) and outside", function()
		expect(HazardLogic.inBox(0, 0, 0, 0, 0, 0, 2, 2, 2)).toBe(true)
		expect(HazardLogic.inBox(1.5, 0, 0, 0, 0, 0, 2, 2, 2)).toBe(true)
		expect(HazardLogic.inBox(3, 0, 0, 0, 0, 0, 2, 2, 2)).toBe(false)
		expect(HazardLogic.inBox(0, 5, 0, 0, 0, 0, 2, 2, 2)).toBe(false)
	end)

	it("bar: follows the angle", function()
		-- a 10 long, 1 wide bar along +X
		expect(HazardLogic.inBar(4, 0, 0, 0, 0, 0, 10, 2, 1, 0)).toBe(true)
		expect(HazardLogic.inBar(0, 0, 4, 0, 0, 0, 10, 2, 1, 0)).toBe(false)
		-- turned a quarter turn it lies along Z instead
		expect(HazardLogic.inBar(0, 0, 4, 0, 0, 0, 10, 2, 1, math.pi / 2)).toBe(true)
		expect(HazardLogic.inBar(4, 0, 0, 0, 0, 0, 10, 2, 1, math.pi / 2)).toBe(false)
	end)

	it("bar: above the bar is safe", function()
		expect(HazardLogic.inBar(2, 6, 0, 0, 0, 0, 10, 2, 1, 0)).toBe(false)
	end)
end)

return nil
