--!strict
-- Which tutorial hint to show for a saved Tutorial.Step (docs/ARCHITECTURE.md 5). Pure and
-- display-only: the server decides when a step is done, the client just reads the snapshot.
--   Step = last completed step: 0 nothing yet ... 4 bought the first upgrade, 5 complete.
-- Hint n of 5 is shown while Step == n - 1; steps 4 and 5 finish together on the first purchase.

export type Target = "StartPad" | "FinishPad" | "ClubButton" | "BuyButton"

export type Hint = {
	number: number, -- 1..TOTAL, shown as "Step n/TOTAL"
	total: number,
	key: string, -- localization key of the hint text
	target: Target, -- what the client highlights
}

local TOTAL = 5

local HINTS: { Hint } = {
	{ number = 1, total = TOTAL, key = "Tutorial.GoToStart", target = "StartPad" },
	{ number = 2, total = TOTAL, key = "Tutorial.RunTrack", target = "FinishPad" },
	{ number = 3, total = TOTAL, key = "Tutorial.OpenClub", target = "ClubButton" },
	{ number = 4, total = TOTAL, key = "Tutorial.PressBuild", target = "BuyButton" },
}

local TutorialHints = {}

TutorialHints.Total = TOTAL

-- The hint for the player's progress, or nil when the tutorial is over (or the data is odd).
function TutorialHints.forProgress(step: number, completed: boolean): Hint?
	if completed or step ~= step or step < 0 then
		return nil
	end
	return HINTS[math.floor(step) + 1]
end

return TutorialHints
