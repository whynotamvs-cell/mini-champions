--!strict
-- Shared minigame lifecycle: one active run per player (docs/ARCHITECTURE.md 5).
-- The MVP has a single minigame, Desk Dash.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Validators = require(ReplicatedStorage.Shared.Net.Validators)
local Net = require(script.Parent.Parent.Net)
local ObstacleDash = require(script.Parent.Minigames.ObstacleDash)

local MinigameService = {}

MinigameService.ObstacleDash = ObstacleDash

function MinigameService:Init()
	ObstacleDash:Init()
	Net.onServerEvent("RequestRestart", {
		rate = { count = 1, per = 1 },
		validate = Validators.none,
	}, function(player: Player)
		ObstacleDash:Restart(player)
	end)
end

function MinigameService:Start()
	ObstacleDash:Start()
end

function MinigameService:GetActiveRun(player: Player): any
	return ObstacleDash:GetRun(player)
end

return MinigameService
