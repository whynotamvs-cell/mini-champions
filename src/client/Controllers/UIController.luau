--!strict
-- Root ScreenGui, scaling, loading screen and toasts (docs/ARCHITECTURE.md 11).
-- Base layout 844x390 (landscape phone); UIScale follows the short side of the screen.

local Players = game:GetService("Players")
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

local function buildLoading()
	local frame = Instance.new("Frame")
	frame.Name = "Loading"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.Shade
	frame.ZIndex = 100
	frame.Parent = canvas
	loadingLabel = Components.label({
		Size = UDim2.fromOffset(400, 48),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Theme.TextLight,
		ZIndex = 101,
		MaxTextSize = 36,
		Parent = frame,
	})
	-- Shown only when the server reports that the profile could not be loaded.
	loadingTitle = Components.label({
		Size = UDim2.fromOffset(460, 44),
		Position = UDim2.fromScale(0.5, 0.28),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Theme.Accent,
		ZIndex = 101,
		MaxTextSize = 34,
		Visible = false,
		Parent = frame,
	})
	loadingHint = Components.label({
		Size = UDim2.fromOffset(460, 56),
		Position = UDim2.fromScale(0.5, 0.76),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Theme.Muted,
		TextWrapped = true,
		ZIndex = 101,
		MaxTextSize = 22,
		Visible = false,
		Parent = frame,
	})
	loading = frame
end

local function refreshTexts()
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
	for _, label in { loadingTitle, loadingHint } do
		if label then
			label.Visible = true
		end
	end
	if loadingLabel then
		loadingLabel.Size = UDim2.fromOffset(460, 90)
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
