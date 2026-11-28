--!strict
-- UI building blocks, Mobile First (docs/ARCHITECTURE.md 11). Sizes are in the 844x390 base
-- layout; UIController scales the whole screen. Text is always set by code (AutoLocalize off).

local Juice = require(script.Parent.Juice)

local Components = {}

-- Chunky "popular Roblox game" look: rounded font, saturated colours, thick dark outlines,
-- glossy gradient buttons, deep blue panels with a gold rim, white text with a dark stroke.
Components.Theme = table.freeze({
	Font = Enum.Font.FredokaOne,
	Text = Color3.fromRGB(255, 255, 255),
	TextLight = Color3.fromRGB(255, 255, 255),
	TextStroke = Color3.fromRGB(18, 20, 50),
	Panel = Color3.fromRGB(40, 52, 108),
	PanelDark = Color3.fromRGB(22, 28, 68),
	PanelStroke = Color3.fromRGB(255, 205, 70),
	Outline = Color3.fromRGB(18, 20, 50),
	Accent = Color3.fromRGB(255, 176, 36),
	AccentDark = Color3.fromRGB(255, 226, 120),
	Good = Color3.fromRGB(64, 200, 104),
	Bad = Color3.fromRGB(235, 70, 80),
	Blue = Color3.fromRGB(58, 150, 255),
	Muted = Color3.fromRGB(112, 120, 160),
	Shade = Color3.fromRGB(16, 18, 40),
	MinTextSize = 14,
	MinButton = 48,
})

local Theme = Components.Theme

-- Star icon (a text symbol, not an emoji) shown next to every amount instead of a plural noun.
Components.STAR = "★"

local function apply(instance: Instance, props: { [string]: any })
	for key, value in props do
		if key ~= "Parent" and key ~= "MaxTextSize" then
			(instance :: any)[key] = value
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function textSize(parent: Instance, max: number?)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = Theme.MinTextSize
	c.MaxTextSize = max or 32
	c.Parent = parent
end

function Components.label(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.Font
	label.TextColor3 = Theme.Text
	label.TextStrokeColor3 = Theme.TextStroke
	label.TextStrokeTransparency = 0.25
	label.TextScaled = true
	label.AutoLocalize = false
	label.Text = ""
	apply(label, props)
	textSize(label, props.MaxTextSize)
	return label
end

function Components.button(props: { [string]: any }, onActivated: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Theme.Accent
	button.Font = Theme.Font
	button.TextColor3 = Theme.Text
	button.TextStrokeColor3 = Theme.TextStroke
	button.TextStrokeTransparency = 0.2
	button.TextScaled = true
	button.AutoLocalize = false
	button.AutoButtonColor = true
	button.Selectable = true -- gamepad navigation later (ARCHITECTURE.md 11)
	button.Text = ""
	apply(button, props)
	corner(button, 10)
	textSize(button, props.MaxTextSize or 26)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = button
	local min = Instance.new("UISizeConstraint")
	min.MinSize = Vector2.new(Theme.MinButton, Theme.MinButton)
	min.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Outline
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	-- The gradient multiplies the button colour: lighter on top, darker at the bottom edge.
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Shine"
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(235, 235, 235)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(165, 165, 175)),
	})
	gradient.Parent = button
	-- A soft highlight across the top: the glossy "candy" look.
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.88
	gloss.BorderSizePixel = 0
	gloss.Size = UDim2.new(1, -10, 0.38, 0)
	gloss.Position = UDim2.fromOffset(5, 3)
	gloss.Active = false
	gloss.ZIndex = button.ZIndex
	gloss.Parent = button
	corner(gloss, 8)
	button.Activated:Connect(function()
		Juice.pop(button, 0.92, 0.2) -- press feedback
		onActivated()
	end)
	return button
end

function Components.panel(props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Theme.Panel
	frame.BorderSizePixel = 0
	apply(frame, props)
	corner(frame, 16)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.PanelStroke
	stroke.Thickness = 3
	stroke.Parent = frame
	-- Deep blue, a little lighter at the top.
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Depth"
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 195, 225)),
	})
	gradient.Parent = frame
	return frame
end

function Components.setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then Theme.Accent else Theme.Muted
	button.TextTransparency = if enabled then 0 else 0.25
end

return Components
