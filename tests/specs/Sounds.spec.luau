--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)

describe("Config.Sounds", function()
	it("has a sprite with every cue for every track", function()
		for _, trackId in Tracks.Order do
			local sprite = (Sounds.Tracks :: any)[trackId]
			expect(sprite ~= nil).toBe(true)
			for _, name in Sounds.CueNames do
				expect(sprite.cues[name] ~= nil).toBe(true)
			end
		end
	end)

	it("asset ids are either empty (silent) or a rbxassetid:// id", function()
		for _, trackId in Tracks.Order do
			local asset = (Sounds.Tracks :: any)[trackId].asset
			expect(asset == "" or string.match(asset, "^rbxassetid://%d+$") ~= nil).toBe(true)
		end
	end)

	it("keeps every cue inside the sprite and cues from overlapping", function()
		for _, trackId in Tracks.Order do
			local cues = (Sounds.Tracks :: any)[trackId].cues
			local ordered = {}
			for _, name in Sounds.CueNames do
				table.insert(ordered, cues[name])
			end
			table.sort(ordered, function(a, b)
				return a.start < b.start
			end)
			for i, c in ordered do
				expect(c.start >= 0 and c.length > 0.05 and c.volume > 0 and c.volume <= 4).toBe(true)
				expect(c.start + c.length <= Sounds.SpriteSeconds).toBe(true)
				local nextCue = ordered[i + 1]
				if nextCue then
					expect(c.start + c.length <= nextCue.start + 1e-6).toBe(true)
				end
			end
		end
	end)

	it("both tracks share the same cue layout (one generator slot table)", function()
		local desk = (Sounds.Tracks :: any).desk.cues
		local keys = (Sounds.Tracks :: any).keys.cues
		for _, name in Sounds.CueNames do
			expect(desk[name].start).toBe(keys[name].start)
			expect(desk[name].length).toBe(keys[name].length)
		end
	end)
end)

return nil
