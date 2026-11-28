--!strict
-- Root ScreenGui, scaling, loading screen and toasts (docs/ARCHITECTURE.md 11).
-- Base layout 844x390 (landscape phone); UIScale follows the short side of the screen.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Components = require(script.Parent.Parent.UI.Components)
local Juice = require(script.Parent.Parent.UI.Juice)
local Net = require(script.Parent.Parent.Net)
local DataController = require(script.Parent.DataController)
local LocalizationController = require(script.Parent.LocalizationController)

local L = LocalizationController.L
local Theme = Components.Theme

local BASE_SHORT_SIDE = 390
local MIN_SCALE, MAX_SCALE = 0.75, 1.6
local TOAST_SECONDS = 3.5

local UIController = {}

local screen: ScreenGui = Instance.new("ScreenGui")
screen.Name = "MiniChampions"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local scale = Instance.new("UIScale")
scale.Parent = screen

-- The scaled canvas: children are laid out in base-resolution offsets.
local canvas = Instance.new("Frame")
canvas.Name = "Canvas"
canvas.BackgroundTransparency = 1
canvas.AnchorPoint = Vector2.new(0.5, 0.5)
canvas.Position = UDim2.fromScale(0.5, 0.5)
canvas.Parent = screen

local loading: Frame? = nil
local loadingLabel: TextLabel? = nil
local loadingKey = "UI.Loading"
local loadingTitle: TextLabel? = nil
local loadingHint: TextLabel? = nil
local loadError: string? = nil -- localization key of the server's "could not load" reason
local toastHolder: Frame? = nil

local function updateScale()
	-- AbsoluteSize already excludes the safe-area insets (notch, Roblox buttons).
	local area = screen.AbsoluteSize
	if area.X <= 0 or area.Y <= 0 then
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		area = camera.ViewportSize
	end
	local s = math.clamp(math.min(area.X, area.Y) / BASE_SHORT_SIDE, MIN_SCALE, MAX_SCALE)
	scale.Scale = s
	-- The canvas fills the safe area in base-layout units.
	canvas.Size = UDim2.fromOffset(area.X / s, area.Y / s)
end

-- Loading screen: bright gradient, bouncing logo, drifting stars, a shimmering bar and a rotating tip.
local TIP_COUNT = 5
local TIP_SECONDS = 3.2
local loadingDecor: { GuiObject } = {}

local function gradientOn(parent: Instance, rotation: number, colors: { Color3 })
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	g.Color = ColorSequence.new(keys)
	g.Parent = parent
	return g
end

