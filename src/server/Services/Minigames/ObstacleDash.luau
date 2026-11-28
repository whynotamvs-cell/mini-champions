--!strict
-- Obstacle tracks on the server (docs/ARCHITECTURE.md 8): Desk Dash and Keyboard Dash share one
-- engine. The client never reports times, checkpoints or finishes: everything is detected here from
-- the replicated root part position. Each run belongs to one track (Config.Tracks).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Dash = require(ReplicatedStorage.Shared.Config.Dash)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local HazardLogic = require(ReplicatedStorage.Shared.Utilities.HazardLogic)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)

local Services = script.Parent.Parent
local Net = require(Services.Parent.Net)
local PlayerDataService = require(Services.PlayerDataService)
local RewardService = require(Services.RewardService)
local TelemetryService = require(Services.TelemetryService)
local DashRewards = require(script.Parent.DashRewards)
local DashRun = require(script.Parent.DashRun)

type Medal = PlayerDataTypes.Medal

type Zone = {
	kind: string,
	index: number,
	part: BasePart,
}

-- A timed obstacle (laser or spinner bar). Its parameters are attributes on the part; the part itself
-- is only visual and the hit test is evaluated here from the server time.
type Hazard = {
	kind: string,
	part: BasePart,
	period: number,
	onSec: number,
	phase: number,
	speed: number,
}

-- The world objects of one track, found by name under Workspace.DeskWorld.
type TrackWorld = {
	track: Tracks.Track,
	startZone: Zone,
	finishZone: Zone,
	checkpointZones: { [number]: Zone },
	spawns: { [number]: BasePart },
	returnPoint: BasePart?,
	hazards: { Hazard },
}

type PlayerState = {
	run: DashRun.Run?,
	onStartPad: boolean,
	lastPos: Vector3?,
	teleportGraceUntil: number,
	returnAt: number?,
	returnPoint: BasePart?,
	lastMissingHintAt: number,
	lastLockedHintAt: number,
}

export type FinishInfo = {
	timeMs: number,
	medal: Medal,
	firstFinish: boolean,
	trackId: string,
}

local TELEPORT_GRACE_SEC = 0.5
local MISSING_HINT_COOLDOWN_SEC = 2
local LOCKED_HINT_COOLDOWN_SEC = 4

local ObstacleDash = {}

-- Signals for TutorialService and others. Handlers must not yield.
ObstacleDash.EnteredStart = Signal.new() :: Signal.Signal<Player, string>
ObstacleDash.RunStarted = Signal.new() :: Signal.Signal<Player, string>
ObstacleDash.CheckpointReached = Signal.new() :: Signal.Signal<Player, number, string>
ObstacleDash.Finished = Signal.new() :: Signal.Signal<Player, FinishInfo>

local worlds: { [string]: TrackWorld } = {}
local states: { [Player]: PlayerState } = {}

local function nowMs(): number
	return math.floor(Workspace:GetServerTimeNow() * 1000)
end

local function stateOf(player: Player): PlayerState
	local state = states[player]
	if state == nil then
		state = {
			run = nil,
			onStartPad = false,
			lastPos = nil,
			teleportGraceUntil = 0,
			returnAt = nil,
			returnPoint = nil,
			lastMissingHintAt = 0,
			lastLockedHintAt = 0,
		}
		states[player] = state
	end
	return state
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function inZone(position: Vector3, zone: Zone?): boolean
	if zone == nil then
		return false
	end
	local p = zone.part
	local c, s = p.Position, p.Size
	return DashRun.inBox(position.X, position.Y, position.Z, c.X, c.Y, c.Z, s.X, s.Y, s.Z)
end

local function send(player: Player, trackId: string, payload: { [string]: any })
	payload.track = trackId
	Net.fireClient("DashEvent", player, payload)
end

local function teleport(player: Player, target: BasePart?)
	local character = player.Character
	if character == nil or target == nil then
		return
	end
	local state = stateOf(player)
	state.teleportGraceUntil = os.clock() + TELEPORT_GRACE_SEC
	state.lastPos = nil
	character:PivotTo(target.CFrame)
end

