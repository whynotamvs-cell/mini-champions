--!strict
-- Tutorial: steps advance only from server events or the one validated client ack
-- (docs/ARCHITECTURE.md 5); the client draws the hint for the saved step (Shared/Utilities/
-- TutorialHints). Toasts only announce bonuses. Onboarding funnel steps (ARCHITECTURE.md 12.1)
-- are logged from here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Validators = require(ReplicatedStorage.Shared.Net.Validators)
local Net = require(script.Parent.Parent.Net)
local ClubService = require(script.Parent.ClubService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RewardService = require(script.Parent.RewardService)
local TelemetryService = require(script.Parent.TelemetryService)
local ObstacleDash = require(script.Parent.Minigames.ObstacleDash)
local TutorialLogic = require(script.Parent.Logic.TutorialLogic)

local Steps = TutorialLogic.Steps

local TutorialService = {}

local function notify(player: Player, key: string, args: { [string]: any }?)
	Net.fireClient("Notify", player, key, args)
end

local function step(player: Player): number?
	local data = PlayerDataService:Get(player)
	return data and data.Tutorial.Step
end

function TutorialService:Init()
	PlayerDataService.Loaded:Connect(function(player, data)
		if data.Meta.SessionCount == 1 and data.Tutorial.Step == 0 then
			TelemetryService:Onboarding(player, 1, "Joined")
		end
		-- The current hint is drawn by the client from Tutorial.Step in its snapshot, so a
		-- player who rejoins mid-tutorial continues from the last completed step (TEST_PLAN F-04).
	end)

	-- Step 3: the client says the club menu was opened. Only valid right after the first finish.
	Net.onServerEvent("TutorialAck", {
		rate = { count = 2, per = 1 },
		validate = Validators.tuple(Validators.integer(Steps.OpenedClubMenu, Steps.OpenedClubMenu)),
	}, function(player: Player, _step: number)
		local committed = PlayerDataService:Update(player, function(data): boolean?
			return TutorialLogic.ackOpenedClub(data)
		end)
		if committed then
			TelemetryService:Onboarding(player, 6, "OpenedClubMenu")
		end
	end)

	ObstacleDash.EnteredStart:Connect(function(player)
		local committed = PlayerDataService:Update(player, function(data): boolean?
			return TutorialLogic.advance(data, Steps.ReachedDashStart)
		end)
		if committed then
			TelemetryService:Onboarding(player, 2, "ReachedDashStart")
		end
	end)

	-- Funnel steps 3 and 4 sit inside tutorial step 1; they can repeat if the first run is abandoned.
	ObstacleDash.RunStarted:Connect(function(player)
		if step(player) == Steps.ReachedDashStart then
			TelemetryService:Onboarding(player, 3, "StartedFirstRun")
		end
	end)
	ObstacleDash.CheckpointReached:Connect(function(player, index)
		if index == 2 and step(player) == Steps.ReachedDashStart then
			TelemetryService:Onboarding(player, 4, "ReachedCheckpoint2")
		end
	end)

	ObstacleDash.Finished:Connect(function(player, _info)
		local grant = TutorialLogic.firstFinishGrant()
		local result = RewardService:Grant(player, grant, TutorialLogic.firstFinishGuard, true)
		if result then
			TelemetryService:Onboarding(player, 5, "FinishedFirstRun")
			notify(player, "Tutorial.FinishBonus", { stars = Economy.Tutorial.FirstFinishStars })
		end
	end)

	ClubService.Purchased:Connect(function(player, index)
		if index ~= 1 then
			return
		end
		local before = step(player) or 0
		local result = RewardService:Grant(player, TutorialLogic.completeGrant(), TutorialLogic.completeGuard, true)
		if result then
			if before < Steps.OpenedClubMenu then
				-- The ack never arrived (e.g. the menu was opened before the first finish): log the step now.
				TelemetryService:Onboarding(player, 6, "OpenedClubMenu")
			end
			TelemetryService:Onboarding(player, 7, "BoughtFirstUpgrade")
			TelemetryService:Onboarding(player, 8, "TutorialComplete")
			notify(player, "Tutorial.Complete")
			notify(player, "Track.Unlocked") -- the second track opens with the end of the tutorial
		end
	end)
end

function TutorialService:Start() end

return TutorialService
