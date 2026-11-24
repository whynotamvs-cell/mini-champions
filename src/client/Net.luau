--!strict
-- Client networking: looks up remotes created by the server. Never creates remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local WAIT_TIMEOUT_SEC = 30

local Net = {}

local folder: Instance? = nil

local function getRemote(name: string): Instance
	assert(Remotes.Definitions[name], `Net: unknown remote "{name}"`)
	if folder == nil then
		folder = ReplicatedStorage:WaitForChild(Remotes.FolderName, WAIT_TIMEOUT_SEC)
	end
	assert(folder, "Net: Remotes folder not found (server did not start?)")
	local remote = folder:WaitForChild(name, WAIT_TIMEOUT_SEC)
	assert(remote, `Net: remote "{name}" not found`)
	return remote
end

function Net.fireServer(name: string, ...: any)
	local remote = getRemote(name) :: RemoteEvent
	remote:FireServer(...)
end

function Net.invokeServer(name: string, ...: any): any
	local remote = getRemote(name) :: RemoteFunction
	return remote:InvokeServer(...)
end

function Net.onClientEvent(name: string, handler: (...any) -> ()): RBXScriptConnection
	local remote = getRemote(name) :: RemoteEvent
	return remote.OnClientEvent:Connect(handler)
end

return Net
