--!strict
-- HUD and Desk Dash screens: Stars, level, club button, countdown, timer, checkpoints,
-- restart button and the result screen. Layout zones follow ARCHITECTURE.md 11: HUD on top,
-- menu buttons right-centre, bottom corners left free for the joystick and jump button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Utilities.Format)
local Components = require(script.Parent.Parent.UI.Components)
local Juice = require(script.Parent.Parent.UI.Juice)
local ClubMenuController = require(script.Parent.ClubMenuController)
local DashController = require(script.Parent.DashController)
local DataController = require(script.Parent.DataController)
local LocalizationController = require(script.Parent.LocalizationController)
local UIController = require(script.Parent.UIController)

local L = LocalizationController.L
local Theme = Components.Theme
local STAR = Components.STAR

local RESULT_SECONDS = 6

local HudController = {}

type Ui = {
	stars: TextLabel,
	level: TextLabel,
	clubButton: TextButton,
	countdown: TextLabel,
	timer: TextLabel,
	checkpoint: TextLabel,
	restart: TextButton,
	result: Frame,
	resultTitle: TextLabel,
	resultLine1: TextLabel,
	resultLine2: TextLabel,
	resultLine3: TextLabel,
	resultClose: TextButton,
}

local ui: Ui? = nil
local running = false
local checkpointIndex = 0
local checkpointTotal = 0
local countdownToken = 0
local resultToken = 0
local lastResult: { [string]: any }? = nil
local starsTarget: number? = nil
local starsToken = 0
local starsAnimating = false

-- Shows the balance: counts up when Stars are earned, jumps when they are spent.
local function setStars(u: Ui, value: number)
	local function text(n: number): string
		return `{STAR} {Format.integer(n)}`
	end
	local previous = starsTarget
	if previous == value then
		if not starsAnimating then
			u.stars.Text = text(value)
		end
		return
	end
	starsTarget = value
	starsToken += 1
	local token = starsToken
	if previous == nil or value < previous then
		starsAnimating = false
		u.stars.Text = text(value)
		if previous ~= nil then
			Juice.pop(u.stars, 1.12, 0.25)
		end
		return
	end
	starsAnimating = true
	Juice.pop(u.stars, 1.2, 0.35)
	Juice.tweenNumber(previous, value, 0.7, function(n: number)
		if token == starsToken then
			u.stars.Text = text(n)
			if n == value then
				starsAnimating = false
			end
		end
	end, function()
		return token ~= starsToken
	end)
end

local function render()
	local u = ui
	if u == nil then
		return
	end
	local snapshot = DataController:Get()
	if snapshot then
		setStars(u, snapshot.Stars)
		u.level.Text = L("HUD.Level", { level = snapshot.Level })
	end
	u.clubButton.Text = L("HUD.Club")
	u.restart.Text = L("Dash.Restart")
	u.restart.Visible = running
	u.timer.Visible = running
	u.checkpoint.Visible = running and checkpointTotal > 0
	u.checkpoint.Text = L("Dash.Checkpoint", { index = checkpointIndex, total = checkpointTotal })
	u.resultClose.Text = L("UI.Close")

	local r = lastResult
	if r then
		if r.valid then
			u.resultTitle.Text = L("Dash.Result.Title")
			local medalName = L(`Dash.Medal.{r.medal}`)
			local timeText = L("Dash.Result.Time", { time = Format.time(r.timeMs) })
			u.resultLine1.Text = `{medalName} · {timeText}`
			u.resultLine2.Text = `+{r.stars} {STAR}`
			u.resultLine3.Text = if r.newBest
				then L("Dash.Result.NewBest")
				elseif snapshot and snapshot.DeskDash.BestTimeMs > 0 then L(
					"Dash.Result.Best",
					{ time = Format.time(snapshot.DeskDash.BestTimeMs) }
				)
				else ""
		else
			u.resultTitle.Text = L("Dash.Result.Title")
			u.resultLine1.Text = L("Dash.Result.Rejected")
			u.resultLine2.Text = ""
			u.resultLine3.Text = ""
		end
	end
end

local function showCountdown(seconds: number)
	local u = ui
	if u == nil then
		return
	end
	countdownToken += 1
	local token = countdownToken
	task.spawn(function()
		for n = seconds, 1, -1 do
			if token ~= countdownToken then
				return
			end
			u.countdown.Text = tostring(n)
			u.countdown.TextColor3 = Theme.Accent
			u.countdown.Visible = true
			Juice.pop(u.countdown, 1.8, 0.4)
			task.wait(1)
		end
	end)
end

local function hideCountdown()
	countdownToken += 1
	if ui then
		ui.countdown.Visible = false
	end
end

local function flashGo()
	local u = ui
	if u == nil then
		return
	end
	countdownToken += 1
	local token = countdownToken
	u.countdown.Text = L("Dash.Go")
	u.countdown.TextColor3 = Theme.Good
	u.countdown.Visible = true
	Juice.pop(u.countdown, 2.1, 0.45)
	task.delay(0.8, function()
		if token == countdownToken then
			u.countdown.Visible = false
		end
	end)
end

