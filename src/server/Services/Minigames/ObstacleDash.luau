--!strict
-- Desk Dash on the server (docs/ARCHITECTURE.md 8). The client never reports times,
-- checkpoints or finishes: everything is detected here from the replicated root part position.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Dash = require(ReplicatedStorage.Shared.Config.Dash)
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

type PlayerState = {
	run: DashRun.Run?,
	onStartPad: boolean,
	lastPos: Vector3?,
	teleportGraceUntil: number,
	returnAt: number?,
	lastMissingHintAt: number,
}

export type FinishInfo = {
	timeMs: number,
	medal: Medal,
	firstFinish: boolean,
}

local TELEPORT_GRACE_SEC = 0.5
local MISSING_HINT_COOLDOWN_SEC = 2

local ObstacleDash = {}

-- Signals for TutorialService and others. Handlers must not yield.
ObstacleDash.EnteredStart = Signal.new() :: Signal.Signal<Player>
ObstacleDash.RunStarted = Signal.new() :: Signal.Signal<Player>
ObstacleDash.CheckpointReached = Signal.new() :: Signal.Signal<Player, number>
ObstacleDash.Finished = Signal.new() :: Signal.Signal<Player, FinishInfo>

local startZone: Zone? = nil
local finishZone: Zone? = nil
local checkpointZones: { [number]: Zone } = {}
local spawns: { [number]: BasePart } = {}
local returnPoint: BasePart? = nil
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
			lastMissingHintAt = 0,
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

local function send(player: Player, payload: { [string]: any })
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

local function teleportToCheckpoint(player: Player)
	local run = stateOf(player).run
	if run then
		teleport(player, spawns[run.lastCheckpoint] or spawns[0])
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
			TelemetryService:Progression(player, "Fail", reason)
		end
		if notify then
			send(player, { kind = "abandon", reason = reason })
		end
	end
	state.run = nil
end

local function startCountdown(player: Player)
	local state = stateOf(player)
	state.run = DashRun.new(HttpService:GenerateGUID(false), nowMs())
	send(player, { kind = "countdown", seconds = Dash.CountdownSec })
	ObstacleDash.EnteredStart:Fire(player)
end

local function reward(player: Player, run: DashRun.Run)
	if not DashRun.markRewarded(run) then
		return
	end
	local timeMs = run.timeMs :: number
	local medal: Medal = DashRewards.medalForTime(timeMs)

	local before = PlayerDataService:Get(player)
	local firstFinish = before ~= nil and before.Minigames.DeskDash.Finishes == 0

	local recordGuard, isNewBest = DashRewards.recordFinishGuard(timeMs)
	local starsTotal = 0
	local runResult = RewardService:Grant(player, DashRewards.runGrant(run.runId, medal), recordGuard)
	if runResult then
		starsTotal += runResult.starsAdded + runResult.levelUpStars
	end

	local firstMedals: { Medal } = {}
	for _, first in DashRewards.firstMedalGrants(medal) do
		local result = RewardService:Grant(player, first.grant, DashRewards.firstMedalGuard(first.medal), true)
		if result then
			starsTotal += result.starsAdded + result.levelUpStars
			table.insert(firstMedals, first.medal)
		end
	end

	TelemetryService:Progression(player, "Complete")
	TelemetryService:Custom(player, "DashFinishTimeSec", timeMs / 1000)
	TelemetryService:Custom(player, "DashMedal", if medal == "Gold" then 3 elseif medal == "Silver" then 2 else 1)

	send(player, {
		kind = "finish",
		valid = true,
		timeMs = timeMs,
		medal = medal,
		stars = starsTotal,
		newBest = isNewBest(),
		firstMedals = firstMedals,
	})
	ObstacleDash.Finished:Fire(player, { timeMs = timeMs, medal = medal, firstFinish = firstFinish })
end

local function onCheckpoint(player: Player, index: number)
	local run = stateOf(player).run
	if run and DashRun.reachCheckpoint(run, index, nowMs()) then
		send(player, { kind = "checkpoint", index = index, total = Dash.CheckpointCount })
		ObstacleDash.CheckpointReached:Fire(player, index)
	end
end

