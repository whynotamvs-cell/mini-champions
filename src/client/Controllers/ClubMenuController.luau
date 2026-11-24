--!strict
-- Club menu: next upgrade, price and the Build button (tutorial target "BuyButton"). Sends only the intent ("buy index N");
-- the server checks order, price and balance (docs/ARCHITECTURE.md 6.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Format = require(ReplicatedStorage.Shared.Utilities.Format)
local Components = require(script.Parent.Parent.UI.Components)
local Juice = require(script.Parent.Parent.UI.Juice)
local Net = require(script.Parent.Parent.Net)
local DataController = require(script.Parent.DataController)
local LocalizationController = require(script.Parent.LocalizationController)
local UIController = require(script.Parent.UIController)

local L = LocalizationController.L
local STAR = Components.STAR

local ClubMenuController = {}

-- Fired when the menu becomes visible (the tutorial listens). Handlers must not yield.
ClubMenuController.Opened = Signal.new() :: Signal.Signal<>

type Ui = {
	frame: Frame,
	title: TextLabel,
	level: TextLabel,
	nextLabel: TextLabel,
	name: TextLabel,
	price: TextLabel,
	status: TextLabel,
	buy: TextButton,
	close: TextButton,
}

local ui: Ui? = nil
local pending = false

-- Highest upgrade index the server can actually build (models exist); set by ClubService.
local function availableUpgrades(): number
	local value = ReplicatedStorage:GetAttribute("AvailableUpgrades")
	return if type(value) == "number" then value else 0
end

local function render()
	local u = ui
	if u == nil then
		return
	end
	u.title.Text = L("Club.Title")
	u.nextLabel.Text = L("Club.Next")
	u.buy.Text = L("Club.Buy")
	u.close.Text = L("UI.Close")

	local snapshot = DataController:Get()
	if snapshot == nil then
		return
	end
	u.level.Text = L("Club.Level", { level = snapshot.ClubLevel })

	local nextIndex = snapshot.UpgradesOwned + 1
	local upgrade = Economy.Upgrades[nextIndex]
	local canBuy = false
	if upgrade == nil then
		u.name.Text = ""
		u.price.Text = ""
		u.status.Text = L("Club.AllBuilt")
	elseif nextIndex > availableUpgrades() then
		u.name.Text = L(`Club.Upgrade.{upgrade.Id}.Name`)
		u.price.Text = `{STAR} {Format.integer(upgrade.Price)}`
		u.status.Text = L("Club.ComingSoon")
	else
		u.name.Text = L(`Club.Upgrade.{upgrade.Id}.Name`)
		u.price.Text = `{STAR} {Format.integer(upgrade.Price)}`
		canBuy = snapshot.Stars >= upgrade.Price
		u.status.Text = if canBuy then "" else L("Club.NotEnough")
	end
	u.buy.Visible = upgrade ~= nil and nextIndex <= availableUpgrades()
	Components.setEnabled(u.buy, canBuy and not pending)
end

local function buy()
	local snapshot = DataController:Get()
	if pending or snapshot == nil then
		return
	end
	local index = snapshot.UpgradesOwned + 1
	local upgrade = Economy.Upgrades[index]
	if upgrade == nil or snapshot.Stars < upgrade.Price then
		return
	end
	pending = true
	render()
	task.spawn(function()
		local ok, response = pcall(Net.invokeServer, "PurchaseUpgrade", index)
		pending = false
		if ok and type(response) == "table" and response.ok then
			UIController:Toast("Club.Built", { name = L(`Club.Upgrade.{upgrade.Id}.Name`) })
		elseif ok and type(response) == "table" and response.reason == "unavailable" then
			UIController:Toast("Club.ComingSoon")
		else
			UIController:Toast("Error.PurchaseFailed")
		end
		render()
	end)
end

local function build(canvas: Frame): Ui
	local frame = Components.panel({
		Name = "ClubMenu",
		Size = UDim2.fromOffset(380, 260),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 30,
		Parent = canvas,
	})
	local function line(y: number, height: number, max: number): TextLabel
		return Components.label({
			Size = UDim2.new(1, -24, 0, height),
			Position = UDim2.fromOffset(12, y),
			ZIndex = 31,
			MaxTextSize = max,
			Parent = frame,
		})
	end
	local title = line(10, 36, 32)
	local level = line(48, 24, 20)
	local nextLabel = line(80, 22, 18)
	local name = line(104, 32, 26)
	local price = line(138, 28, 24)
	local status = line(168, 22, 18)
	local buyButton = Components.button({
		Name = "BuyButton",
		Size = UDim2.fromOffset(150, 52),
		Position = UDim2.new(0.5, -8, 1, -12),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 31,
		Parent = frame,
	}, buy)
	local close = Components.button({
		Size = UDim2.fromOffset(150, 52),
		Position = UDim2.new(0.5, 8, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Components.Theme.Muted,
		ZIndex = 31,
		Parent = frame,
	}, function()
		frame.Visible = false
	end)
	return {
		frame = frame,
		title = title,
		level = level,
		nextLabel = nextLabel,
		name = name,
		price = price,
		status = status,
		buy = buyButton,
		close = close,
	}
end

function ClubMenuController:Init()
	DataController.Changed:Connect(render)
	LocalizationController.Changed:Connect(render)
end

function ClubMenuController:Start()
	ui = build(UIController:GetCanvas())
	ReplicatedStorage:GetAttributeChangedSignal("AvailableUpgrades"):Connect(render)
	render()
	-- PC hotkeys (ARCHITECTURE.md 11): C toggles the club menu, Escape closes it.
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.C then
			ClubMenuController:Toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and ui then
			ui.frame.Visible = false
		end
	end)
end

function ClubMenuController:Toggle()
	local u = ui
	if u then
		u.frame.Visible = not u.frame.Visible
		if u.frame.Visible then
			Juice.pop(u.frame, 0.85, 0.3)
			ClubMenuController.Opened:Fire()
		end
		render()
	end
end

return ClubMenuController