local function buildLoading()
	local frame = Instance.new("Frame")
	frame.Name = "Loading"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.ZIndex = 100
	frame.ClipsDescendants = true
	frame.Parent = canvas
	gradientOn(frame, 35, { Color3.fromRGB(255, 160, 40), Color3.fromRGB(235, 70, 130), Color3.fromRGB(90, 70, 200) })
	loadingDecor = {}

	-- Drifting stars in the background.
	local stars: { { gui: TextLabel, speed: number, phase: number, baseX: number } } = {}
	for i = 1, 14 do
		local star = Instance.new("TextLabel")
		star.BackgroundTransparency = 1
		star.Text = Components.STAR
		star.Font = Theme.Font
		star.AutoLocalize = false
		star.TextColor3 = Color3.fromRGB(255, 240, 150)
		star.TextTransparency = 0.45
		star.TextSize = 18 + (i * 7) % 34
		star.Size = UDim2.fromOffset(60, 60)
		star.Rotation = (i * 37) % 60 - 30
		star.ZIndex = 101
		star.Parent = frame
		table.insert(loadingDecor, star)
		table.insert(stars, { gui = star, speed = 12 + (i * 5) % 22, phase = i * 1.7, baseX = ((i * 61) % 100) / 100 })
	end

	local logo = Components.label({
		Size = UDim2.fromOffset(620, 96),
		Position = UDim2.fromScale(0.5, 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 103,
		MaxTextSize = 84,
		Parent = frame,
	})
	logo.Name = "Logo"
	logo.TextStrokeTransparency = 1
	local logoStroke = Instance.new("UIStroke")
	logoStroke.Color = Theme.TextStroke
	logoStroke.Thickness = 6
	logoStroke.Parent = logo
	gradientOn(logo, 90, { Color3.fromRGB(255, 250, 170), Color3.fromRGB(255, 190, 40), Color3.fromRGB(255, 120, 30) })
	local logoScale = Instance.new("UIScale")
	logoScale.Parent = logo
	table.insert(loadingDecor, logo)

	local tagline = Components.label({
		Name = "Tagline",
		Size = UDim2.fromOffset(520, 34),
		Position = UDim2.fromScale(0.5, 0.46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 103,
		MaxTextSize = 26,
		Parent = frame,
	})
	table.insert(loadingDecor, tagline)

	loadingLabel = Components.label({
		Size = UDim2.fromOffset(400, 40),
		Position = UDim2.fromScale(0.5, 0.64),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Theme.TextLight,
		ZIndex = 103,
		MaxTextSize = 30,
		Parent = frame,
	})

	-- Indeterminate bar: a bright block sliding back and forth in a dark pill.
	local track = Instance.new("Frame")
	track.Name = "BarTrack"
	track.Size = UDim2.fromOffset(360, 22)
	track.Position = UDim2.fromScale(0.5, 0.74)
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.BackgroundColor3 = Theme.PanelDark
	track.ClipsDescendants = true
	track.ZIndex = 103
	track.Parent = frame
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = Theme.Outline
	trackStroke.Thickness = 3
	trackStroke.Parent = track
	local block = Instance.new("Frame")
	block.Size = UDim2.fromOffset(130, 22)
	block.BackgroundColor3 = Theme.Accent
	block.ZIndex = 104
	block.Parent = track
	local blockCorner = Instance.new("UICorner")
	blockCorner.CornerRadius = UDim.new(1, 0)
	blockCorner.Parent = block
	gradientOn(block, 90, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190) })
	table.insert(loadingDecor, track)

	local tip = Components.label({
		Name = "Tip",
		Size = UDim2.fromOffset(560, 34),
		Position = UDim2.fromScale(0.5, 0.88),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 103,
		MaxTextSize = 22,
		TextWrapped = true,
		Parent = frame,
	})
	table.insert(loadingDecor, tip)

	-- Shown only when the server reports that the profile could not be loaded.
	loadingTitle = Components.label({
		Size = UDim2.fromOffset(460, 44),
		Position = UDim2.fromScale(0.5, 0.28),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Theme.AccentDark,
		ZIndex = 103,
		MaxTextSize = 34,
		Visible = false,
		Parent = frame,
	})
	loadingHint = Components.label({
		Size = UDim2.fromOffset(460, 56),
		Position = UDim2.fromScale(0.5, 0.76),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Theme.TextLight,
		TextWrapped = true,
		ZIndex = 103,
		MaxTextSize = 22,
		Visible = false,
		Parent = frame,
	})
	loading = frame

	local startedAt = os.clock()
	local tipIndex = 0
	local function nextTip()
		tipIndex = tipIndex % TIP_COUNT + 1
		tip.Text = L(`Loading.Tip.{tipIndex}`)
	end
	nextTip()
	task.spawn(function()
		local lastTip = os.clock()
		while loading == frame and frame.Parent do
			local t = os.clock() - startedAt
			local pulse = 1 + 0.045 * math.sin(t * 3)
			logoScale.Scale = pulse
			logo.Rotation = 2.2 * math.sin(t * 1.6)
			local cycle = (t * 0.55) % 2
			local pos = if cycle < 1 then cycle else 2 - cycle
			block.Position = UDim2.fromOffset(pos * (360 - 130), 0)
			for _, star in stars do
				local y = ((t * star.speed + star.phase * 40) % 520) / 520
				star.gui.Position = UDim2.fromScale(star.baseX, 1 - y)
				star.gui.Rotation += 0.4
			end
			if os.clock() - lastTip > TIP_SECONDS then
				lastTip = os.clock()
				nextTip()
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

local function refreshTexts()
	if loading then
		local logo = loading:FindFirstChild("Logo")
		if logo and logo:IsA("TextLabel") then
			logo.Text = L("Game.Title")
		end
		local tagline = loading:FindFirstChild("Tagline")
		if tagline and tagline:IsA("TextLabel") then
			tagline.Text = L("Loading.Tagline")
		end
	end
	if loadingLabel then
		loadingLabel.Text = L(loadError or loadingKey)
		loadingLabel.TextWrapped = true
	end
	if loadingTitle and loadError then
		loadingTitle.Text = L("Error.Title")
	end
	if loadingHint and loadError then
		loadingHint.Text = L("Error.RejoinHint")
	end
end

-- The server could not load this player's data and is about to kick: replace "Loading…" with
-- the reason and a hint, so the player is not left staring at a spinner.
local function showLoadError(key: string)
	if loading == nil then
		return
	end
	loadError = key
	for _, decor in loadingDecor do
		decor.Visible = false
	end
	for _, label in { loadingTitle, loadingHint } do
		if label then
			label.Visible = true
		end
	end
	if loadingLabel then
		loadingLabel.Size = UDim2.fromOffset(460, 90)
		loadingLabel.Position = UDim2.fromScale(0.5, 0.5)
		loadingLabel.TextColor3 = Theme.TextLight
	end
	refreshTexts()
end

function UIController:Init()
	DataController.Changed:Connect(function()
		if loading then
			local cover = loading
			loading = nil
			loadingLabel = nil
			loadingTitle = nil
			loadingHint = nil
			Juice.fadeOutAndDestroy(cover)
		end
	end)
	LocalizationController.Changed:Connect(refreshTexts)
end

function UIController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	buildLoading()

	local holder = Instance.new("Frame")
	holder.Name = "Toasts"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(460, 200)
	holder.Position = UDim2.new(0.5, 0, 0, 70)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.ZIndex = 50
	holder.Parent = canvas
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	toastHolder = holder

	screen.Parent = playerGui
	updateScale()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
	refreshTexts()

	Net.onClientEvent("Notify", function(key: string, args: { [string]: any }?)
		if type(key) ~= "string" then
			return
		end
		if loading and string.find(key, "^Error%.") ~= nil then
			showLoadError(key) -- before the first snapshot an Error.* key means the load failed
		else
			UIController:Toast(key, args)
		end
	end)

	task.delay(GameConfig.LoadTimeoutSec, function()
		if loading and loadError == nil then
			loadingKey = "UI.LoadingSlow"
			refreshTexts()
		end
	end)
end

-- Container for screens built by other controllers.
function UIController:GetCanvas(): Frame
	return canvas
end

-- Short message at the top of the screen. Text is re-read on language change while visible.
function UIController:Toast(key: string, args: { [string]: any }?, seconds: number?)
	local holder = toastHolder
	if holder == nil then
		return
	end
	local toast = Components.panel({
		Size = UDim2.fromOffset(440, 44),
		BackgroundColor3 = Theme.Panel,
		ZIndex = 51,
		Parent = holder,
	})
	local label = Components.label({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = L(key, args),
		ZIndex = 52,
		MaxTextSize = 24,
		Parent = toast,
	})
	Juice.pop(toast, 0.8, 0.25)
	local connection = LocalizationController.Changed:Connect(function()
		label.Text = L(key, args)
	end)
	task.delay(seconds or TOAST_SECONDS, function()
		connection:Disconnect()
		toast:Destroy()
	end)
end

return UIController
