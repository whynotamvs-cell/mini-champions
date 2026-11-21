--!strict
-- Holds the latest data snapshot from the server. Display only: the server never reads it back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(script.Parent.Parent.Net)

type ClientSnapshot = PlayerDataTypes.ClientSnapshot

local DataController = {}

-- Fired with every new snapshot. Subscribe in Init(); handlers must not yield.
DataController.Changed = Signal.new() :: Signal.Signal<ClientSnapshot>

local current: ClientSnapshot? = nil

function DataController:Init() end

function DataController:Start()
	Net.onClientEvent("DataSnapshot", function(snapshot: ClientSnapshot)
		current = snapshot
		DataController.Changed:Fire(snapshot)
	end)
	-- Listener exists now; ask for the snapshot in case the server sent it before we listened.
	Net.fireServer("RequestSnapshot")
end

function DataController:Get(): ClientSnapshot?
	return current
end

return DataController
