--!strict
-- Obstacle track sounds: countdown ticks, GO, jump and landing during a run, checkpoint chime, fall,
-- and the finish jingle by medal. Each track plays cues from its own sprite file (Config.Sounds,
-- made by tools/gen_sounds.py). A track whose sprite has no asset id yet stays silent. Driven only by
-- server DashEvents and the local character's own jump/landing; every sound goes through the "Sfx"
-- SoundGroup, so the volume setting applies.

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
local LOAD_TIMEOUT_SEC = 3

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

local function spriteOf(trackId: any): Sounds.Sprite?
	if type(trackId) ~= "string" then
		return nil
	end
	local sprite = (Sounds.Tracks :: any)[trackId] :: Sounds.Sprite?
	if sprite == nil or sprite.asset == "" then
		return nil -- no sprite uploaded yet: this track stays silent
	end
	return sprite
end

-- Plays one cue of a sprite: starts the file at the cue's offset, stops it after the cue's length.
local function playCue(sprite: Sounds.Sprite, cue: Sounds.Cue, throttleKey: string?)
	if throttleKey then
		local now = os.clock()
		if now - (lastPlayed[throttleKey] or 0) < MIN_GAP_SEC then
			return
		end
		lastPlayed[throttleKey] = now
	end
	task.spawn(function()
		local sound = Instance.new("Sound")
		sound.SoundId = sprite.asset
		sound.Volume = cue.volume
		sound.SoundGroup = sfxGroup()
		sound.Parent = SoundService
		Debris:AddItem(sound, cue.length + LOAD_TIMEOUT_SEC + 1) -- safety net
		if not sound.IsLoaded then
			local loaded = false
			sound.Loaded:Once(function()
				loaded = true
			end)
			local waited = 0
			while not loaded and waited < LOAD_TIMEOUT_SEC do
				task.wait(0.05)
				waited += 0.05
			end
			if not loaded then
				sound:Destroy()
				return
			end
		end
		sound.TimePosition = cue.start
		sound:Play()
		task.delay(cue.length, function()
			if sound.Parent then
				sound:Stop()
				sound:Destroy()
			end
		end)
	end)
end

local function onDashEvent(event: DashController.DashEvent)
	local trackId = event.track
	local sprite = spriteOf(trackId)
	if sprite == nil then
		return
	end
	local cues = sprite.cues
	local kind = event.kind
	if kind == "countdown" then
		countdownToken += 1
		local token = countdownToken
		local seconds = if type(event.seconds) == "number" then event.seconds else 3
		for i = 0, seconds - 1 do
			task.delay(i, function()
				if token == countdownToken then
					playCue(sprite, cues.tick)
				end
			end)
		end
	elseif kind == "start" then
		countdownToken += 1
		activeTrack = trackId
		fallen = false
		playCue(sprite, cues.go)
	elseif kind == "checkpoint" then
		playCue(sprite, cues.checkpoint)
	elseif kind == "finish" then
		activeTrack = nil
		if event.valid == true then
			local medal = if event.medal == "Gold" or event.medal == "Silver" then event.medal else "Bronze"
			playCue(sprite, (cues :: any)["finish" .. medal])
		else
			playCue(sprite, cues.rejected)
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
		local sprite = spriteOf(activeTrack)
		if sprite == nil then
			return
		end
		if new == Enum.HumanoidStateType.Jumping then
			playCue(sprite, sprite.cues.jump, "jump")
		elseif new == Enum.HumanoidStateType.Landed then
			playCue(sprite, sprite.cues.land, "land")
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
		local sprite = spriteOf(trackId)
		if trackId == nil or sprite == nil then
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
			playCue(sprite, sprite.cues.fall)
		elseif y >= track.FallResetY + 3 then
			fallen = false
		end
	end)

	-- Warm the cache so the first cue does not wait for the file.
	task.spawn(function()
		local templates: { Instance } = {}
		for _, trackId in Tracks.Order do
			local sprite: Sounds.Sprite = (Sounds.Tracks :: any)[trackId]
			if sprite.asset ~= "" then
				local sound = Instance.new("Sound")
				sound.SoundId = sprite.asset
				table.insert(templates, sound)
			end
		end
		if #templates == 0 then
			return
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