local function worldOf(run: DashRun.Run): TrackWorld
	return worlds[run.track.Id]
end

local function teleportToCheckpoint(player: Player)
	local run = stateOf(player).run
	if run then
		local world = worldOf(run)
		teleport(player, world.spawns[run.lastCheckpoint] or world.spawns[0])
	end
end

local function endRun(player: Player, reason: string, notify: boolean)
	local state = stateOf(player)
	local run = state.run
	if run == nil then
		return
	end
	local wasRunning = run.state == "Running"
	if DashRun.abandon(run, reason) then
		if wasRunning then
			TelemetryService:Progression(player, "Fail", reason, run.track.Progression)
		end
		if notify then
			send(player, run.track.Id, { kind = "abandon", reason = reason })
		end
	end
	state.run = nil
end

local function startCountdown(player: Player, track: Tracks.Track)
	local state = stateOf(player)
	state.run = DashRun.new(HttpService:GenerateGUID(false), nowMs(), track)
	send(player, track.Id, { kind = "countdown", seconds = Dash.CountdownSec })
	ObstacleDash.EnteredStart:Fire(player, track.Id)
end

local function reward(player: Player, run: DashRun.Run)
	if not DashRun.markRewarded(run) then
		return
	end
	local track = run.track
	local timeMs = run.timeMs :: number
	local medal: Medal = DashRewards.medalForTime(timeMs, track.Id)

	local before = PlayerDataService:Get(player)
	local record = before and (before.Minigames :: any)[track.DataKey]
	local firstFinish = record ~= nil and record.Finishes == 0

	local recordGuard, isNewBest = DashRewards.recordFinishGuard(timeMs, track)
	local starsTotal = 0
	local petId = if before and before.Pets.Equipped ~= "" then before.Pets.Equipped else nil
	local runResult = RewardService:Grant(player, DashRewards.runGrant(run.runId, medal, track, petId), recordGuard)
	if runResult then
		starsTotal += runResult.starsAdded + runResult.levelUpStars
	end

	local firstMedals: { Medal } = {}
	for _, first in DashRewards.firstMedalGrants(medal, track) do
		local result = RewardService:Grant(player, first.grant, DashRewards.firstMedalGuard(first.medal, track), true)
		if result then
			starsTotal += result.starsAdded + result.levelUpStars
			table.insert(firstMedals, first.medal)
		end
	end

	TelemetryService:Progression(player, "Complete", nil, track.Progression)
	TelemetryService:Custom(player, "DashFinishTimeSec", timeMs / 1000, { track = track.Id })
	TelemetryService:Custom(
		player,
		"DashMedal",
		if medal == "Gold" then 3 elseif medal == "Silver" then 2 else 1,
		{ track = track.Id }
	)

	send(player, track.Id, {
		kind = "finish",
		valid = true,
		timeMs = timeMs,
		medal = medal,
		stars = starsTotal,
		newBest = isNewBest(),
		firstMedals = firstMedals,
	})
	ObstacleDash.Finished:Fire(
		player,
		{ timeMs = timeMs, medal = medal, firstFinish = firstFinish, trackId = track.Id }
	)
end

local function onCheckpoint(player: Player, trackId: string, index: number)
	local run = stateOf(player).run
	if run and run.track.Id == trackId and DashRun.reachCheckpoint(run, index, nowMs()) then
		send(player, trackId, { kind = "checkpoint", index = index, total = run.track.CheckpointCount })
		ObstacleDash.CheckpointReached:Fire(player, index, trackId)
	end
end

