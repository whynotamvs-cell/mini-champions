--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Music = require(ReplicatedStorage.Shared.Config.Music)

describe("Config.Music", function()
	it("asset is empty (silent) or a rbxassetid:// id", function()
		expect(Music.asset == "" or string.match(Music.asset, "^rbxassetid://%d+$") ~= nil).toBe(true)
	end)

	it("keeps the music quiet and the fade short", function()
		expect(Music.volume > 0 and Music.volume <= 0.7).toBe(true)
		expect(Music.fadeInSec >= 0 and Music.fadeInSec <= 10).toBe(true)
	end)
end)

return nil
