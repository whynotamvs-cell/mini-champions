--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)
local PlayerData = ServerScriptService.Server.Services.PlayerData
local Template = require(PlayerData.Template)
local Validate = require(PlayerData.Validate)

local function fresh(): any
	return TableUtil.deepCopy(Template)
end

describe("Validate", function()
	it("finds no issues in the template and keeps valid data unchanged", function()
		local data = fresh()
		data.Stars = 500
		data.XP = 1234
		data.Club.UpgradesOwned = 3
		data.Minigames.DeskDash.BestTimeMs = 150_000
		data.RecentGrants = { "dash:abc", "medal:dash:gold" }
		local before = TableUtil.deepCopy(data)
		expect(#Validate.issues(data)).toBe(0)
		expect(#Validate.repair(data)).toBe(0)
		expect(data).toEqual(before)
	end)

	it("issues() reports problems without changing data", function()
		local data = fresh()
		data.Stars = -5
		local issues = Validate.issues(data)
		expect(#issues).toBeGreaterThan(0)
		expect(data.Stars).toBe(-5)
	end)

	it("clamps numbers into range (DATA_SCHEMA.md 9)", function()
		local data = fresh()
		data.Stars = -5
		data.Club.UpgradesOwned = 12
		data.Tutorial.Step = 9
		data.Settings.MusicVolume = 999
		Validate.repair(data)
		expect(data.Stars).toBe(0)
		expect(data.Club.UpgradesOwned).toBe(8)
		expect(data.Tutorial.Step).toBe(5)
		expect(data.Settings.MusicVolume).toBe(1)
	end)

	it("caps Stars at the max balance and floors fractions", function()
		local data = fresh()
		data.Stars = 5_000_000
		data.XP = 10.7
		Validate.repair(data)
		expect(data.Stars).toBe(1_000_000)
		expect(data.XP).toBe(10)
	end)

	it("fixes wrong types: string for a number, NaN, string for a table", function()
		local data = fresh()
		data.Stars = "lots"
		data.XP = 0 / 0
		data.Tutorial = "skip"
		data.Settings.Language = "xx"
		data.Settings.ReducedMotion = "yes"
		Validate.repair(data)
		expect(data.Stars).toBe(0)
		expect(data.XP).toBe(0)
		expect(data.Tutorial).toEqual(Template.Tutorial)
		expect(data.Settings.Language).toBe("auto")
		expect(data.Settings.ReducedMotion).toBe(false)
	end)

	it("drops an impossible best time (below the anti-cheat minimum)", function()
		local data = fresh()
		data.Minigames.DeskDash.BestTimeMs = 1_000
		Validate.repair(data)
		expect(data.Minigames.DeskDash.BestTimeMs).toBe(0)
	end)

	it("trims RecentGrants to 50 newest valid ids", function()
		local data = fresh()
		for i = 1, 60 do
			table.insert(data.RecentGrants, `g{i}`)
		end
		table.insert(data.RecentGrants, string.rep("x", 100))
		Validate.repair(data)
		expect(#data.RecentGrants).toBe(50)
		expect(data.RecentGrants[1]).toBe("g11")
		expect(data.RecentGrants[50]).toBe("g60")
	end)
end)

return nil
