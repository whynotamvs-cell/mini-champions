--!strict
-- Server networking. Creates every remote from the manifest and wraps every handler with
-- rate limiting, argument validation and the profile-ready check (docs/ARCHITECTURE.md 6.2).
-- A rejected call is dropped silently and counted; no kicks in the MVP.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(Shared.Net.RateLimiter)
local Validators = require(Shared.Net.Validators)

export type HandlerOptions = {
	rate: { count: number, per: number },
	validate: Validators.TupleValidator,
	requireReady: boolean?,
}

local VIOLATION_REPORT_EVERY = 10

local Net = {}

local remotes: { [string]: Instance } = {}
local limiters: { RateLimiter.RateLimiter } = {}
local violations: { [Player]: number } = {}
local isReady: (Player) -> boolean = function(_player: Player)
	return false
end
local violationReporter: ((player: Player, remoteName: string, reason: string) -> ())? = nil

function Net.init()
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName
	local definitions: { [string]: Remotes.RemoteKind } = Remotes.Definitions :: any
	for name, kind in definitions do
		local remote: Instance = if kind == "Function"
			then Instance.new("RemoteFunction")
			else Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage

	Players.PlayerRemoving:Connect(function(player)
		violations[player] = nil
		for _, limiter in limiters do
			limiter:Forget(player)
		end
	end)
end

-- PlayerDataService registers its IsReady check here (avoids a require cycle).
function Net.setReadyCheck(check: (Player) -> boolean)
	isReady = check
end

-- TelemetryService registers a reporter for repeated violations.
function Net.setViolationReporter(reporter: (player: Player, remoteName: string, reason: string) -> ())
	violationReporter = reporter
end

local function getRemote(name: string): Instance
	local remote = remotes[name]
	assert(remote, `Net: unknown remote "{name}" (call Net.init() first and check Remotes.luau)`)
	return remote
end

local function recordViolation(player: Player, remoteName: string, reason: string)
	local count = (violations[player] or 0) + 1
	violations[player] = count
	if count == 1 or count % VIOLATION_REPORT_EVERY == 0 then
		warn(`[Net] {player.Name} ({player.UserId}) {remoteName}: {reason} (violations: {count})`)
		if violationReporter then
			violationReporter(player, remoteName, reason)
		end
	end
end

local function makeGuard(name: string, options: HandlerOptions): (player: Player, count: number, ...any) -> boolean
	local limiter = RateLimiter.new(options.rate.count, options.rate.per)
	table.insert(limiters, limiter)
	return function(player: Player, count: number, ...: any): boolean
		if not limiter:Allow(player) then
			recordViolation(player, name, "rate limit")
			return false
		end
		local ok, reason = options.validate(count, ...)
		if not ok then
			recordViolation(player, name, reason or "invalid arguments")
			return false
		end
		if options.requireReady ~= false and not isReady(player) then
			-- Not a violation: the profile may still be loading.
			return false
		end
		return true
	end
end

function Net.onServerEvent(name: string, options: HandlerOptions, handler: (Player, ...any) -> ())
	local remote = getRemote(name)
	assert(remote:IsA("RemoteEvent"), `Net: "{name}" is not a RemoteEvent`)
	local guard = makeGuard(name, options)
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if guard(player, select("#", ...), ...) then
			handler(player, ...)
		end
	end)
end

-- Handler result is returned to the client; nil when the call was rejected or the handler errored.
function Net.onServerInvoke(name: string, options: HandlerOptions, handler: (Player, ...any) -> any)
	local remote = getRemote(name)
	assert(remote:IsA("RemoteFunction"), `Net: "{name}" is not a RemoteFunction`)
	local guard = makeGuard(name, options)
	remote.OnServerInvoke = function(player: Player, ...: any): any
		if not guard(player, select("#", ...), ...) then
			return nil
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(`[Net] {name} handler error: {result}`)
			return nil
		end
		return result
	end
end

function Net.fireClient(name: string, player: Player, ...: any)
	local remote = getRemote(name) :: RemoteEvent
	remote:FireClient(player, ...)
end

function Net.fireAllClients(name: string, ...: any)
	local remote = getRemote(name) :: RemoteEvent
	remote:FireAllClients(...)
end

return Net
