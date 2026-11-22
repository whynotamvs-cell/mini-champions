--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Emotes = require(ReplicatedStorage.Shared.Config.Emotes)
local Validators = require(ReplicatedStorage.Shared.Net.Validators)

describe("Config.Emotes", function()
	it("has the six preset emotes with unique IDs and keys", function()
		expect(#Emotes.Items).toBe(6)
		local ids: { [string]: boolean } = {}
		local keys: { [string]: boolean } = {}
		for _, item in Emotes.Items do
			expect(ids[item.Id]).toBe(nil)
			expect(keys[item.Key]).toBe(nil)
			ids[item.Id] = true
			keys[item.Key] = true
			expect(#item.Id <= 32).toBe(true)
		end
	end)
end)

describe("SendEmote validation (TEST_PLAN X-04)", function()
	local validate = Validators.tuple(Validators.enumString(Emotes.Ids))

	it("accepts every preset ID", function()
		for _, id in Emotes.Ids do
			expect((validate(1, id))).toBe(true)
		end
	end)

	it("rejects unknown IDs, long strings, tables, numbers and missing or extra arguments", function()
		for _, bad in { "dance", "", ("x"):rep(300), {}, 5, true } :: { any } do
			expect((validate(1, bad))).toBe(false)
		end
		expect((validate(0))).toBe(false)
		expect((validate(2, "wave", "wave"))).toBe(false)
	end)
end)
