--!strict
-- Results board just past the finish: the fastest valid finishes on this server, drawn as a
-- SurfaceGui on the ResultsBoard part. Display only: the server decides what is on the board and
-- only names, times and medals arrive here. Title and empty text are localized per viewer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Utilities.Format)
local Components = require(script.Parent.Parent.UI.Components)
local Juice = require(script.Parent.Parent.UI.Juice)
local Net = require(script.Parent.Parent.Net)
local LocalizationController = require(script.Parent.LocalizationController)

local L = LocalizationController.L
local Theme = Components.Theme

local MAX_ROWS = 5
local PIXELS_PER_STUD = 40 -- the 22 x 12 stud board becomes 880 x 480 px

local MEDAL_COLORS: { [string]: Color3 } = {
	Gold = Color3.fromRGB(255, 205, 60),
	Silver = Color3.fromRGB(220, 226, 235),
	Bronze = Color3.fromRGB(214, 140, 80),
}
local ROW_COLOR = Color3.fromRGB(40, 48, 70)
local OWN_ROW_COLOR = Color3.fromRGB(70, 90, 140)

local BoardController = {}

type Row = { userId: number, name: string, timeMs: number, medal: string }

type RowUi = {
	frame: Frame,
	rank: TextLabel,
	name: TextLabel,
	time: TextLabel,
	medal: Frame,
}

type Ui = {
	title: TextLabel,
	empty: TextLabel,
	rows: { RowUi },
}

local ui: Ui? = nil
local rows: { Row } = {}

-- Keeps only well-formed rows; anything unexpected is dropped, never trusted.
local function parse(payload: any): { Row }
	local out: { Row } = {}
	if type(payload) ~= "table" then
		return out
	end
	for i = 1, math.min(#payload, MAX_ROWS) do
		local entry = payload[i]
		if
			type(entry) == "table"
			and type(entry.userId) == "number"
			and type(entry.name) == "string"
			and type(entry.timeMs) == "number"
			and type(entry.medal) == "string"
		then
			table.insert(out, {
				userId = entry.userId,
				name = entry.name,
				timeMs = entry.timeMs,
				medal = entry.medal,
			})
		end
	end
	return out
end

local function render(changed: { [number]: boolean }?)
	local u = ui
	if u == nil then
		return
	end
	u.title.Text = L("Board.Title")
	u.empty.Text = L("Board.Empty")
	u.empty.Visible = #rows == 0
	local me = Players.LocalPlayer.UserId
	for i, rowUi in u.rows do
		local row = rows[i]
		rowUi.frame.Visible = row ~= nil
		if row then
			rowUi.rank.Text = tostring(i)
			rowUi.name.Text = row.name
			rowUi.time.Text = Format.time(row.timeMs)
			rowUi.medal.BackgroundColor3 = MEDAL_COLORS[row.medal] or MEDAL_COLORS.Bronze
			rowUi.frame.BackgroundColor3 = if row.userId == me then OWN_ROW_COLOR else ROW_COLOR
			if changed and changed[i] then
				Juice.pop(rowUi.frame, 1.06, 0.35)
			end
		end
	end
end

local function build(board: BasePart): Ui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ResultsBoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.Adornee = board
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(24, 30, 46)
	back.BorderSizePixel = 0
	back.Parent = gui

	local title = Components.label({
		Size = UDim2.new(1, -40, 0, 70),
		Position = UDim2.fromOffset(20, 10),
		TextColor3 = Theme.Accent,
		MaxTextSize = 56,
		Parent = back,
	})
	local empty = Components.label({
		Size = UDim2.new(1, -80, 0, 100),
		Position = UDim2.fromOffset(40, 200),
		TextColor3 = Theme.TextLight,
		MaxTextSize = 40,
		Parent = back,
	})

	local rowUis: { RowUi } = {}
	for i = 1, MAX_ROWS do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, -40, 0, 66)
		frame.Position = UDim2.fromOffset(20, 90 + (i - 1) * 76)
		frame.BackgroundColor3 = ROW_COLOR
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Parent = back
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = frame

		local rank = Components.label({
			Size = UDim2.fromOffset(60, 50),
			Position = UDim2.fromOffset(12, 8),
			TextColor3 = Theme.TextLight,
			MaxTextSize = 44,
			Parent = frame,
		})
		local medal = Instance.new("Frame")
		medal.Size = UDim2.fromOffset(30, 30)
		medal.Position = UDim2.fromOffset(82, 18)
		medal.BorderSizePixel = 0
		medal.Parent = frame
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = medal
		local name = Components.label({
			Size = UDim2.new(1, -420, 0, 50),
			Position = UDim2.fromOffset(130, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.TextLight,
			MaxTextSize = 40,
			Parent = frame,
		})
		local time = Components.label({
			Size = UDim2.fromOffset(250, 50),
			Position = UDim2.new(1, -262, 0, 8),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Theme.TextLight,
			MaxTextSize = 44,
			Parent = frame,
		})
		table.insert(rowUis, { frame = frame, rank = rank, name = name, time = time, medal = medal })
	end

	return { title = title, empty = empty, rows = rowUis }
end

-- Which row positions got a new or faster result since the last update (for the pop).
local function changedRows(old: { Row }, new: { Row }): { [number]: boolean }
	local changed: { [number]: boolean } = {}
	for i, row in new do
		local before = old[i]
		if before == nil or before.userId ~= row.userId or before.timeMs ~= row.timeMs then
			changed[i] = true
		end
	end
	return changed
end

function BoardController:Init()
	LocalizationController.Changed:Connect(function()
		render(nil)
	end)
end

function BoardController:Start()
	local world = Workspace:WaitForChild("DeskWorld", 30)
	local board = world
		and world:WaitForChild("DeskDash", 30)
		and world.DeskDash:WaitForChild("Geometry", 30)
		and world.DeskDash.Geometry:WaitForChild("ResultsBoard", 30)
	if board == nil or not board:IsA("BasePart") then
		warn("[BoardController] ResultsBoard part not found; the results board is not shown")
		return
	end
	ui = build(board)
	render(nil)

	Net.onClientEvent("BoardUpdate", function(payload: any)
		local new = parse(payload)
		local changed = changedRows(rows, new)
		rows = new
		render(changed)
	end)
	Net.fireServer("RequestBoard")
end

return BoardController
