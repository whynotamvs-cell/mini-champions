--!strict
-- Records screen: the player's best time and earned medals on every track. Display only, built
-- from the data snapshot; the button appears once the tutorial is finished (before that there is
-- nothing to show). Hotkey R on PC.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.Shared.Utilities.Format)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local Components = require(script.Parent.Parent.UI.Components)
local Juice = require(script.Parent.Parent.UI.Juice)
local DataController = require(script.Parent.DataController)
local LocalizationController = require(script.Parent.LocalizationController)
local UIController = require(script.Parent.UIController)

local L = LocalizationController.L
local Theme = Components.Theme

local MEDALS = { "Bronze", "Silver", "Gold" }
local MEDAL_COLORS: { [string]: Color3 } = {
	Gold = Color3.fromRGB(255, 205, 60),
	Silver = Color3.fromRGB(220, 226, 235),
	Bronze = Color3.fromRGB(214, 140, 80),
}
local EMPTY_MEDAL = Color3.fromRGB(190, 184, 172)
local ROW_HEIGHT = 74

local RecordsController = {}

type RowUi = {
	name: TextLabel,
	best: TextLabel,
	medals: { [string]: Frame },
}

type Ui = {
	frame: Frame,
	title: TextLabel,
	openButton: TextButton,
	close: TextButton,
	rows: { [string]: RowUi },
}

local ui: Ui? = nil
local tutorialDone = false

local function render()
	local u = ui
	if u == nil then
		return
	end
	u.title.Text = L("Records.Title")
	u.openButton.Text = L("HUD.Records")
	u.openButton.Visible = tutorialDone
	u.close.Text = L("UI.Close")

	local snapshot = DataController:Get() :: { [string]: any }?
	for _, trackId in Tracks.Order do
		local track = Tracks.ById[trackId]
		local row = u.rows[trackId]
		local record = snapshot and snapshot[track.DataKey]
		row.name.Text = L(track.NameKey)
		local bestMs = if type(record) == "table" and type(record.BestTimeMs) == "number" then record.BestTimeMs else 0
		row.best.Text = if bestMs > 0 then L("Dash.Result.Best", { time = Format.time(bestMs) }) else L("Records.None")
		for _, medal in MEDALS do
			local earned = type(record) == "table" and type(record.Medals) == "table" and record.Medals[medal] == true
			row.medals[medal].BackgroundColor3 = if earned then MEDAL_COLORS[medal] else EMPTY_MEDAL
		end
	end
end

local function build(canvas: Frame): Ui
	local frame = Components.panel({
		Name = "RecordsPanel",
		Size = UDim2.fromOffset(396, 66 + #Tracks.Order * ROW_HEIGHT + 62),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 31,
		Parent = canvas,
	})
	local title = Components.label({
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.fromOffset(12, 8),
		ZIndex = 32,
		MaxTextSize = 28,
		Parent = frame,
	})

	local rows: { [string]: RowUi } = {}
	for i, trackId in Tracks.Order do
		local top = 52 + (i - 1) * ROW_HEIGHT
		local back = Instance.new("Frame")
		back.Size = UDim2.new(1, -24, 0, ROW_HEIGHT - 8)
		back.Position = UDim2.fromOffset(12, top)
		back.BackgroundColor3 = Theme.PanelDark
		back.BorderSizePixel = 0
		back.ZIndex = 32
		back.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = back

		local name = Components.label({
			Size = UDim2.new(1, -150, 0, 28),
			Position = UDim2.fromOffset(10, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 33,
			MaxTextSize = 24,
			Parent = back,
		})
		local best = Components.label({
			Size = UDim2.new(1, -150, 0, 26),
			Position = UDim2.fromOffset(10, 34),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.AccentDark,
			ZIndex = 33,
			MaxTextSize = 20,
			Parent = back,
		})
		local medals: { [string]: Frame } = {}
		for m, medal in MEDALS do
			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromOffset(30, 30)
			dot.Position = UDim2.new(1, -118 + (m - 1) * 38, 0.5, -15)
			dot.BorderSizePixel = 0
			dot.ZIndex = 33
			dot.Parent = back
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(1, 0)
			round.Parent = dot
			local ring = Instance.new("UIStroke")
			ring.Color = Theme.PanelStroke
			ring.Thickness = 2
			ring.Parent = dot
			medals[medal] = dot
		end
		rows[trackId] = { name = name, best = best, medals = medals }
	end

	local close = Components.button({
		Size = UDim2.fromOffset(140, 44),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.Muted,
		ZIndex = 32,
		Parent = frame,
	}, function()
		frame.Visible = false
	end)

	local openButton = Components.button({
		Name = "RecordsButton",
		Size = UDim2.fromOffset(130, 44),
		Position = UDim2.fromOffset(12, 88),
		MaxTextSize = 18,
		Visible = false,
		Parent = canvas,
	}, function()
		RecordsController:Toggle()
	end)

	return { frame = frame, title = title, openButton = openButton, close = close, rows = rows }
end

function RecordsController:Init()
	DataController.Changed:Connect(function(snapshot)
		tutorialDone = snapshot.Tutorial.Completed
		render()
	end)
	LocalizationController.Changed:Connect(render)
end

function RecordsController:Start()
	ui = build(UIController:GetCanvas())
	local snapshot = DataController:Get()
	if snapshot then
		tutorialDone = snapshot.Tutorial.Completed
	end
	render()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not tutorialDone then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			RecordsController:Toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and ui then
			ui.frame.Visible = false
		end
	end)
end

function RecordsController:Toggle()
	local u = ui
	if u then
		u.frame.Visible = not u.frame.Visible
		if u.frame.Visible then
			Juice.pop(u.frame, 0.85, 0.3)
		end
		render()
	end
end

return RecordsController
