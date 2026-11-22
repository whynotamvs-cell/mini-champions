--!strict
-- Tutorial steps (Tutorial.Step = last completed step, 0..5). The numbering is final for the MVP
-- so stage 2 can fill in the UI for steps 3 without a data migration.
--   1 ReachedDashStart  2 FinishedFirstRun (+bonus)  3 OpenedClubMenu
--   4 BoughtFirstUpgrade  5 Complete (+bonus)
-- Step 3 is acknowledged by the client (TutorialAck) when the club menu opens; steps 4 and 5
-- are passed together by the first purchase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local RewardLogic = require(script.Parent.RewardLogic)

local TutorialLogic = {}

TutorialLogic.Steps = table.freeze({
	ReachedDashStart = 1,
	FinishedFirstRun = 2,
	OpenedClubMenu = 3,
	BoughtFirstUpgrade = 4,
	Complete = 5,
})

-- Moves the tutorial forward to `step` (never backwards). Returns true if it moved.
function TutorialLogic.advance(data: any, step: number): boolean
	if data.Tutorial.Completed or data.Tutorial.Step >= step then
		return false
	end
	data.Tutorial.Step = step
	if step >= TutorialLogic.Steps.Complete then
		data.Tutorial.Completed = true
	end
	return true
end

-- Client "I opened the club menu" (TutorialAck): counts only right after the first finish, so
-- a client can neither skip ahead nor replay a step.
function TutorialLogic.ackOpenedClub(data: any): boolean
	if data.Tutorial.Step ~= TutorialLogic.Steps.FinishedFirstRun then
		return false
	end
	return TutorialLogic.advance(data, TutorialLogic.Steps.OpenedClubMenu)
end

function TutorialLogic.firstFinishGrant(): RewardLogic.Grant
	local t = Economy.Tutorial
	return {
		source = "Tutorial",
		grantId = "tutorial:first_finish",
		lines = { { sku = "tutorial_first_finish", stars = t.FirstFinishStars } },
		xp = t.FirstFinishXP,
	}
end

function TutorialLogic.completeGrant(): RewardLogic.Grant
	local t = Economy.Tutorial
	return {
		source = "Tutorial",
		grantId = "tutorial:complete",
		lines = { { sku = "tutorial_complete", stars = t.CompleteStars } },
		xp = t.CompleteXP,
	}
end

-- Guards: the permanent Tutorial.Step flag is the main protection, RecentGrants the backup.
function TutorialLogic.firstFinishGuard(data: any): boolean
	return TutorialLogic.advance(data, TutorialLogic.Steps.FinishedFirstRun)
end

function TutorialLogic.completeGuard(data: any): boolean
	return TutorialLogic.advance(data, TutorialLogic.Steps.Complete)
end

return TutorialLogic
