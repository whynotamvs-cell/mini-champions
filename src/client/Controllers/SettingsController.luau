--!strict
-- Settings screen: music and sound volume, language (Auto / English / Русский) and reduced motion.
-- The client only sends the changed keys (debounced); the server validates and saves, then the
-- next snapshot is what is really stored. Volumes drive the "Music" and "Sfx" SoundGroups that
-- future sounds are routed through; reduced motion switches the cosmetic animations off.
-- Labels wrap and the opener caps its font so Russian text never breaks mid-word (L-05).

local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Components = require(script.Parent.Parent.UI.Components)
local Juice = require(script.Parent.Parent.UI.Juice)
local Net = require(script.Parent.Parent.Net)
local DataController = require(script.Parent.DataController)
local LocalizationController = require(script.Parent.LocalizationController)
local UIController = require(script.Parent.UIController)

local L = LocalizationController.L
local Theme = Components.Theme

local VOLUME_STEP = 0.1
local SEND_DELAY_SEC = 0.5
local LANGUAGES = { "auto", "en", "ru" }
local LANGUAGE_KEYS: { [string]: string } = {
	auto = "Settings.LanguageAuto",
	en = "Settings.LanguageEn",
	ru = "Settings.LanguageRu",
}

local SettingsController = {}

type Draft = {
	MusicVolume: number,
	SfxVolume: number,
	Language: string,
	ReducedMotion: boolean,
	ShowPets: boolean,
}

type Ui = {
	frame: Frame,
	title: TextLabel,
	openButton: TextButton,
	musicLabel: TextLabel,
	musicValue: TextLabel,
	sfxLabel: TextLabel,
	sfxValue: TextLabel,
	languageLabel: TextLabel,
	languageButton: TextButton,
	motionLabel: TextLabel,
	motionButton: TextButton,
	petsLabel: TextLabel,
	petsButton: TextButton,
	close: TextButton,
}

local ui: Ui? = nil
local draft: Draft? = nil
local dirty: { [string]: boolean } = {}
local sendToken = 0

local function roundVolume(value: number): number
	return math.clamp(math.floor(value * 10 + 0.5) / 10, 0, 1)
end

local function soundGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = SoundService
	return group
end

-- Applies a settings table to the local engine state (sound groups, reduced motion).
local function applyLocal(settings: Draft)
	soundGroup("Music").Volume = settings.MusicVolume
	soundGroup("Sfx").Volume = settings.SfxVolume
	Juice.setReducedMotion(settings.ReducedMotion)
end

local function render()
	local u = ui
	local d = draft
	if u == nil then
		return
	end
	u.title.Text = L("Settings.Title")
	u.openButton.Text = L("HUD.Settings")
	u.musicLabel.Text = L("Settings.Music")
	u.sfxLabel.Text = L("Settings.Sfx")
	u.languageLabel.Text = L("Settings.Language")
	u.motionLabel.Text = L("Settings.ReducedMotion")
	u.petsLabel.Text = L("Settings.ShowPets")
	u.close.Text = L("UI.Close")
	if d then
		u.musicValue.Text = `{math.floor(d.MusicVolume * 100 + 0.5)}%`
		u.sfxValue.Text = `{math.floor(d.SfxVolume * 100 + 0.5)}%`
		u.languageButton.Text = L(LANGUAGE_KEYS[d.Language] or LANGUAGE_KEYS.auto)
		u.motionButton.Text = L(if d.ReducedMotion then "Settings.On" else "Settings.Off")
		u.motionButton.BackgroundColor3 = if d.ReducedMotion then Theme.Good else Theme.Muted
		u.petsButton.Text = L(if d.ShowPets then "Settings.On" else "Settings.Off")
		u.petsButton.BackgroundColor3 = if d.ShowPets then Theme.Good else Theme.Muted
	end
end

local function flush()
	local d = draft
	if d == nil or next(dirty) == nil then
		return
	end
	local payload: { [string]: any } = {}
	for key in dirty do
		payload[key] = (d :: any)[key]
	end
	dirty = {}
	Net.fireServer("UpdateSettings", payload)
end

local function change(key: string, value: any)
	local d = draft
	if d == nil then
		return
	end
	(d :: any)[key] = value
	dirty[key] = true
	applyLocal(d)
	render()
	sendToken += 1
	local token = sendToken
	task.delay(SEND_DELAY_SEC, function()
		if token == sendToken then
			flush()
		end
	end)
end

-- Fresh server data: keys without a pending local edit follow the server value.
local function onSnapshot(snapshot: { [string]: any })
	local settings = snapshot.Settings
	if type(settings) ~= "table" then
		return
	end
	if draft == nil then
		draft = {
			MusicVolume = settings.MusicVolume,
			SfxVolume = settings.SfxVolume,
			Language = settings.Language,
			ReducedMotion = settings.ReducedMotion,
			ShowPets = settings.ShowPets ~= false,
		}
	else
		for _, key in { "MusicVolume", "SfxVolume", "Language", "ReducedMotion", "ShowPets" } do
			if not dirty[key] then
				(draft :: any)[key] = settings[key]
			end
		end
	end
	applyLocal(draft :: Draft)
	render()
