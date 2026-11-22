--!strict
-- Emote panel and the bubbles above players' heads (docs/ARCHITECTURE.md 7). The player picks one
-- of the preset emotes; only its ID goes to the server. Every client draws the bubble with the
-- text in its own language, so no text from other players is ever shown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Emotes = require(ReplicatedStorage.Shared.Config.Emotes)
local Components = require(script.Parent.Parent.UI.Components)
local Juice = require(script.Parent.Parent.UI.Juice)
local Net = require(script.Parent.Parent.Net)
local LocalizationController = require(script.Parent.LocalizationController)
local UIController = require(script.Parent.UIController)

local L = LocalizationController.L
local Theme = Components.Theme

local EmoteController = {}

type Ui = {
	frame: Frame,
	title: TextLabel,
	openButton: TextButton,
	buttons: { [string]: TextButton },
}

local ui: Ui? = nil
local cooldownUntil = 0

local function colorOf(item: Emotes.Emote): Color3
	local rgb = item.Color
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function render()
	local u = ui
	if u == nil then
		return
	end
	u.title.Text = L("Emote.Title")
	u.openButton.Text = L("HUD.Emotes")
	for _, item in Emotes.Items do
		local button = u.buttons[item.Id]
		if button then
			button.Text = L(item.Key)
		end
	end
end

local function setCooldown(active: boolean)
	local u = ui
	if u == nil then
		return
	end
	for _, item in Emotes.Items do
		local button = u.buttons[item.Id]
		if button then
			button.Active = not active
			button.AutoButtonColor = not active
			button.BackgroundColor3 = if active then Theme.Muted else colorOf(item)
		end
	end
end

local function send(emoteId: string)
	if os.clock() < cooldownUntil then
		return
	end
	cooldownUntil = os.clock() + Emotes.CooldownSec
	Net.fireServer("SendEmote", emoteId)
	if ui then
		ui.frame.Visible = false
	end
	setCooldown(true)
	task.delay(Emotes.CooldownSec, function()
		setCooldown(false)
	end)
end

-- Bubble above a character's head; replaces the previous one of the same player.
local function showBubble(userId: number, emoteId: string)
	local item = Emotes.ById[emoteId]
	local player = Players:GetPlayerByUserId(userId)
	local head = player and player.Character and player.Character:FindFirstChild("Head")
	if item == nil or head == nil or not head:IsA("BasePart") then
		return
	end
	local old = head:FindFirstChild("EmoteBubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "EmoteBubble"
	gui.Size = UDim2.fromOffset(170, 52)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 140
	gui.AlwaysOnTop = false
	gui.Adornee = head
	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.AnchorPoint = Vector2.new(0.5, 0.5)
	bubble.Position = UDim2.fromScale(0.5, 0.5)
	bubble.BackgroundColor3 = colorOf(item)
	bubble.BorderSizePixel = 0
	bubble.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = bubble
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.PanelStroke
	stroke.Thickness = 2
	stroke.Parent = bubble
	local text = Components.label({
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		Text = L(item.Key),
		MaxTextSize = 28,
		Parent = bubble,
	})
	text.TextColor3 = Theme.Text
	gui.Parent = head
	Juice.pop(bubble, 0.5, 0.35)
	task.delay(Emotes.ShowSec, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

local function build(canvas: Frame): Ui
	local frame = Components.panel({
		Name = "EmotePanel",
		Size = UDim2.fromOffset(380, 220),
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
	local buttons: { [string]: TextButton } = {}
	for i, item in Emotes.Items do
		local column = (i - 1) % 3
		local row = (i - 1) // 3
		local button = Components.button({
			Size = UDim2.fromOffset(112, 56),
			Position = UDim2.fromOffset(12 + column * 122, 50 + row * 64),
			BackgroundColor3 = colorOf(item),
			MaxTextSize = 20,
			ZIndex = 32,
			Parent = frame,
		}, function()
			send(item.Id)
		end)
		buttons[item.Id] = button
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
	close.Name = "Close"

	local openButton = Components.button({
		Name = "EmoteButton",
		Size = UDim2.fromOffset(110, 48),
		Position = UDim2.new(1, -12, 0.42, -62),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = canvas,
	}, function()
		EmoteController:Toggle()
	end)

	return { frame = frame, title = title, openButton = openButton, buttons = buttons }
end

function EmoteController:Init()
	LocalizationController.Changed:Connect(function()
		render()
		local u = ui
		if u then
			local close = u.frame:FindFirstChild("Close")
			if close and close:IsA("TextButton") then
				close.Text = L("UI.Close")
			end
		end
	end)
end

function EmoteController:Start()
	ui = build(UIController:GetCanvas())
	render()
	local close = (ui :: Ui).frame:FindFirstChild("Close")
	if close and close:IsA("TextButton") then
		close.Text = L("UI.Close")
	end
	Net.onClientEvent("EmoteShown", function(userId: any, emoteId: any)
		if type(userId) == "number" and type(emoteId) == "string" then
			showBubble(userId, emoteId)
		end
	end)
	-- PC hotkeys (ARCHITECTURE.md 11): E toggles the emote panel, Escape closes it.
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			EmoteController:Toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and ui then
			ui.frame.Visible = false
		end
	end)
end

function EmoteController:Toggle()
	local u = ui
	if u then
		u.frame.Visible = not u.frame.Visible
		if u.frame.Visible then
			Juice.pop(u.frame, 0.85, 0.3)
		end
		render()
	end
end

return EmoteController
