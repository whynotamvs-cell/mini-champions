--!strict
-- Tutorial guidance: a "Step n/5" banner with the hint for the saved Tutorial.Step, a pulsing
-- outline on the button to press and a glow on the pad to run to. Display only: progress is
-- decided by the server. The one thing sent back is the "I opened the club menu" ack (step 3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TutorialHints = require(ReplicatedStorage.Shared.Utilities.TutorialHints)
local Components = require(script.Parent.Parent.UI.Components)
local Juice = require(script.Parent.Parent.UI.Juice)
local Net = require(script.Parent.Parent.Net)
local ClubMenuController = require(script.Parent.ClubMenuController)
local DataController = require(script.Parent.DataController)
local LocalizationController = require(script.Parent.LocalizationController)
local UIController = require(script.Parent.UIController)

local L = LocalizationController.L
local Theme = Components.Theme

local OPENED_CLUB_STEP = 3
local GLOW_COLOR = Color3.fromRGB(255, 240, 120)

local TutorialController = {}

type Banner = {
	frame: Frame,
	step: TextLabel,
	hint: TextLabel,
}

local banner: Banner? = nil
local current: TutorialHints.Hint? = nil
local lastStep = -1
local lastAckedAt = 0
local pulse: UIStroke? = nil
local glow: Highlight? = nil

local function clearEmphasis()
	if pulse then
		pulse:Destroy()
		pulse = nil
	end
	if glow then
		glow:Destroy()
		glow = nil
	end
end

-- Pulsing outline around a UI button; a steady outline when motion is reduced.
local function pulseButton(button: GuiObject)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TutorialPulse"
	stroke.Color = GLOW_COLOR
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 4
	stroke.Parent = button
	pulse = stroke
	if not Juice.isReducedMotion() then
		stroke.Thickness = 1
		TweenService:Create(
			stroke,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Thickness = 6 }
		):Play()
	end
end

-- Glow on a world part that shows through walls, so the player can find the pad.
local function glowPart(path: { string })
	local node: Instance? = Workspace
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	if node == nil or not node:IsA("BasePart") then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "TutorialGlow"
	highlight.FillColor = GLOW_COLOR
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.45
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = node
	highlight.Parent = node
	glow = highlight
	if not Juice.isReducedMotion() then
		TweenService:Create(
			highlight,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ FillTransparency = 0.85 }
		):Play()
	end
end

local function findButton(name: string): GuiObject?
	local canvas = UIController:GetCanvas()
	local found = canvas:FindFirstChild(name, true)
	return if found and found:IsA("GuiObject") then found else nil
end

local function emphasize(hint: TutorialHints.Hint?)
	clearEmphasis()
	if hint == nil then
		return
	end
	if hint.target == "ClubButton" then
		local button = findButton("ClubButton")
		if button then
			pulseButton(button)
		end
	elseif hint.target == "BuyButton" then
		local button = findButton("BuyButton")
		if button then
			pulseButton(button)
		end
	elseif hint.target == "StartPad" then
		glowPart({ "DeskWorld", "DeskDash", "Geometry", "StartPad" })
	elseif hint.target == "FinishPad" then
		glowPart({ "DeskWorld", "DeskDash", "Geometry", "FinishPad" })
	end
end

local function render()
	local b = banner
	if b == nil then
		return
	end
	local hint = current
	b.frame.Visible = hint ~= nil
	if hint then
		b.step.Text = L("Tutorial.Step", { step = hint.number, total = hint.total })
		b.hint.Text = L(hint.key)
	end
end

local function onSnapshot(snapshot: { [string]: any })
	local tutorial = snapshot.Tutorial
	if type(tutorial) ~= "table" then
		return
	end
	local hint = TutorialHints.forProgress(tutorial.Step, tutorial.Completed == true)
	local newStep = if hint then hint.number else TutorialHints.Total + 1
	current = hint
	if newStep ~= lastStep then
		lastStep = newStep
		emphasize(hint)
		if banner and hint then
			Juice.pop(banner.frame, 1.12, 0.35)
		end
	end
	render()
end

local function build(canvas: Frame): Banner
	local frame = Components.panel({
		Name = "TutorialBanner",
		Size = UDim2.fromOffset(330, 84),
		Position = UDim2.fromOffset(12, 88),
		Visible = false,
		ZIndex = 10,
		Parent = canvas,
	})
	frame.BackgroundColor3 = Color3.fromRGB(255, 247, 214)
	local step = Components.label({
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.AccentDark,
		ZIndex = 11,
		MaxTextSize = 16,
		Parent = frame,
	})
	local hint = Components.label({
		Size = UDim2.new(1, -16, 1, -28),
		Position = UDim2.fromOffset(8, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		MaxTextSize = 20,
		TextWrapped = true,
		Parent = frame,
	})
	return { frame = frame, step = step, hint = hint }
end

function TutorialController:Init()
	DataController.Changed:Connect(onSnapshot)
	LocalizationController.Changed:Connect(render)
	ClubMenuController.Opened:Connect(function()
		-- Only matters while the hint says "open the club"; the server re-checks the step.
		local hint = current
		if hint and hint.target == "ClubButton" and os.clock() - lastAckedAt > 1 then
			lastAckedAt = os.clock()
			Net.fireServer("TutorialAck", OPENED_CLUB_STEP)
		end
	end)
end

function TutorialController:Start()
	banner = build(UIController:GetCanvas())
	local snapshot = DataController:Get()
	if snapshot then
		onSnapshot(snapshot :: any)
	end
	-- Buttons may not have existed when the first snapshot arrived.
	emphasize(current)
	render()
end

return TutorialController