end

local function nextLanguage(current: string): string
	for i, language in LANGUAGES do
		if language == current then
			return LANGUAGES[i % #LANGUAGES + 1]
		end
	end
	return LANGUAGES[1]
end

local function build(canvas: Frame): Ui
	local frame = Components.panel({
		Name = "SettingsMenu",
		Size = UDim2.fromOffset(380, 362),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 32,
		Parent = canvas,
	})
	local function label(x: number, y: number, width: number, height: number, max: number): TextLabel
		return Components.label({
			Size = UDim2.fromOffset(width, height),
			Position = UDim2.fromOffset(x, y),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true, -- long Russian labels use a second line instead of overflowing
			ZIndex = 33,
			MaxTextSize = max,
			Parent = frame,
		})
	end
	local function small(x: number, y: number, text: string, onActivated: () -> ()): TextButton
		local button = Components.button({
			Size = UDim2.fromOffset(48, 48),
			Position = UDim2.fromOffset(x, y),
			ZIndex = 33,
			Parent = frame,
		}, onActivated)
		button.Text = text
		return button
	end

	local title = Components.label({
		Size = UDim2.new(1, -24, 0, 36),
		Position = UDim2.fromOffset(12, 8),
		ZIndex = 33,
		MaxTextSize = 30,
		Parent = frame,
	})

	local function volumeRow(y: number, key: string): (TextLabel, TextLabel)
		local name = label(14, y, 128, 48, 22)
		small(146, y, "-", function()
			local d = draft
			if d then
				change(key, roundVolume((d :: any)[key] - VOLUME_STEP))
			end
		end)
		local value = Components.label({
			Size = UDim2.fromOffset(72, 48),
			Position = UDim2.fromOffset(198, y),
			ZIndex = 33,
			MaxTextSize = 24,
			Parent = frame,
		})
		small(274, y, "+", function()
			local d = draft
			if d then
				change(key, roundVolume((d :: any)[key] + VOLUME_STEP))
			end
		end)
		return name, value
	end
	local musicLabel, musicValue = volumeRow(50, "MusicVolume")
	local sfxLabel, sfxValue = volumeRow(100, "SfxVolume")

	local languageLabel = label(14, 150, 128, 48, 22)
	local languageButton = Components.button({
		Size = UDim2.fromOffset(212, 48),
		Position = UDim2.fromOffset(146, 150),
		ZIndex = 33,
		Parent = frame,
	}, function()
		local d = draft
		if d then
			change("Language", nextLanguage(d.Language))
		end
	end)

	local motionLabel = label(14, 200, 128, 48, 20)
	local motionButton = Components.button({
		Size = UDim2.fromOffset(212, 48),
		Position = UDim2.fromOffset(146, 200),
		ZIndex = 33,
		Parent = frame,
	}, function()
		local d = draft
		if d then
			change("ReducedMotion", not d.ReducedMotion)
		end
	end)

	local petsLabel = label(14, 250, 128, 48, 20)
	local petsButton = Components.button({
		Size = UDim2.fromOffset(212, 48),
		Position = UDim2.fromOffset(146, 250),
		ZIndex = 33,
		Parent = frame,
	}, function()
		local d = draft
		if d then
			change("ShowPets", not d.ShowPets)
		end
	end)

	local close = Components.button({
		Size = UDim2.fromOffset(150, 48),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.Muted,
		ZIndex = 33,
		Parent = frame,
	}, function()
		frame.Visible = false
	end)

	local openButton = Components.button({
		Name = "SettingsButton",
		Size = UDim2.fromOffset(130, 48),
		Position = UDim2.new(1, -12, 0.42, -64),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Muted,
		MaxTextSize = 18, -- a smaller cap keeps "Настройки" on one line instead of breaking mid-word
		Parent = canvas,
	}, function()
		SettingsController:Toggle()
	end)

	return {
		frame = frame,
		title = title,
		openButton = openButton,
		musicLabel = musicLabel,
		musicValue = musicValue,
		sfxLabel = sfxLabel,
		sfxValue = sfxValue,
		languageLabel = languageLabel,
		languageButton = languageButton,
		motionLabel = motionLabel,
		motionButton = motionButton,
		petsLabel = petsLabel,
		petsButton = petsButton,
		close = close,
	}
end

function SettingsController:Init()
	DataController.Changed:Connect(onSnapshot)
	LocalizationController.Changed:Connect(render)
end

function SettingsController:Start()
	ui = build(UIController:GetCanvas())
	local snapshot = DataController:Get()
	if snapshot then
		onSnapshot(snapshot :: any)
	end
	render()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape and ui then
			ui.frame.Visible = false
		end
	end)
end

function SettingsController:Toggle()
	local u = ui
	if u then
		u.frame.Visible = not u.frame.Visible
		if u.frame.Visible then
			Juice.pop(u.frame, 0.85, 0.3)
		end
		render()
	end
end

return SettingsController
