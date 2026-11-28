--!strict
-- Big, colourful run feedback in the style of popular Roblox games: sliding ribbons for checkpoints,
-- finish and records, a progress bar with a dot per checkpoint, a red flash when a hazard hits and
-- a welcome ribbon. Display only, driven by server DashEvents and the data snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local Components = require(script.Parent.Parent.UI.Components)
local Juice = require(script.Parent.Parent.UI.Juice)
local DashController = require(script.Parent.DashController)
local DataController = require(script.Parent.DataController)
local LocalizationController = require(script.Parent.LocalizationController)
local UIController = require(script.Parent.UIController)

local L = LocalizationController.L
local Theme = Components.Theme

local BannerController = {}

type Progress = {
	holder: Frame,
	fill: Frame,
	dots: { Frame },
}

local BANNER_Y = 150
local HOLD_SECONDS = 1.7

local canvas: Frame? = nil
local flash: Frame? = nil
local progress: Progress? = nil
local progressTotal = 0
local welcomed = false
local queueBusyUntil = 0

local function addGradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
end

-- A ribbon slides down from above, bounces, waits and slides away. Only one ribbon at a time per slot:
-- a newer one waits for the older one to clear so two never overlap.
local function ribbon(text: string, color: Color3, size: number?, delaySeconds: number?)
	local root = canvas
	if root == nil then
		return
	end
	local start = math.max(os.clock() + (delaySeconds or 0), queueBusyUntil)
	queueBusyUntil = start + HOLD_SECONDS + 0.6
	task.delay(start - os.clock(), function()
		if canvas == nil then
			return
		end
		local frame = Instance.new("Frame")
		frame.Name = "Ribbon"
		frame.Size = UDim2.fromOffset(size or 380, 58)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.new(0.5, 0, 0, -60)
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		frame.ZIndex = 60
		frame.Parent = root
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Outline
		stroke.Thickness = 4
		stroke.Parent = frame
		addGradient(frame, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 180))
		local label = Components.label({
			Size = UDim2.new(1, -24, 1, -10),
			Position = UDim2.fromOffset(12, 5),
			Text = text,
			ZIndex = 61,
			MaxTextSize = 40,
			Parent = frame,
		})
		label.TextStrokeTransparency = 0
		local target = UDim2.new(0.5, 0, 0, BANNER_Y)
		if Juice.isReducedMotion() then
			frame.Position = target
		else
			TweenService
				:Create(
					frame,
					TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Position = target }
				)
				:Play()
		end
		task.delay(HOLD_SECONDS, function()
			if Juice.isReducedMotion() then
				frame:Destroy()
				return
			end
			local out = TweenService:Create(
				frame,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.new(0.5, 0, 0, -60) }
			)
			out.Completed:Once(function()
				frame:Destroy()
			end)
			out:Play()
		end)
	end)
end

-- A quick red edge flash (hazard hit). Skipped with reduced motion.
local function flashRed()
	local f = flash
	if f == nil or Juice.isReducedMotion() then
		return
	end
	f.BackgroundTransparency = 0.55
	TweenService
		:Create(f, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		:Play()
end

local function buildProgress(root: Frame): Progress
	local holder = Instance.new("Frame")
	holder.Name = "RunProgress"
	holder.Size = UDim2.fromOffset(270, 16)
	holder.Position = UDim2.new(0.5, 0, 0, 90)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.BackgroundColor3 = Theme.PanelDark
	holder.Visible = false
	holder.ZIndex = 8
	holder.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Outline
	stroke.Thickness = 3
	stroke.Parent = holder
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.Good
	fill.BorderSizePixel = 0
	fill.ZIndex = 9
	fill.Parent = holder
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	addGradient(fill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175))
	return { holder = holder, fill = fill, dots = {} }
end

-- Rebuilds the dots for a track with `total` checkpoints (plus the finish).
local function layoutDots(total: number)
	local p = progress
	if p == nil or progressTotal == total then
		return
	end
	progressTotal = total
	for _, dot in p.dots do
		dot:Destroy()
	end
	p.dots = {}
	for i = 1, total do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(12, 12)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(i / (total + 1), 0.5)
		dot.BackgroundColor3 = Theme.Muted
		dot.ZIndex = 10
		dot.Parent = p.holder
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = dot
		local ring = Instance.new("UIStroke")
		ring.Color = Theme.Outline
		ring.Thickness = 2
		ring.Parent = dot
		table.insert(p.dots, dot)
	end
end

local function setProgress(reached: number, total: number)
	local p = progress
	if p == nil then
		return
	end
	layoutDots(total)
	local alpha = reached / (total + 1)
	TweenService:Create(p.fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1),
	}):Play()
	for i, dot in p.dots do
		dot.BackgroundColor3 = if i <= reached then Theme.Accent else Theme.Muted
	end
end

local function onDashEvent(event: DashController.DashEvent)
	local p = progress
	local kind = event.kind
	if kind == "start" then
		local track = Tracks.ById[tostring(event.track)]
		if p and track then
			p.holder.Visible = true
			progressTotal = -1
			setProgress(0, track.CheckpointCount)
		end
	elseif kind == "checkpoint" then
		if type(event.index) == "number" and type(event.total) == "number" then
			setProgress(event.index, event.total)
			ribbon(L("Banner.Checkpoint", { index = event.index, total = event.total }), Theme.Good, 340)
		end
	elseif kind == "finish" then
		if p then
			p.holder.Visible = false
		end
		if event.valid == true then
			ribbon(L("Banner.Finish"), Color3.fromRGB(255, 190, 40), 380)
			if event.newBest == true then
				ribbon(L("Banner.NewRecord"), Color3.fromRGB(230, 70, 170), 420)
			end
		end
	elseif kind == "abandon" or kind == "cancel" then
		if p then
			p.holder.Visible = false
		end
	elseif kind == "hazard" then
		flashRed()
		ribbon(L("Banner.Zap"), Theme.Bad, 400)
	end
end

function BannerController:Init()
	DashController.Event:Connect(onDashEvent)
	DataController.Changed:Connect(function()
		if not welcomed then
			welcomed = true
			task.delay(1.2, function()
				ribbon(L("Banner.Welcome"), Theme.Blue, 420)
			end)
		end
	end)
end

function BannerController:Start()
	local root = UIController:GetCanvas()
	canvas = root
	progress = buildProgress(root)
	local f = Instance.new("Frame")
	f.Name = "HazardFlash"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(255, 40, 50)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Active = false
	f.ZIndex = 40
	f.Parent = root
	flash = f
end

return BannerController
