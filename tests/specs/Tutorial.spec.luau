--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Formulas = require(ReplicatedStorage.Shared.Utilities.Formulas)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)
local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)
local Services = ServerScriptService.Server.Services
local Template = require(Services.PlayerData.Template)
local Validate = require(Services.PlayerData.Validate)
local RewardLogic = require(Services.Logic.RewardLogic)
local PurchaseLogic = require(Services.Logic.PurchaseLogic)
local TutorialLogic = require(Services.Logic.TutorialLogic)
local DashRewards = require(Services.Minigames.DashRewards)

local Steps = TutorialLogic.Steps

describe("TutorialLogic.advance", function()
	it("only moves forward and marks completion at step 5", function()
		local data = TableUtil.deepCopy(Template)
		expect(TutorialLogic.advance(data, Steps.ReachedDashStart)).toBe(true)
		expect(TutorialLogic.advance(data, Steps.ReachedDashStart)).toBe(false)
		expect(TutorialLogic.advance(data, Steps.Complete)).toBe(true)
		expect(data.Tutorial.Completed).toBe(true)
		expect(TutorialLogic.advance(data, Steps.Complete)).toBe(false)
	end)
end)

describe("Stage 1 vertical slice in pure logic (TEST_PLAN F-02)", function()
	-- Mirrors what ObstacleDash + TutorialService + ClubService do, in the same order.
	local function finishRun(data: any, runId: string, timeMs: number)
		local medal: PlayerDataTypes.Medal = Formulas.medalForTime(timeMs)
		local guard = DashRewards.recordFinishGuard(timeMs)
		RewardLogic.apply(data, DashRewards.runGrant(runId, medal), guard)
		for _, first in DashRewards.firstMedalGrants(medal) do
			RewardLogic.apply(data, first.grant, DashRewards.firstMedalGuard(first.medal))
		end
		RewardLogic.apply(data, TutorialLogic.firstFinishGrant(), TutorialLogic.firstFinishGuard)
	end

	it("join -> start -> Bronze finish = 100 Stars -> buy #1 -> tutorial done = 65 Stars, level 2", function()
		local data = TableUtil.deepCopy(Template)
		TutorialLogic.advance(data, Steps.ReachedDashStart)
		finishRun(data, "run-1", 200_000) -- Bronze
		expect(data.Stars).toBe(100)
		expect(data.Tutorial.Step).toBe(Steps.FinishedFirstRun)

		expect((PurchaseLogic.apply(data, 1))).toBe(true)
		RewardLogic.apply(data, TutorialLogic.completeGrant(), TutorialLogic.completeGuard)

		expect(data.Stars).toBe(65)
		expect(Formulas.levelFromXP(data.XP)).toBe(2)
		expect(data.Tutorial.Completed).toBe(true)
		expect(data.Club.UpgradesOwned).toBe(1)
		expect(#Validate.issues(data)).toBe(0)
	end)

	it("tutorial bonuses never pay twice, even after RecentGrants is cleared", function()
		local data = TableUtil.deepCopy(Template)
		finishRun(data, "run-1", 200_000)
		data.RecentGrants = {}
		finishRun(data, "run-2", 200_000)
		-- second run: 20 for the finish only (first Bronze and tutorial bonus are one-time)
		expect(data.Stars).toBe(120)
		RewardLogic.apply(data, TutorialLogic.completeGrant(), TutorialLogic.completeGuard)
		local after = data.Stars
		data.RecentGrants = {}
		RewardLogic.apply(data, TutorialLogic.completeGrant(), TutorialLogic.completeGuard)
		expect(data.Stars).toBe(after)
	end)
end)

return nil
