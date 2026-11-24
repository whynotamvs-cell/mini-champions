--!strict
-- Preset emotes (docs/ARCHITECTURE.md 7). The client sends only an emote ID from Config.Emotes;
-- the server checks the ID and the rate limit, then tells every client who emoted what.
-- No text from players ever reaches other players.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Emotes = require(ReplicatedStorage.Shared.Config.Emotes)
local Validators = require(ReplicatedStorage.Shared.Net.Validators)

local Net = require(script.Parent.Parent.Net)
local TelemetryService = require(script.Parent.TelemetryService)

local EmoteService = {}

function EmoteService:Init()
	Net.onServerEvent("SendEmote", {
		-- One emote per CooldownSec per player (TEST_PLAN X-05).
		rate = { count = 1, per = Emotes.CooldownSec },
		validate = Validators.tuple(Validators.enumString(Emotes.Ids)),
	}, function(player: Player, emoteId: string)
		Net.fireAllClients("EmoteShown", player.UserId, emoteId)
		TelemetryService:Custom(player, "EmoteUsed", 1, { emote = emoteId })
	end)
end

function EmoteService:Start() end

return EmoteService
