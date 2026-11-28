--!strict
-- Shop: paid items (skip, Spring Boots, Stars packs, cosmetics). The client only shows prices from
-- Roblox's own purchase prompt and sends intents ("equip X", "boots on", "use a skip"); the server
-- owns tokens, passes and equipped items (docs/ECONOMY.md 9). Items whose Creator Hub id is still 0 show "Soon".

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Components = require(script.Parent.Parent.UI.Components)
local Juice = require(script.Parent.Parent.UI.Juice)
local Net = require(script.Parent.Parent.Net)
local DashController = require(script.Parent.DashController)
local DataController = require(script.Parent.DataController)
local LocalizationController = require(script.Parent.LocalizationController)
local UIController = require(script.Parent.UIController)

local L = LocalizationController.L

local ShopController = {}

type Ui = {
	open: TextButton,
	skip: TextButton,
	frame: Frame,
	title: TextLabel,
	note: TextLabel,
	list: ScrollingFrame,
	close: TextButton,
}

local ROW_HEIGHT = 54

local ui: Ui? = nil
local running = false
local rows: { [string]: { frame: Frame, name: TextLabel, action: TextButton } } = {}

local function snapshot()
	return DataController:Get()
end

local function prompt(item: Shop.Item)
	if item.RobloxId == 0 then
		return
	end
	local player = Players.LocalPlayer
	if item.Kind == "Pass" then
		MarketplaceService:PromptGamePassPurchase(player, item.RobloxId)
	else
		MarketplaceService:PromptProductPurchase(player, item.RobloxId)
	end
end

local function nameOf(item: Shop.Item, data: any): string
	local count = if data then data.Shop.SkipTokens else 0
	return L(`Shop.Item.{item.Id}.Name`, { count = count, stars = item.Stars or 0 })
end

-- What the action button of an item says and does right now.
local function actionFor(item: Shop.Item, data: any): (string, boolean, () -> ())
	local shop = if data then data.Shop else nil
	if item.Kind == "Pass" then
		if shop and shop.SpringBoots then
			local on = shop.SpringOn
			return L(if on then "Shop.Spring.On" else "Shop.Spring.Off"),
				true,
				function()
					Net.fireServer("SetSpring", not on)
				end
		end
	elseif item.Kind == "Trail" or item.Kind == "Finish" then
		if shop and shop.Owned[item.Id] then
			local equipped = (item.Kind == "Trail" and shop.Trail == item.Id)
				or (item.Kind == "Finish" and shop.Finish == item.Id)
			return L(if equipped then "Shop.Equipped" else "Shop.Equip"),
				true,
				function()
					if equipped then
						Net.fireServer(
							"EquipCosmetic",
							if item.Kind == "Trail" then Shop.ClearTrail else Shop.ClearFinish
						)
					else
						Net.fireServer("EquipCosmetic", item.Id)
					end
				end
		end
	end
	if item.RobloxId == 0 then
		return L("Shop.Soon"), false, function() end
	end
	return L("Shop.Buy"), true, function()
		prompt(item)
	end
end

local function render()
	local u = ui
	if u == nil then
		return
	end
	local data = snapshot()
	u.open.Text = L("Shop.Button")
	u.title.Text = L("Shop.Title")
	u.note.Text = L("Shop.Note")
	u.close.Text = L("UI.Close")
	local tokens = if data then data.Shop.SkipTokens else 0
	u.skip.Visible = running
	u.skip.Text = L("Shop.Skip.Button", { count = tokens })
	for _, item in Shop.Items do
		local row = rows[item.Id]
		if row then
			row.name.Text = nameOf(item, data)
			local text, enabled = actionFor(item, data)
			row.action.Text = text
			Components.setEnabled(row.action, enabled)
		end
	end
end

local function buildRow(list: ScrollingFrame, item: Shop.Item, order: number)
	local frame = Components.panel({
		Name = item.Id,
		Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
		LayoutOrder = order,
		BackgroundColor3 = Components.Theme.PanelDark,
		ZIndex = 41,
		Parent = list,
	})
	local name = Components.label({
		Size = UDim2.new(1, -160, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		ZIndex = 42,
		Parent = frame,
	})
	local action = Components.button({
		Size = UDim2.fromOffset(140, 42),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		MaxTextSize = 20,
		ZIndex = 42,
		Parent = frame,
	}, function()
		local _, enabled, run = actionFor(item, snapshot())
		if enabled then
			run()
		end
	end)
	rows[item.Id] = { frame = frame, name = name, action = action }
end

local function build(canvas: Frame): Ui
	local open = Components.button({
		Name = "ShopButton",
		Size = UDim2.fromOffset(120, 52),
		Position = UDim2.new(0, 12, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 20,
		Parent = canvas,
	}, function()
		ShopController:Toggle()
	end)
	local skip = Components.button({
		Name = "SkipButton",
		Size = UDim2.fromOffset(170, 52),
		Position = UDim2.new(0, 140, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Components.Theme.Good,
		Visible = false,
		ZIndex = 20,
		Parent = canvas,
	}, function()
		local data = snapshot()
		if data and data.Shop.SkipTokens > 0 then
			Net.fireServer("UseSkip")
		else
			local item = Shop.ById.skip
			if item.RobloxId == 0 then
				UIController:Toast("Shop.Skip.None")
			else
				prompt(item)
			end
		end
	end)
	local frame = Components.panel({
		Name = "ShopMenu",
		Size = UDim2.fromOffset(500, 340),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 40,
		Parent = canvas,
	})
	local title = Components.label({
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.fromOffset(12, 8),
		MaxTextSize = 30,
		ZIndex = 41,
		Parent = frame,
	})
	local note = Components.label({
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 44),
		MaxTextSize = 16,
		ZIndex = 41,
		Parent = frame,
	})
	local list = Instance.new("ScrollingFrame")
	list.Name = "Items"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, -24, 1, -150)
	list.Position = UDim2.fromOffset(12, 78)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.ZIndex = 41
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local close = Components.button({
		Size = UDim2.fromOffset(160, 52),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Components.Theme.Muted,
		ZIndex = 41,
		Parent = frame,
	}, function()
		frame.Visible = false
	end)
	for order, item in Shop.Items do
		buildRow(list, item, order)
	end
	return { open = open, skip = skip, frame = frame, title = title, note = note, list = list, close = close }
end

function ShopController:Init()
	DataController.Changed:Connect(render)
	LocalizationController.Changed:Connect(render)
	DashController.Event:Connect(function(event)
		local kind = event.kind
		if kind == "start" then
			running = true
		elseif kind == "finish" or kind == "abandon" or kind == "cancel" then
			running = false
		end
		render()
	end)
end

function ShopController:Start()
	ui = build(UIController:GetCanvas())
	render()
end

function ShopController:Toggle()
	local u = ui
	if u then
		u.frame.Visible = not u.frame.Visible
		if u.frame.Visible then
			Juice.pop(u.frame, 0.85, 0.3)
		end
		render()
	end
end

return ShopController
