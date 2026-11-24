--!strict
-- Results board at the finish (docs/ARCHITECTURE.md 8): best valid finish per player on this
-- server, fastest first. Only finishes the server already validated and rewarded reach it
-- (ObstacleDash.Finished). Clients only draw what they receive; nothing here is saved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Validators = require(ReplicatedStorage.Shared.Net.Validators)

local Net = require(script.Parent.Parent.Net)
local BoardLogic = require(script.Parent.Logic.BoardLogic)
local ObstacleDash = require(script.Parent.Minigames.ObstacleDash)

local BoardService = {}

local entries: { BoardLogic.Entry } = {}

function BoardService:Init()
	ObstacleDash.Finished:Connect(function(player: Player, info)
		if BoardLogic.record(entries, player.UserId, player.DisplayName, info.timeMs, info.medal) then
			Net.fireAllClients("BoardUpdate", BoardLogic.snapshot(entries))
		end
	end)

	-- A client asks once its listener exists (joins after the board already has rows).
	Net.onServerEvent("RequestBoard", {
		rate = { count = 1, per = 1 },
		validate = Validators.none,
		requireReady = false,
	}, function(player: Player)
		Net.fireClient("BoardUpdate", player, BoardLogic.snapshot(entries))
	end)
end

function BoardService:Start() end

return BoardService