local function showResult(event: { [string]: any })
	local u = ui
	if u == nil then
		return
	end
	lastResult = event
	resultToken += 1
	local token = resultToken
	u.result.Visible = true
	render()
	Juice.pop(u.result, 0.8, 0.35)
	-- Reveal the result lines one by one (all at once when motion is reduced or the run was rejected).
	local lines = { u.resultLine1, u.resultLine2, u.resultLine3 }
	for _, resultLine in lines do
		resultLine.Visible = true
	end
	if event.valid and not Juice.isReducedMotion() then
		for _, resultLine in lines do
			resultLine.Visible = false
		end
		task.spawn(function()
			for _, resultLine in lines do
				task.wait(0.25)
				if token ~= resultToken then
					return
				end
				resultLine.Visible = true
				Juice.pop(resultLine, 1.4, 0.3)
			end
		end)
	end
	task.delay(RESULT_SECONDS, function()
		if token == resultToken then
			u.result.Visible = false
		end
	end)
end

local function onDashEvent(event: { [string]: any })
	local kind = event.kind
	if kind == "countdown" then
		if ui then
			ui.result.Visible = false
		end
		showCountdown(event.seconds)
	elseif kind == "cancel" then
		hideCountdown()
		UIController:Toast("Dash.Cancelled")
	elseif kind == "start" then
		running = true
		checkpointIndex = 0
		checkpointTotal = 0
		flashGo()
	elseif kind == "checkpoint" then
		checkpointIndex = event.index
		checkpointTotal = event.total
		if ui then
			Juice.pop(ui.checkpoint, 1.35, 0.3)
		end
	elseif kind == "missing_checkpoint" then
		UIController:Toast("Dash.MissingCheckpoint", { index = event.next })
	elseif kind == "finish" then
		running = false
		showResult(event)
	elseif kind == "abandon" then
		running = false
		hideCountdown()
		UIController:Toast(if event.reason == "timeout" then "Dash.Timeout" else "Dash.Abandoned")
	end
	render()
end

local function build(canvas: Frame): Ui
	local top = Components.panel({
		Name = "TopBar",
		Size = UDim2.fromOffset(250, 52),
		Position = UDim2.fromOffset(12, 10),
		Parent = canvas,
	})
	local stars = Components.label({
		Size = UDim2.new(0.5, -8, 1, -12),
		Position = UDim2.fromOffset(10, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 28,
		Parent = top,
	})
	local level = Components.label({
		Size = UDim2.new(0.5, -8, 1, -12),
		Position = UDim2.new(0.5, 0, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 24,
		Parent = top,
	})

	local clubButton = Components.button({
		Name = "ClubButton",
		Size = UDim2.fromOffset(96, 56),
		Position = UDim2.new(1, -12, 0.42, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = canvas,
	}, function()
		ClubMenuController:Toggle()
	end)

	local restart = Components.button({
		Name = "RestartButton",
		Size = UDim2.fromOffset(96, 48),
		Position = UDim2.new(1, -12, 0.42, 40),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.Muted,
		Visible = false,
		Parent = canvas,
	}, function()
		DashController:RequestRestart()
	end)

	local timer = Components.label({
		Name = "Timer",
		Size = UDim2.fromOffset(180, 44),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = Theme.TextLight,
		TextStrokeTransparency = 0.3,
		MaxTextSize = 36,
		Visible = false,
		Parent = canvas,
	})
	local checkpoint = Components.label({
		Name = "Checkpoint",
		Size = UDim2.fromOffset(220, 30),
		Position = UDim2.new(0.5, 0, 0, 54),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = Theme.TextLight,
		TextStrokeTransparency = 0.3,
		MaxTextSize = 22,
		Visible = false,
		Parent = canvas,
	})
	local countdown = Components.label({
		Name = "Countdown",
		Size = UDim2.fromOffset(260, 110),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Theme.Accent,
		TextStrokeTransparency = 0,
		MaxTextSize = 96,
		Visible = false,
		Parent = canvas,
	})

	local result = Components.panel({
		Name = "Result",
		Size = UDim2.fromOffset(340, 210),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 20,
		Parent = canvas,
	})
	local function line(y: number, height: number, max: number): TextLabel
		return Components.label({
			Size = UDim2.new(1, -24, 0, height),
			Position = UDim2.fromOffset(12, y),
			ZIndex = 21,
			MaxTextSize = max,
			Parent = result,
		})
	end
	local resultTitle = line(10, 40, 34)
	local resultLine1 = line(54, 30, 24)
	local resultLine2 = line(86, 34, 30)
	local resultLine3 = line(122, 26, 22)
	local resultClose = Components.button({
		Size = UDim2.fromOffset(140, 48),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 21,
		Parent = result,
	}, function()
		result.Visible = false
	end)

	return {
		stars = stars,
		level = level,
		clubButton = clubButton,
		countdown = countdown,
		timer = timer,
		checkpoint = checkpoint,
		restart = restart,
		result = result,
		resultTitle = resultTitle,
		resultLine1 = resultLine1,
		resultLine2 = resultLine2,
		resultLine3 = resultLine3,
		resultClose = resultClose,
	}
end

function HudController:Init()
	DataController.Changed:Connect(render)
	LocalizationController.Changed:Connect(render)
	DashController.Event:Connect(onDashEvent)
end

function HudController:Start()
	ui = build(UIController:GetCanvas())
	render()
	RunService.RenderStepped:Connect(function()
		local u = ui
		if u and running then
			local elapsed = DashController:GetElapsedMs()
			if elapsed then
				u.timer.Text = Format.time(elapsed)
			end
		end
	end)
end

return HudController
