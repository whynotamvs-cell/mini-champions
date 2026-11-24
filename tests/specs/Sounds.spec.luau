--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)

local CUE_NAMES = { "tick", "go", "jump", "land", "checkpoint", "fall", "rejected" }

local function eachStep(cues: any, visit: (step: Sounds.Step, where: string) -> ())
	for _, name in CUE_NAMES do
		for _, step in cues[name] do
			visit(step, name)
		end
	end
	for medal, steps in cues.finish do
		for _, step in steps do
			visit(step, `finish.{medal}`)
		end
	end
end

describe("Config.Sounds", function()
	it("has a full cue set for every track", function()
		for _, trackId in Tracks.Order do
			local cues = (Sounds.Tracks :: any)[trackId]
			expect(cues ~= nil).toBe(true)
			for _, name in CUE_NAMES do
				expect(#cues[name] > 0).toBe(true)
			end
			for _, medal in { "Gold", "Silver", "Bronze" } do
				expect(#cues.finish[medal] > 0).toBe(true)
			end
		end
	end)

	it("only uses built-in sounds that were verified to load", function()
		for _, trackId in Tracks.Order do
			eachStep((Sounds.Tracks :: any)[trackId], function(step, where)
				expect(Sounds.Verified[step.id] ~= nil).toBe(true)
				expect(string.sub(step.id, 1, 18)).toBe("rbxasset://sounds/")
				expect(where ~= "").toBe(true)
			end)
		end
	end)

	it("keeps speeds, volumes and delays in sane ranges", function()
		for _, trackId in Tracks.Order do
			eachStep((Sounds.Tracks :: any)[trackId], function(step)
				expect(step.speed >= 0.5 and step.speed <= 2.5).toBe(true)
				expect(step.volume > 0 and step.volume <= 1).toBe(true)
				expect(step.delay >= 0 and step.delay <= 2).toBe(true)
			end)
		end
	end)

	it("makes the two tracks sound different (jump and checkpoint)", function()
		local desk = (Sounds.Tracks :: any).desk
		local keys = (Sounds.Tracks :: any).keys
		expect(desk.jump[1].id ~= keys.jump[1].id or desk.jump[1].speed ~= keys.jump[1].speed).toBe(true)
		expect(desk.checkpoint[1].id ~= keys.checkpoint[1].id).toBe(true)
	end)
end)

return nil
