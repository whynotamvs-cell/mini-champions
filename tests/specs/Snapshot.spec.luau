--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)
local PlayerData = ServerScriptService.Server.Services.PlayerData
local Snapshot = require(PlayerData.Snapshot)
local Template = require(PlayerData.Template)

describe("Snapshot.build", function()
	it("derives level and club level and exposes only UI fields", function()
		local data = TableUtil.deepCopy(Template)
		data.Stars = 65
		data.XP = 85
		data.Club.UpgradesOwned = 1
		data.RecentGrants = { "secret-grant" }
		local s = Snapshot.build(data) :: any
		expect(s.Stars).toBe(65)
		expect(s.Level).toBe(2)
		expect(s.XPIntoLevel).toBe(10)
		expect(s.XPForNext).toBe(100)
		expect(s.ClubLevel).toBe(2)
		expect(s.RecentGrants).toBeNil()
		expect(s.Meta).toBeNil()
		expect(s.LifetimeStars).toBeNil()
	end)

	it("does not share tables with the profile", function()
		local data = TableUtil.deepCopy(Template)
		local s = Snapshot.build(data)
		s.Settings.MusicVolume = 0
		expect(data.Settings.MusicVolume).toBe(0.6)
	end)
end)

return nil