local function onFinish(player: Player, trackId: string)
	local state = stateOf(player)
	local run = state.run
	if run == nil or run.track.Id ~= trackId then
		return
	end
	local outcome = DashRun.reachFinish(run, nowMs())
	if outcome == "missing_checkpoint" then
		if os.clock() - state.lastMissingHintAt > MISSING_HINT_COOLDOWN_SEC then
			state.lastMissingHintAt = os.clock()
			send(player, trackId, { kind = "missing_checkpoint", next = run.lastCheckpoint + 1 })
		end
		return
	elseif outcome == "rejected" then
		TelemetryService:Progression(player, "Fail", run.rejectReason, run.track.Progression)
		TelemetryService:Custom(player, "DashRejected", 1, { reason = run.rejectReason or "unknown", track = trackId })
		warn(`[ObstacleDash] run rejected for {player.UserId} on {trackId}: {run.rejectReason}`)
		send(player, trackId, { kind = "finish", valid = false })
	elseif outcome == "assisted" then
		TelemetryService:Progression(player, "Fail", "assisted", run.track.Progression)
		send(player, trackId, { kind = "finish", valid = false, assisted = true, timeMs = run.timeMs })
	elseif outcome == "valid" then
		reward(player, run)
	else
		return
	end
	state.run = nil
	state.returnAt = os.clock() + Dash.ReturnDelaySec
	state.returnPoint = worlds[trackId].returnPoint
end

-- The track whose start pad the position is standing on, if any.
local function startPadAt(position: Vector3): Tracks.Track?
	for _, trackId in Tracks.Order do
		local world = worlds[trackId]
		if world and inZone(position, world.startZone) then
			return world.track
		end
	end
	return nil
end

-- A locked track (needs the finished tutorial) never starts a run; the player is told why.
local function isUnlocked(player: Player, track: Tracks.Track): boolean
	if not track.RequiresTutorial then
		return true
	end
	local data = PlayerDataService:Get(player)
	return data ~= nil and data.Tutorial.Completed
end

local function hazardHits(world: TrackWorld, position: Vector3): boolean
	local t = Workspace:GetServerTimeNow()
	for _, hazard in world.hazards do
		local c, s = hazard.part.Position, hazard.part.Size
		if hazard.kind == "Laser" then
			if
				HazardLogic.laserOn(t, hazard.period, hazard.onSec, hazard.phase)
				and HazardLogic.inBox(position.X, position.Y, position.Z, c.X, c.Y, c.Z, s.X, s.Y, s.Z)
			then
				return true
			end
		elseif hazard.kind == "Spinner" then
			local angle = HazardLogic.spinnerAngle(t, hazard.speed, hazard.phase)
			if HazardLogic.inBar(position.X, position.Y, position.Z, c.X, c.Y, c.Z, s.X, s.Y, s.Z, angle) then
				return true
			end
		end
	end
	return false
end

local function poll(player: Player, dtSec: number)
	local root = rootOf(player)
	if root == nil then
		return
	end
	local state = stateOf(player)
	local position = root.Position
	local run = state.run
	local onStart: boolean

	if run == nil then
		local padTrack = startPadAt(position)
		onStart = padTrack ~= nil
		if padTrack and not state.onStartPad and PlayerDataService:IsReady(player) then
			if isUnlocked(player, padTrack) then
				startCountdown(player, padTrack)
			elseif os.clock() - state.lastLockedHintAt > LOCKED_HINT_COOLDOWN_SEC then
				state.lastLockedHintAt = os.clock()
				send(player, padTrack.Id, { kind = "locked" })
			end
		end
	else
		local world = worldOf(run)
		onStart = inZone(position, world.startZone)
		if run.state == "Countdown" then
			if not onStart then
				DashRun.leaveStart(run)
				state.run = nil
				send(player, run.track.Id, { kind = "cancel" })
			elseif DashRun.tick(run, nowMs()) == "started" then
				send(player, run.track.Id, { kind = "start", startMs = run.startMs })
				TelemetryService:Progression(player, "Start", nil, run.track.Progression)
				ObstacleDash.RunStarted:Fire(player, run.track.Id)
			end
		elseif run.state == "Running" then
			if DashRun.tick(run, nowMs()) == "timeout" then
				TelemetryService:Progression(player, "Fail", "timeout", run.track.Progression)
				send(player, run.track.Id, { kind = "abandon", reason = "timeout" })
				state.run = nil
				teleport(player, world.returnPoint)
			else
				local last = state.lastPos
				if last and os.clock() > state.teleportGraceUntil then
					local dx, dz = position.X - last.X, position.Z - last.Z
					if math.sqrt(dx * dx + dz * dz) > DashRun.maxStep(dtSec) then
						DashRun.markSuspicious(run)
					end
				end
				if position.Y < run.track.FallResetY then
					teleportToCheckpoint(player)
					return
				end
				if os.clock() > state.teleportGraceUntil and hazardHits(world, position) then
					teleportToCheckpoint(player)
					send(player, run.track.Id, { kind = "hazard" })
					return
				end
				if Dash.CheckpointDetection == "Poll" then
					local nextZone = world.checkpointZones[run.lastCheckpoint + 1]
					if nextZone and inZone(position, nextZone) then
						onCheckpoint(player, run.track.Id, run.lastCheckpoint + 1)
					end
					if inZone(position, world.finishZone) then
						onFinish(player, run.track.Id)
					end
				end
			end
		end
	end

	if state.returnAt and os.clock() >= state.returnAt then
		state.returnAt = nil
		teleport(player, state.returnPoint)
	end

	state.onStartPad = onStart
	state.lastPos = if os.clock() > state.teleportGraceUntil then root.Position else nil
