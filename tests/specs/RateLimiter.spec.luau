--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local RateLimiter = require(ReplicatedStorage.Shared.Net.RateLimiter)

describe("RateLimiter", function()
	local now = 0
	local function clock(): number
		return now
	end

	it("allows up to `count` calls at once and blocks the rest", function()
		now = 0
		local limiter = RateLimiter.new(2, 1, clock)
		expect(limiter:Allow("a")).toBe(true)
		expect(limiter:Allow("a")).toBe(true)
		expect(limiter:Allow("a")).toBe(false)
	end)

	it("refills over time", function()
		now = 0
		local limiter = RateLimiter.new(1, 2, clock)
		expect(limiter:Allow("a")).toBe(true)
		now = 1
		expect(limiter:Allow("a")).toBe(false)
		now = 2.01
		expect(limiter:Allow("a")).toBe(true)
	end)

	it("keeps keys independent and can forget a key", function()
		now = 0
		local limiter = RateLimiter.new(1, 10, clock)
		expect(limiter:Allow("a")).toBe(true)
		expect(limiter:Allow("b")).toBe(true)
		expect(limiter:Allow("a")).toBe(false)
		limiter:Forget("a")
		expect(limiter:Allow("a")).toBe(true)
	end)

	it("lets through at most `count` of 100 burst calls", function()
		now = 0
		local limiter = RateLimiter.new(2, 1, clock)
		local allowed = 0
		for _ = 1, 100 do
			if limiter:Allow("spam") then
				allowed += 1
			end
		end
		expect(allowed).toBe(2)
	end)
end)

return nil
