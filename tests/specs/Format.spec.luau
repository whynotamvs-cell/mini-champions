--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Format = require(ReplicatedStorage.Shared.Utilities.Format)

describe("Format.time", function()
	it("formats minutes, seconds and tenths", function()
		expect(Format.time(62_345)).toBe("1:02.3")
		expect(Format.time(9_870)).toBe("0:09.8")
		expect(Format.time(0)).toBe("0:00.0")
		expect(Format.time(59_999)).toBe("0:59.9")
	end)

	it("never shows negative or NaN times", function()
		expect(Format.time(-5)).toBe("0:00.0")
		expect(Format.time(0 / 0)).toBe("0:00.0")
	end)
end)

describe("Format.integer", function()
	it("groups thousands with spaces", function()
		expect(Format.integer(0)).toBe("0")
		expect(Format.integer(999)).toBe("999")
		expect(Format.integer(1_000)).toBe("1 000")
		expect(Format.integer(1_000_000)).toBe("1 000 000")
		expect(Format.integer(3_950)).toBe("3 950")
	end)
end)

return nil
