--!strict
-- Living decor in the world: the welcome sign gets its title, gateways sparkle, trophies spin,
-- dust drifts under the lamps. Everything is client-side and cosmetic; parts are marked in the
-- world model by attributes (FxKind, Spin) written by tools/gen_world.py.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Juice = require(script.Parent.Parent.UI.Juice)
local LocalizationController = require(script.Parent.LocalizationController)

local L = LocalizationController.L

local WorldFxController = {}

type Spinner = { part: BasePart, base: CFrame, speed: number, offset: number }

local spinners: { Spinner } = {}
local titleLabels: { TextLabel } = {}
local subtitleLabels: { TextLabel } = {}

local function sparkles(part: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 7
	emitter.Lifetime = NumberRange.new(1.2, 2)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -2, 0)
	emitter.LightEmission = 0.8
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 190, 60))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = part
end

local function dressLogoSign(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 10
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = part
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.BorderSizePixel = 0
	back.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 20
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 40)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 70, 130)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 70, 200)),
	})
	gradient.Parent = back
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 40)
	corner.Parent = back
	local rim = Instance.new("UIStroke")
	rim.Color = Color3.fromRGB(255, 220, 90)
	rim.Thickness = 4
	rim.Parent = back
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0.92, 0.55)
	title.Position = UDim2.fromScale(0.04, 0.1)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.AutoLocalize = false
	title.TextColor3 = Color3.fromRGB(255, 235, 120)
	title.Text = ""
	title.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(18, 20, 50)
	stroke.Thickness = 4
	stroke.Parent = title
	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Size = UDim2.fromScale(0.8, 0.22)
	subtitle.Position = UDim2.fromScale(0.1, 0.68)
	subtitle.Font = Enum.Font.FredokaOne
	subtitle.TextScaled = true
	subtitle.AutoLocalize = false
	subtitle.TextColor3 = Color3.new(1, 1, 1)
	subtitle.Text = ""
	subtitle.Parent = back
	local subStroke = Instance.new("UIStroke")
	subStroke.Color = Color3.fromRGB(18, 20, 50)
	subStroke.Thickness = 3
	subStroke.Parent = subtitle
	table.insert(titleLabels, title)
	table.insert(subtitleLabels, subtitle)
end

local function refreshTexts()
	for _, label in titleLabels do
		label.Text = L("Game.Title")
	end
	for _, label in subtitleLabels do
		label.Text = L("Loading.Tagline")
	end
end

local function dress(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local kind = instance:GetAttribute("FxKind")
	if kind == "LogoSign" then
		dressLogoSign(instance)
		refreshTexts()
	elseif kind == "Sparkle" then
		sparkles(instance)
	end
	local speed = instance:GetAttribute("Spin")
	if type(speed) == "number" then
		table.insert(spinners, {
			part = instance,
			base = instance.CFrame,
			speed = speed,
			offset = tonumber(instance:GetAttribute("SpinOffset")) or 0,
		})
	end
end

function WorldFxController:Init()
	LocalizationController.Changed:Connect(refreshTexts)
end

function WorldFxController:Start()
	local deskWorld = Workspace:WaitForChild("DeskWorld", 30)
	if deskWorld == nil then
		return
	end
	for _, descendant in deskWorld:GetDescendants() do
		dress(descendant)
	end
	deskWorld.DescendantAdded:Connect(dress)
	RunService.RenderStepped:Connect(function()
		if Juice.isReducedMotion() then
			return
		end
		local t = os.clock()
		for _, spinner in spinners do
			local angle = math.rad(spinner.speed * t + spinner.offset)
			spinner.part.CFrame = spinner.base * CFrame.Angles(0, angle, 0)
		end
	end)
end

return WorldFxController
