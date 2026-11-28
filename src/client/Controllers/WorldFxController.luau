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

-- The golden trophy: a plinth, a stem, a cup built from stacked discs, ball-chain handles and a star on
-- the front. The plinth stands still; the cup turns slowly with a soft glow and a few sparkles.
type TrophyPart = { part: Part, offset: CFrame }

local trophyTurning: { TrophyPart } = {}
local trophyBase: CFrame? = nil

local GOLD = Color3.fromRGB(255, 200, 60)
local GOLD_DARK = Color3.fromRGB(200, 140, 30)
local NAVY = Color3.fromRGB(30, 36, 80)

local function trophyPart(
	folder: Folder,
	shape: Enum.PartType?,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = folder
	return part
end

local function poseTrophy(angle: number)
	local base = trophyBase
	if base == nil then
		return
	end
	local turn = base * CFrame.Angles(0, angle, 0)
	for _, entry in trophyTurning do
		entry.part.CFrame = turn * entry.offset
	end
end

local function buildTrophy(anchor: BasePart)
	local folder = Instance.new("Folder")
	folder.Name = "Trophy"
	folder.Parent = Workspace
	local origin = CFrame.new(anchor.Position.X, anchor.Position.Y, anchor.Position.Z)
	trophyBase = origin
	-- Everything below is in anchor space (y up from the floor). A cylinder's axis is X, so it is turned upright.
	local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

	local function still(size: Vector3, y: number, color: Color3, material: Enum.Material)
		local p = trophyPart(folder, nil, size, color, material)
		p.CFrame = origin * CFrame.new(0, y, 0)
		p.CanCollide = true
		return p
	end
	local function turning(part: Part, offset: CFrame)
		table.insert(trophyTurning, { part = part, offset = offset })
	end
	local function disc(diameter: number, height: number, y: number, color: Color3, material: Enum.Material?)
		local p = trophyPart(
			folder,
			Enum.PartType.Cylinder,
			Vector3.new(height, diameter, diameter),
			color,
			material or Enum.Material.Metal
		)
		turning(p, CFrame.new(0, y, 0) * UPRIGHT)
		return p
	end

	-- Plinth: two tiers with a glowing gold trim.
	still(Vector3.new(8, 1.2, 8), 0.6, NAVY, Enum.Material.SmoothPlastic)
	still(Vector3.new(8.3, 0.25, 8.3), 1.25, GOLD, Enum.Material.Neon).CanCollide = false
	still(Vector3.new(5.6, 1.0, 5.6), 1.85, GOLD_DARK, Enum.Material.Metal)
	-- Foot, stem and rings (turning, though they look the same from every side).
	disc(3.6, 0.5, 2.6, GOLD)
	disc(2.4, 0.35, 3.0, GOLD_DARK)
	disc(1.3, 3.0, 4.6, GOLD)
	disc(2.2, 0.35, 6.2, GOLD_DARK)
	-- Cup: a bowl of stacked discs that widen towards the rim.
	disc(3.0, 0.8, 6.8, GOLD)
	disc(4.4, 0.9, 7.6, GOLD)
	disc(5.4, 1.0, 8.5, GOLD)
	disc(6.0, 1.2, 9.6, GOLD)
	disc(6.3, 1.2, 10.8, GOLD)
	disc(6.8, 0.4, 11.6, Color3.fromRGB(255, 235, 140), Enum.Material.Neon)
	disc(5.9, 0.1, 11.45, Color3.fromRGB(120, 70, 20), Enum.Material.SmoothPlastic)
	-- Handles: a chain of gold balls on a half circle at each side.
	for _, side in { -1, 1 } do
		for angle = -75, 75, 30 do
			local a = math.rad(angle)
			local ball =
				trophyPart(folder, Enum.PartType.Ball, Vector3.new(0.75, 0.75, 0.75), GOLD, Enum.Material.Metal)
			turning(ball, CFrame.new(side * (3.0 + 1.5 * math.cos(a)), 9.7 + 1.5 * math.sin(a), 0))
		end
	end
	-- A star on the front of the cup: five crossing bars.
	for i = 0, 4 do
		local bar =
			trophyPart(folder, nil, Vector3.new(2.0, 0.42, 0.18), Color3.fromRGB(255, 250, 200), Enum.Material.Neon)
		turning(bar, CFrame.new(0, 9.6, -3.12) * CFrame.Angles(0, 0, math.rad(i * 36)))
	end

	-- A soft glow around the cup and a few sparkles rising from the rim.
	local glowPart = trophyPart(folder, nil, Vector3.new(1, 1, 1), GOLD, Enum.Material.SmoothPlastic)
	glowPart.Transparency = 1
	glowPart.CFrame = origin * CFrame.new(0, 10, 0)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 130)
	light.Brightness = 1.6
	light.Range = 26
	light.Shadows = false
	light.Parent = glowPart
	local spark = trophyPart(folder, nil, Vector3.new(4, 0.2, 4), GOLD, Enum.Material.SmoothPlastic)
	spark.Transparency = 1
	spark.CFrame = origin * CFrame.new(0, 11.8, 0)
	sparkles(spark)
	poseTrophy(0)
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
	elseif kind == "Trophy" then
		buildTrophy(instance)
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
		poseTrophy(t * 0.5)
		for _, spinner in spinners do
			local angle = math.rad(spinner.speed * t + spinner.offset)
			spinner.part.CFrame = spinner.base * CFrame.Angles(0, angle, 0)
		end
	end)
end

return WorldFxController
