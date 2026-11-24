--!strict
-- Calm background music: one looping sound that fades in when the game starts and plays through the
-- "Music" SoundGroup (the music volume in Settings scales it). Silent while Config.Music.asset is empty.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Music = require(ReplicatedStorage.Shared.Config.Music)

local MusicController = {}

local function musicGroup(): SoundGroup
	local existing = SoundService:FindFirstChild("Music")
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = "Music"
	group.Parent = SoundService
	return group
end

function MusicController:Init() end

function MusicController:Start()
	if Music.asset == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "BackgroundMusic"
	sound.SoundId = Music.asset
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = musicGroup()
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(Music.fadeInSec, Enum.EasingStyle.Sine), { Volume = Music.volume }):Play()
end

return MusicController
