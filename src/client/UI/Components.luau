--!strict
-- UI building blocks, Mobile First (docs/ARCHITECTURE.md 11). Sizes are in the 844x390 base
-- layout; UIController scales the whole screen. Text is always set by code (AutoLocalize off).

local Juice = require(script.Parent.Juice)

local Components = {}

Components.Theme = table.freeze({
	Font = Enum.Font.GothamBold,
	Text = Color3.fromRGB(35, 35, 40),
	TextLight = Color3.fromRGB(255, 255, 255),
	Panel = Color3.fromRGB(250, 246, 236),
	PanelStroke = Color3.fromRGB(90, 70, 50),
	Accent = Color3.fromRGB(255, 196, 64),
	AccentDark = Color3.fromRGB(150, 105, 20),
	Good = Color3.fromRGB(80, 170, 95),
	Muted = Color3.fromRGB(160, 160, 165),
	Shade = Color3.fromRGB(20, 20, 25),
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
	stroke.Color = Theme.AccentDark
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
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
	corner(frame, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.PanelStroke
	stroke.Thickness = 2
	stroke.Parent = frame
	return frame
end

function Components.setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then Theme.Accent else Theme.Muted
end

return Components