end

-- Finds the zones and spawn points of one track under `deskWorld`. Returns nil (with a warning)
-- for a track whose model is missing, so an old place file still runs with the tracks it has.
local function collectTrack(deskWorld: Instance, track: Tracks.Track): TrackWorld?
	local model = deskWorld:WaitForChild(track.WorldName, 10)
	if model == nil then
		warn(`[ObstacleDash] track "{track.Id}": model "{track.WorldName}" not found, track disabled`)
		return nil
	end

	local startZone: Zone? = nil
	local finishZone: Zone? = nil
	local checkpointZones: { [number]: Zone } = {}
	for _, zonePart in model:WaitForChild("Zones"):GetChildren() do
		if zonePart:IsA("BasePart") then
			local kind = zonePart:GetAttribute("DashZone")
			local index = zonePart:GetAttribute("Index")
			if type(kind) == "string" and type(index) == "number" then
				local zone: Zone = { kind = kind, index = index, part = zonePart }
				if kind == "Start" then
					startZone = zone
				elseif kind == "Finish" then
					finishZone = zone
				elseif kind == "Checkpoint" then
					checkpointZones[index] = zone
				end
			end
		end
	end

	local spawns: { [number]: BasePart } = {}
	local spawnFolder = model:WaitForChild("Spawns")
	for _, spawnPart in spawnFolder:GetChildren() do
		local index = tonumber(string.match(spawnPart.Name, "^Spawn(%d+)$"))
		if index and spawnPart:IsA("BasePart") then
			spawns[index] = spawnPart
		end
	end
	-- Desk Dash keeps its ReturnPoint beside the track model; other tracks keep it in their Spawns.
	local point = spawnFolder:FindFirstChild("ReturnPoint") or deskWorld:FindFirstChild("ReturnPoint")
	local returnPoint = if point and point:IsA("BasePart") then point else spawns[0]

	local hazards: { Hazard } = {}
	local hazardFolder = model:FindFirstChild("Hazards")
	if hazardFolder then
		for _, hazardPart in hazardFolder:GetChildren() do
			local kind = hazardPart:GetAttribute("HazardKind")
			if hazardPart:IsA("BasePart") and (kind == "Laser" or kind == "Spinner") then
				table.insert(hazards, {
					kind = kind :: string,
					part = hazardPart,
					period = tonumber(hazardPart:GetAttribute("Period")) or 0,
					onSec = tonumber(hazardPart:GetAttribute("OnSec")) or 0,
					phase = tonumber(hazardPart:GetAttribute("Phase")) or 0,
					speed = tonumber(hazardPart:GetAttribute("Speed")) or 0,
				})
			end
		end
	end

	assert(startZone and finishZone, `[ObstacleDash] {track.Id}: Start/Finish zones missing`)
	for i = 1, track.CheckpointCount do
		assert(checkpointZones[i], `[ObstacleDash] {track.Id}: Checkpoint{i} zone missing`)
		assert(spawns[i], `[ObstacleDash] {track.Id}: Spawn{i} missing`)
	end
	return {
		track = track,
		startZone = startZone,
		finishZone = finishZone,
		checkpointZones = checkpointZones,
		spawns = spawns,
		returnPoint = returnPoint,
		hazards = hazards,
	}
