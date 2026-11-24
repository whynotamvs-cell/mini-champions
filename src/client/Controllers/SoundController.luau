--!strict
-- Obstacle track sounds: countdown ticks, GO, jump and landing during a run, checkpoint chime, fall,
-- and the finish jingle by medal. Each track has its own set (Config.Sounds): Desk Dash is wooden
-- and papery, Keyboard Dash is clicky and electronic. Driven only by server DashEvents and the
-- local character's own jump/landing; all sounds go through the "Sfx" SoundGroup so the volume
-- setting applies.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local DashController = require(script.Parent.DashController)

local SoundController = {}

local MIN_GAP_SEC = 0.09 -- jump/landing sounds never stack tighter than this

local activeTrack: string? = nil
local countdownToken = 0
local fallen = false
local lastPlayed: { [string]: number } = {}

local function sfxGroup(): SoundGroup
	local existing = SoundService:FindFirstChild("Sfx")
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = "Sfx"
	group.Parent = SoundService
	return group
end

local function playStep(step: Sounds.Step)
	local function fire()
		local sound = Instance.new("Sound")
		sound.SoundId = step.id
		sound.PlaybackSpeed = step.speed
		sound.Volume = step.volume
		sound.SoundGroup = sfxGroup()
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
		Debris:AddItem(sound, 4) -- fallback if Ended never fires
	end
	if step.delay > 0 then
		task.delay(step.delay, fire)
	else
		fire()
	end
end

local function playCue(steps: { Sounds.Step }, throttleKey: string?)
	if throttleKey then
		local now = os.clock()
		if now - (lastPlayed[throttleKey] or 0) < MIN_GAP_SEC then
			return
		end
		lastPlayed[throttleKey] = now
	end
	for _, step in steps do
		playStep(step)
	end
end

local function cuesOf(trackId: any): Sounds.Cues?
	if type(trackId) ~= "string" then
		return nil
	end
	return (Sounds.Tracks :: any)[trackId]
end

local function onDashEvent(event: DashController.DashEvent)
	local trackId = event.track
	local cues = cuesOf(trackId)
	if cues == nil then
		return
	end
	local kind = event.kind
	if kind == "countdown" then
		countdownToken += 1
		local token = countdownToken
		local seconds = if type(event.seconds) == "number" then event.seconds else 3
		for i = 0, seconds - 1 do
			task.delay(i, function()
				if token == countdownToken then
					playCue(cues.tick)
				end
			end)
		end
	elseif kind == "start" then
		countdownToken += 1
		activeTrack = trackId
		fallen = false
		playCue(cues.go)
	elseif kind == "checkpoint" then
		playCue(cues.checkpoint)
	elseif kind == "finish" then
		activeTrack = nil
		if event.valid == true then
			local medal = if event.medal == "Gold" or event.medal == "Silver" then event.medal else "Bronze"
			playCue((cues.finish :: any)[medal])
		else
			playCue(cues.rejected)
		end
	elseif kind == "cancel" or kind == "abandon" then
		countdownToken += 1
		activeTrack = nil
	end
end

local function hookCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.StateChanged:Connect(function(_old, new)
		local trackId = activeTrack
		local cues = cuesOf(trackId)
		if trackId == nil or cues == nil then
			return
		end
		if new == Enum.HumanoidStateType.Jumping then
			playCue(cues.jump, "jump")
		elseif new == Enum.HumanoidStateType.Landed then
			playCue(cues.land, "land")
		end
	end)
end

function SoundController:Init()
	DashController.Event:Connect(onDashEvent)
end

function SoundController:Start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(hookCharacter)
	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end

	-- A fall below the track's height plays once; the server teleports the player back.
	RunService.Heartbeat:Connect(function()
		local trackId = activeTrack
		if trackId == nil then
			return
		end
		local track = Tracks.ById[trackId]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if track == nil or root == nil or not root:IsA("BasePart") then
			return
		end
		local y = root.Position.Y
		if y < track.FallResetY and not fallen then
			fallen = true
			local cues = cuesOf(trackId)
			if cues then
				playCue(cues.fall)
			end
		elseif y >= track.FallResetY + 3 then
			fallen = false
		end
	end)

	-- Warm the cache so the first jump does not wait for the file.
	task.spawn(function()
		local templates: { Instance } = {}
		for id in Sounds.Verified do
			local sound = Instance.new("Sound")
			sound.SoundId = id
			table.insert(templates, sound)
		end
		pcall(function()
			ContentProvider:PreloadAsync(templates)
		end)
		for _, sound in templates do
			sound:Destroy()
		end
	end)
end

return SoundController
