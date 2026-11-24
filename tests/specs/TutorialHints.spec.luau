--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)
local TutorialHints = require(ReplicatedStorage.Shared.Utilities.TutorialHints)
local Services = ServerScriptService.Server.Services
local Template = require(Services.PlayerData.Template)
local TutorialLogic = require(Services.Logic.TutorialLogic)

local Steps = TutorialLogic.Steps

describe("TutorialHints.forProgress", function()
	it("shows steps 1..4 in order for saved steps 0..3, each with its own target", function()
		local expected = { "StartPad", "FinishPad", "ClubButton", "BuyButton" }
		for saved = 0, 3 do
			local hint = TutorialHints.forProgress(saved, false)
			expect(hint ~= nil).toBe(true)
			expect((hint :: any).number).toBe(saved + 1)
			expect((hint :: any).total).toBe(5)
			expect((hint :: any).target).toBe(expected[saved + 1])
		end
	end)

	it("shows nothing once the tutorial is complete or the step is past the hints", function()
		expect(TutorialHints.forProgress(5, true)).toBe(nil)
		expect(TutorialHints.forProgress(2, true)).toBe(nil)
		expect(TutorialHints.forProgress(4, false)).toBe(nil)
	end)

	it("survives odd data without erroring", function()
		expect(TutorialHints.forProgress(-1, false)).toBe(nil)
		expect(TutorialHints.forProgress(0 / 0, false)).toBe(nil)
		expect(TutorialHints.forProgress(99, false)).toBe(nil)
	end)
end)

describe("TutorialLogic.ackOpenedClub (step 3)", function()
	it("counts only right after the first finish", function()
		local data = TableUtil.deepCopy(Template)
		expect(TutorialLogic.ackOpenedClub(data)).toBe(false) -- step 0: cannot skip ahead
		TutorialLogic.advance(data, Steps.ReachedDashStart)
		expect(TutorialLogic.ackOpenedClub(data)).toBe(false) -- step 1: still not finished
		TutorialLogic.advance(data, Steps.FinishedFirstRun)
		expect(TutorialLogic.ackOpenedClub(data)).toBe(true)
		expect(data.Tutorial.Step).toBe(Steps.OpenedClubMenu)
	end)

	it("cannot be replayed and never moves a completed tutorial", function()
		local data = TableUtil.deepCopy(Template)
		TutorialLogic.advance(data, Steps.FinishedFirstRun)
		expect(TutorialLogic.ackOpenedClub(data)).toBe(true)
		expect(TutorialLogic.ackOpenedClub(data)).toBe(false)
		TutorialLogic.advance(data, Steps.Complete)
		expect(TutorialLogic.ackOpenedClub(data)).toBe(false)
		expect(data.Tutorial.Step).toBe(Steps.Complete)
	end)

	it("the first purchase still completes the tutorial from step 3", function()
		local data = TableUtil.deepCopy(Template)
		TutorialLogic.advance(data, Steps.FinishedFirstRun)
		TutorialLogic.ackOpenedClub(data)
		expect(TutorialLogic.completeGuard(data)).toBe(true)
		expect(data.Tutorial.Completed).toBe(true)
	end)
end)
