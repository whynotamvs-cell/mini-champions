--!strict
-- Root ScreenGui, scaling, loading screen and toasts (docs/ARCHITECTURE.md 11).
-- Base layout 844x390 (landscape phone); UIScale follows the short side of the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Components = require(script.Parent.Parent.UI.Components)
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
	loading = frame
end

local function refreshTexts()
	if loadingLabel then
		loadingLabel.Text = L(loadingKey)
	end
end

function UIController:Init()
	DataController.Changed:Connect(function()
		if loading then
			loading:Destroy()
			loading = nil
			loadingLabel = nil
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
		if type(key) == "string" then
			UIController:Toast(key, args)
		end
	end)

	task.delay(GameConfig.LoadTimeoutSec, function()
		if loading then
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
	local connection = LocalizationController.Changed:Connect(function()
		label.Text = L(key, args)
	end)
	task.delay(seconds or TOAST_SECONDS, function()
		connection:Disconnect()
		toast:Destroy()
	end)
end

return UIController
