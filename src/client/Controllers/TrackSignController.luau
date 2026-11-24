--!strict
-- Signs above the start pads: the track name, and for a locked track a short reason. A track is
-- locked until the tutorial is finished (Config.Tracks.RequiresTutorial). Display only; the server
-- decides what actually starts (ObstacleDash).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local Components = require(script.Parent.Parent.UI.Components)
local DataController = require(script.Parent.DataController)
local LocalizationController = require(script.Parent.LocalizationController)

local L = LocalizationController.L
local Theme = Components.Theme

local TrackSignController = {}

type Sign = {
	name: TextLabel,
	note: TextLabel,
}

local signs: { [string]: Sign } = {}
local tutorialDone = false

local function render()
	for trackId, sign in signs do
		local track = Tracks.ById[trackId]
		local locked = track.RequiresTutorial and not tutorialDone
		sign.name.Text = L(track.NameKey)
		sign.name.TextColor3 = if locked then Theme.Muted else Theme.TextLight
		sign.note.Text = if locked then L("Track.LockedSign") else ""
		sign.note.Visible = locked
	end
end

local function build(startPad: BasePart): Sign
	local gui = Instance.new("BillboardGui")
	gui.Name = "TrackSign"
	gui.Size = UDim2.fromOffset(300, 78)
	gui.StudsOffset = Vector3.new(0, 10, 0)
	gui.MaxDistance = 260
	gui.AlwaysOnTop = false
	gui.Adornee = startPad
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(24, 30, 46)
	back.BackgroundTransparency = 0.1
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = back

	local name = Components.label({
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.fromOffset(8, 6),
		TextColor3 = Theme.TextLight,
		MaxTextSize = 32,
		Parent = back,
	})
	local note = Components.label({
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.fromOffset(8, 48),
		TextColor3 = Theme.Accent,
		MaxTextSize = 20,
		Parent = back,
	})
	return { name = name, note = note }
end

function TrackSignController:Init()
	DataController.Changed:Connect(function(snapshot)
		tutorialDone = snapshot.Tutorial.Completed
		render()
	end)
	LocalizationController.Changed:Connect(render)
end

function TrackSignController:Start()
	local world = Workspace:WaitForChild("DeskWorld", 30)
	if world == nil then
		return
	end
	for _, trackId in Tracks.Order do
		local track = Tracks.ById[trackId]
		local model = world:WaitForChild(track.WorldName, 30)
		local geometry = model and model:WaitForChild("Geometry", 30)
		local pad = geometry and geometry:WaitForChild("StartPad", 30)
		if pad and pad:IsA("BasePart") then
			signs[trackId] = build(pad)
		else
			warn(`[TrackSignController] StartPad of "{trackId}" not found`)
		end
	end
	local snapshot = DataController:Get()
	if snapshot then
		tutorialDone = snapshot.Tutorial.Completed
	end
	render()
end

return TrackSignController