local function onFinish(player: Player)
	local state = stateOf(player)
	local run = state.run
	if run == nil then
		return
	end
	local outcome = DashRun.reachFinish(run, nowMs())
	if outcome == "missing_checkpoint" then
		if os.clock() - state.lastMissingHintAt > MISSING_HINT_COOLDOWN_SEC then
			state.lastMissingHintAt = os.clock()
			send(player, { kind = "missing_checkpoint", next = run.lastCheckpoint + 1 })
		end
		return
	elseif outcome == "rejected" then
		TelemetryService:Progression(player, "Fail", run.rejectReason)
		TelemetryService:Custom(player, "DashRejected", 1, { reason = run.rejectReason or "unknown" })
		warn(`[ObstacleDash] run rejected for {player.UserId}: {run.rejectReason}`)
		send(player, { kind = "finish", valid = false })
	elseif outcome == "valid" then
		reward(player, run)
	else
		return
	end
	state.run = nil
	state.returnAt = os.clock() + Dash.ReturnDelaySec
end

local function poll(player: Player, dtSec: number)
	local root = rootOf(player)
	if root == nil then
		return
	end
	local state = stateOf(player)
	local position = root.Position
	local onStart = inZone(position, startZone)
	local run = state.run

	if run == nil then
		if onStart and not state.onStartPad and PlayerDataService:IsReady(player) then
			startCountdown(player)
		end
	elseif run.state == "Countdown" then
		if not onStart then
			DashRun.leaveStart(run)
			state.run = nil
			send(player, { kind = "cancel" })
		elseif DashRun.tick(run, nowMs()) == "started" then
			send(player, { kind = "start", startMs = run.startMs })
			TelemetryService:Progression(player, "Start")
			ObstacleDash.RunStarted:Fire(player)
		end
	elseif run.state == "Running" then
		if DashRun.tick(run, nowMs()) == "timeout" then
			TelemetryService:Progression(player, "Fail", "timeout")
			send(player, { kind = "abandon", reason = "timeout" })
			state.run = nil
			teleport(player, returnPoint)
		else
			local last = state.lastPos
			if last and os.clock() > state.teleportGraceUntil then
				local dx, dz = position.X - last.X, position.Z - last.Z
				if math.sqrt(dx * dx + dz * dz) > DashRun.maxStep(dtSec) then
					DashRun.markSuspicious(run)
				end
			end
			if position.Y < Dash.FallResetY then
				teleportToCheckpoint(player)
				return
			end
			if Dash.CheckpointDetection == "Poll" then
				local nextZone = checkpointZones[run.lastCheckpoint + 1]
				if nextZone and inZone(position, nextZone) then
					onCheckpoint(player, run.lastCheckpoint + 1)
				end
				if inZone(position, finishZone) then
					onFinish(player)
				end
			end
		end
	end

	if state.returnAt and os.clock() >= state.returnAt then
		state.returnAt = nil
		teleport(player, returnPoint)
	end

	state.onStartPad = onStart
	state.lastPos = if os.clock() > state.teleportGraceUntil then root.Position else nil
end

local function collectZones(world: Instance)
	local track = world:WaitForChild("DeskDash")
	for _, zonePart in track:WaitForChild("Zones"):GetChildren() do
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
	for _, spawnPart in track:WaitForChild("Spawns"):GetChildren() do
		local index = tonumber(string.match(spawnPart.Name, "^Spawn(%d+)$"))
		if index and spawnPart:IsA("BasePart") then
			spawns[index] = spawnPart
		end
	end
	local point = world:FindFirstChild("ReturnPoint")
	returnPoint = if point and point:IsA("BasePart") then point else spawns[0]

	assert(startZone and finishZone, "[ObstacleDash] Start/Finish zones missing")
	for i = 1, Dash.CheckpointCount do
		assert(checkpointZones[i], `[ObstacleDash] Checkpoint{i} zone missing`)
		assert(spawns[i], `[ObstacleDash] Spawn{i} missing`)
	end
end

local function connectTouched()
	for _, zone in checkpointZones do
		zone.part.Touched:Connect(function(hit: BasePart)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				onCheckpoint(player, zone.index)
			end
		end)
	end
	local finish = finishZone :: Zone
	finish.part.Touched:Connect(function(hit: BasePart)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			local run = stateOf(player).run
			if run and run.state == "Running" then
				onFinish(player)
			end
		end
	end)
end

function ObstacleDash:Init() end

function ObstacleDash:Start()
	collectZones(Workspace:WaitForChild("DeskWorld"))
	print(`[ObstacleDash] ready, checkpoint detection: {Dash.CheckpointDetection}`)
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

	local function track(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
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

-- RequestRestart from the client: abandon the active run and go back to the hub.
function ObstacleDash:Restart(player: Player)
	local state = stateOf(player)
	if state.run and DashRun.isActive(state.run) then
		endRun(player, "restart", true)
		teleport(player, returnPoint)
	end
end

function ObstacleDash:GetRun(player: Player): DashRun.Run?
	local state = states[player]
	return state and state.run
end

return ObstacleDash
