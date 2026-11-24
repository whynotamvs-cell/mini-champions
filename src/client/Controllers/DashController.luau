--!strict
-- Receives Desk Dash events from the server. Display only: the client never decides
-- anything about a run. The timer is drawn from the server start time (ARCHITECTURE.md 8.3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Net = require(script.Parent.Parent.Net)

export type DashEvent = { kind: string, [string]: any }

local DashController = {}

-- Fired for every server DashEvent. Subscribe in Init(); handlers must not yield.
DashController.Event = Signal.new() :: Signal.Signal<DashEvent>

local startMs: number? = nil

function DashController:Init() end

function DashController:Start()
	Net.onClientEvent("DashEvent", function(event: DashEvent)
		if event.kind == "start" then
			startMs = event.startMs
		elseif event.kind == "finish" or event.kind == "abandon" or event.kind == "cancel" then
			startMs = nil
		end
		DashController.Event:Fire(event)
	end)
end

-- Elapsed run time in ms for the on-screen timer, or nil when not running.
function DashController:GetElapsedMs(): number?
	if startMs == nil then
		return nil
	end
	return math.max(0, math.floor(Workspace:GetServerTimeNow() * 1000) - startMs)
end

function DashController:RequestRestart()
	Net.fireServer("RequestRestart")
end

return DashController