end

local function connectTouched()
	for trackId, world in worlds do
		for _, zone in world.checkpointZones do
			zone.part.Touched:Connect(function(hit: BasePart)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					onCheckpoint(player, trackId, zone.index)
				end
			end)
		end
		world.finishZone.part.Touched:Connect(function(hit: BasePart)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				local run = stateOf(player).run
				if run and run.state == "Running" then
					onFinish(player, trackId)
				end
			end
		end)
	end
end

function ObstacleDash:Init() end

function ObstacleDash:Start()
	local deskWorld = Workspace:WaitForChild("DeskWorld")
	for _, trackId in Tracks.Order do
		local track = Tracks.ById[trackId]
		local world = collectTrack(deskWorld, track)
		if world then
			worlds[trackId] = world
		elseif trackId == Tracks.Default then
			error("[ObstacleDash] the default track is missing")
		end
	end
	local ready = {}
	for _, trackId in Tracks.Order do
		if worlds[trackId] then
			table.insert(ready, trackId)
		end
	end
	print(`[ObstacleDash] ready ({table.concat(ready, ", ")}), checkpoint detection: {Dash.CheckpointDetection}`)
	if Dash.CheckpointDetection == "Touched" then
		connectTouched()
	end

	local function onCharacterAdded(player: Player, character: Model)
		-- Decision D14: dying during a run returns the player to the last checkpoint.
		local state = stateOf(player)
		state.lastPos = nil
		state.teleportGraceUntil = os.clock() + TELEPORT_GRACE_SEC
		local run = state.run
		if run and run.state == "Running" then
			task.spawn(function()
				character:WaitForChild("HumanoidRootPart", 5)
				teleportToCheckpoint(player)
			end)
		end
	end

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		endRun(player, "left", false)
		states[player] = nil
	end)

	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulated += dt
		if accumulated < Dash.PollIntervalSec then
			return
		end
		local step = accumulated
		accumulated = 0
		for _, player in Players:GetPlayers() do
			poll(player, step)
		end
	end)
end

-- RequestRestart from the client: abandon the active run and go back to the track's start area.
function ObstacleDash:Restart(player: Player)
	local state = stateOf(player)
	local run = state.run
	if run and DashRun.isActive(run) then
		local returnPoint = worldOf(run).returnPoint
		endRun(player, "restart", true)
		teleport(player, returnPoint)
	end
end

-- A paid help was used (skip, spring boots): the run can still be finished but earns nothing.
function ObstacleDash:MarkAssisted(player: Player)
	local run = stateOf(player).run
	if run then
		DashRun.markAssisted(run)
	end
end

-- Moves a running player to the next checkpoint (or onto the finish pad after the last one) and
-- marks the run as assisted. Returns nil on success or a reason ("no_run", "not_running").
function ObstacleDash:SkipStage(player: Player): string?
	local run = stateOf(player).run
	if run == nil then
		return "no_run"
	end
	if run.state ~= "Running" then
		return "not_running"
	end
	local world = worldOf(run)
	DashRun.markAssisted(run)
	local nextIndex = run.lastCheckpoint + 1
	if nextIndex <= run.track.CheckpointCount then
		if DashRun.reachCheckpoint(run, nextIndex, nowMs()) then
			send(player, run.track.Id, { kind = "checkpoint", index = nextIndex, total = run.track.CheckpointCount })
		end
		teleport(player, world.spawns[nextIndex] or world.spawns[0])
	else
		-- Past the last checkpoint: stand on the finish pad; the normal finish detection takes over.
		local zone = world.finishZone.part
		local target = zone.CFrame * CFrame.new(0, -zone.Size.Y / 2 + 3, 0)
		local character = player.Character
		if character then
			stateOf(player).teleportGraceUntil = os.clock() + TELEPORT_GRACE_SEC
			stateOf(player).lastPos = nil
			character:PivotTo(target)
		end
	end
	return nil
end

function ObstacleDash:GetRun(player: Player): DashRun.Run?
	local state = states[player]
	return state and state.run
end

return ObstacleDash
