--!strict
-- The only owner of player data and the only module that requires ProfileStore
-- (docs/DATA_SCHEMA.md 2, 5; docs/ARCHITECTURE.md 5). Other services read with Get() and
-- write with Update(); nobody touches Profile.Data directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.Game)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local Signal = require(Shared.Utilities.Signal)
local TableUtil = require(Shared.Utilities.TableUtil)
local Validators = require(Shared.Net.Validators)

local Server = script.Parent.Parent
local Net = require(Server.Net)
local ServerText = require(Server.ServerText)
local ProfileStore = require(Server.Vendor.ProfileStore)
local TelemetryService = require(script.Parent.TelemetryService)

local Migrations = require(script.Parent.PlayerData.Migrations)
local Snapshot = require(script.Parent.PlayerData.Snapshot)
local Template = require(script.Parent.PlayerData.Template)
local Validate = require(script.Parent.PlayerData.Validate)

type PlayerData = PlayerDataTypes.PlayerData
type Profile = ProfileStore.Profile<PlayerData>

local STORE_NAME = "PlayerData_v1"
local SNAPSHOT_COALESCE_SEC = 0.2

local PlayerDataService = {}

-- Fired once per session when a player's profile is Ready. Handlers must not yield.
PlayerDataService.Loaded = Signal.new() :: Signal.Signal<Player, PlayerData>

local store: any = nil
local usingRealStore = false
local profiles: { [Player]: Profile } = {}
local ready: { [Player]: boolean } = {}
local snapshotPending: { [Player]: boolean } = {}

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

local function sendSnapshot(player: Player)
	local profile = profiles[player]
	if profile and ready[player] then
		Net.fireClient("DataSnapshot", player, Snapshot.build(profile.Data))
	end
end

local function scheduleSnapshot(player: Player)
	if snapshotPending[player] then
		return
	end
	snapshotPending[player] = true
	task.delay(SNAPSHOT_COALESCE_SEC, function()
		snapshotPending[player] = nil
		sendSnapshot(player)
	end)
end

-- Seconds before the client is told why (it needs time to start) and before the kick. The player
-- sees the reason on the loading screen first; the kick message is the fallback.
local LOAD_ERROR_NOTIFY_SEC = 1.5
local LOAD_ERROR_KICK_SEC = 5

-- Loading did not work out: no profile exists, so the player must not play. Tell them why, log
-- it (DataLoadFailed, one custom field with a reason from our own list) and kick.
local function failLoad(player: Player, key: string, reason: string)
	TelemetryService:Custom(player, "DataLoadFailed", 1, { reason = reason })
	task.delay(LOAD_ERROR_NOTIFY_SEC, function()
		if player.Parent == Players then
			Net.fireClient("Notify", player, key)
		end
	end)
	task.delay(LOAD_ERROR_KICK_SEC, function()
		ServerText.kick(player, key)
	end)
end

local function loadProfile(player: Player)
	if RunService:IsStudio() and GameConfig.Studio.SimulateLoadFailure then
		warn("[PlayerDataService] SimulateLoadFailure is on")
		failLoad(player, "Error.LoadFailed", "simulated")
		return
	end

	local profile: Profile? = store:StartSessionAsync(keyFor(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Either the player left during loading, or DataStore failed after retries.
		-- Never hand out an empty profile that could later overwrite the real one.
		if player.Parent == Players then
			warn(`[PlayerDataService] profile load failed for {player.UserId}`)
			failLoad(player, "Error.LoadFailed", "store")
		end
		return
	end

	-- ProfileStore.Mock ignores the Cancel callback, so re-check here.
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	local status, migrated, reason = Migrations.migrate(profile.Data)
	if status == "newer" then
		-- Older server code must not modify newer data (DATA_SCHEMA.md 8, rule 3).
		warn(`[PlayerDataService] {player.UserId}: {reason}`)
		profile:EndSession()
		failLoad(player, "Error.UpdateRequired", "newer")
		return
	elseif status == "error" then
		warn(`[PlayerDataService] {player.UserId}: migration error: {reason}`)
		profile:EndSession()
		failLoad(player, "Error.LoadFailed", "migration")
		return
	end
	profile.Data = migrated

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	local fixed = Validate.repair(profile.Data)
	if #fixed > 0 then
		warn(`[PlayerDataService] {player.UserId}: repaired data: {table.concat(fixed, "; ")}`)
	end

	profile.OnSessionEnd:Connect(function()
		local wasOurs = profiles[player] == profile
		profiles[player] = nil
		ready[player] = nil
		if wasOurs and player.Parent == Players then
			-- Another server took the session (DATA_SCHEMA.md 5).
			ServerText.kick(player, "Error.SessionElsewhere")
		end
	end)

	local now = os.time()
	local meta = profile.Data.Meta
	if meta.FirstJoinUnix == 0 then
		meta.FirstJoinUnix = now
	end
	meta.LastJoinUnix = now
	meta.SessionCount += 1

	profiles[player] = profile
	ready[player] = true

	PlayerDataService.Loaded:Fire(player, TableUtil.deepCopy(profile.Data))
	sendSnapshot(player)
end

local function releaseProfile(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	ready[player] = nil
	snapshotPending[player] = nil
	if profile then
		profile:EndSession()
	end
end

function PlayerDataService:Init()
	local profileStore = ProfileStore.New(STORE_NAME, Template)
	usingRealStore = not RunService:IsStudio()
		or (GameConfig.Studio.UseRealDataStore and game.PlaceId == GameConfig.TestPlaceId)
	store = if usingRealStore then profileStore else profileStore.Mock
	print(`[PlayerDataService] store: {if usingRealStore then "DataStore" else "ProfileStore.Mock"}`)

	Net.setReadyCheck(function(player: Player): boolean
		return ready[player] == true
	end)

	Net.onServerEvent("RequestSnapshot", {
		rate = { count = 1, per = 1 },
		validate = Validators.none,
	}, function(player: Player)
		sendSnapshot(player)
	end)
end

function PlayerDataService:Start()
	Players.PlayerAdded:Connect(loadProfile)
	Players.PlayerRemoving:Connect(releaseProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
end

function PlayerDataService:IsReady(player: Player): boolean
	return ready[player] == true
end

function PlayerDataService:IsUsingRealStore(): boolean
	return usingRealStore
end

-- Read-only copy of the player's data, or nil when not Ready.
function PlayerDataService:Get(player: Player): PlayerData?
	local profile = profiles[player]
	if profile == nil or not ready[player] then
		return nil
	end
	return TableUtil.deepCopy(profile.Data)
end

-- Applies `mutate` to a copy of the data. The copy replaces the real data only if `mutate`
-- does not error, does not return false, and the result passes validation. `mutate` must not yield.
-- Returns true when the change was committed.
function PlayerDataService:Update(player: Player, mutate: (data: PlayerData) -> boolean?): boolean
	local profile = profiles[player]
	if profile == nil or not ready[player] or not profile:IsActive() then
		return false
	end
	local copy = TableUtil.deepCopy(profile.Data)
	local ok, result = pcall(mutate, copy)
	if not ok then
		warn(`[PlayerDataService] update failed for {player.UserId}: {result}`)
		return false
	end
	if result == false then
		return false
	end
	local issues = Validate.issues(copy)
	if #issues > 0 then
		warn(`[PlayerDataService] update rejected for {player.UserId}: {table.concat(issues, "; ")}`)
		return false
	end
	profile.Data = copy
	scheduleSnapshot(player)
	return true
end

-- Immediate save for important events (decision D4).
function PlayerDataService:SaveNow(player: Player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

return PlayerDataService
