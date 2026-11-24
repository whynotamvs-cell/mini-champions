--!nonstrict
-- Measures every UI string in Russian at the smallest font the UI can end up with (Theme.MinTextSize
-- 14 at the smallest UIScale 0.75) against the layout size of the element that shows it (TEST_PLAN L-05).
--
-- Run it in Studio during Play, in the CLIENT command bar (or via MCP execute_luau, Client).
-- It prints rows that do not fit at the minimum size ("OVER") and rows that use more than 85%
-- of the box ("tight"). Widths are base-layout studs-of-UI (before UIScale), minus button
-- padding (8 left + 8 right, 4 top + 4 bottom).
--
-- When a UI box or a Russian string changes, update the table below and re-run.
-- Reference result (22.11.2026): see docs/TEST_PLAN.md L-05.

local TextService = game:GetService("TextService")
local LocalizationService = game:GetService("LocalizationService")

local LOCALE = "ru" -- also worth running with "en"
-- Theme.MinTextSize (14) is applied in SCREEN pixels, so at the smallest UIScale (0.75) a string needs
-- 14 / 0.75 layout pixels. Roblox also keeps ~4 px inside a box (a 92 px word did not fit 94 px).
local MIN_SCALE = 0.75
local MIN_SIZE = 14 / MIN_SCALE
local SAFETY = 4

local translator = LocalizationService:GetTranslatorForLocaleAsync(LOCALE)

local function translate(key, args)
	local ok, text = pcall(function()
		return translator:FormatByKey(key, args)
	end)
	return ok and text or `<{key}>`
end

local function measure(text, boxWidth)
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = Font.fromEnum(Enum.Font.GothamBold)
	params.Size = MIN_SIZE
	params.Width = boxWidth or 10000
	return TextService:GetTextBoundsAsync(params)
end

local rows = {}
-- context, key, format args, box width, box height, wraps onto several lines?
local function check(context, key, args, boxWidth, boxHeight, wraps)
	local text = translate(key, args)
	local bounds = measure(text, if wraps then boxWidth else nil)
	local over = if wraps then bounds.Y > boxHeight else (bounds.X > boxWidth - SAFETY or bounds.Y > boxHeight)
	table.insert(
		rows,
		string.format(
			"%s %-10s %-34s %3dx%2d / %dx%d  %s",
			if over then "OVER" else "ok  ",
			context,
			key,
			bounds.X,
			bounds.Y,
			boxWidth,
			boxHeight,
			text
		)
	)
end

-- Buttons
check("btn", "HUD.Club", nil, 80, 48)
check("btn", "HUD.Settings", nil, 114, 40) -- 130 px wide
check("btn", "HUD.Emotes", nil, 114, 40) -- 130 px wide
check("btn", "Dash.Restart", nil, 80, 40)
check("btn", "UI.Close", nil, 124, 36)
check("btn", "Club.Buy", nil, 134, 44)
for _, key in { "Emote.Wave", "Emote.Cheer", "Emote.Clap", "Emote.ThumbsUp", "Emote.GoodGame", "Emote.LetsRace" } do
	check("emoteBtn", key, nil, 104, 48, true) -- 120 wide; two lines fit
	check("bubble", key, nil, 154, 42)
end
for _, key in { "Settings.LanguageAuto", "Settings.LanguageEn", "Settings.LanguageRu", "Settings.On", "Settings.Off" } do
	check("setBtn", key, nil, 196, 40)
end
-- Labels (settings labels wrap: two lines fit in 48)
for _, key in { "Settings.Music", "Settings.Sfx", "Settings.Language", "Settings.ReducedMotion" } do
	check("setLabel", key, nil, 128, 48, true)
end
check("topLevel", "HUD.Level", { level = "20" }, 117, 36)
check("xp", "HUD.Xp", { have = "999", need = "999" }, 230, 20)
check("xp", "HUD.MaxLevel", nil, 230, 20)
check("title", "Settings.Title", nil, 356, 36)
check("title", "Emote.Title", nil, 356, 34)
check("title", "Club.Title", nil, 356, 36)
for _, key in { "Club.Next", "Club.NotEnough", "Club.AllBuilt", "Club.ComingSoon" } do
	check("clubLine", key, nil, 356, 24)
end
check("clubLine", "Club.Level", { level = "9" }, 356, 24)
for _, id in
	{
		"sticky_banner",
		"pencil_fence",
		"eraser_benches",
		"book_stand",
		"ruler_scoreboard",
		"paperclip_trophies",
		"lamp_floodlight",
		"pencil_cup_tower",
	}
do
	check("clubName", `Club.Upgrade.{id}.Name`, nil, 356, 32)
end
-- Toasts: 424 wide, one line
for _, key in
	{
		"Error.PurchaseFailed",
		"Dash.Cancelled",
		"Dash.Abandoned",
		"Dash.Timeout",
		"Tutorial.Complete",
		"Club.ComingSoon",
	}
do
	check("toast", key, nil, 424, 36)
end
check("toast", "Dash.MissingCheckpoint", { index = "4" }, 424, 36)
check("toast", "Club.Built", { name = translate("Club.Upgrade.pencil_cup_tower.Name") }, 424, 36)
check("toast", "Tutorial.FinishBonus", { stars = "50" }, 424, 36)
-- Tutorial banner: 314 wide, wraps, 56 high
for _, key in { "Tutorial.GoToStart", "Tutorial.RunTrack", "Tutorial.OpenClub", "Tutorial.PressBuild" } do
	check("tutHint", key, nil, 314, 56, true)
end
check("tutStep", "Tutorial.Step", { step = "4", total = "5" }, 314, 20)
-- Result screen and Dash HUD
check("result", "Dash.Result.Title", nil, 316, 40)
check("result", "Dash.Result.NewBest", nil, 316, 26)
check("result", "Dash.Result.Rejected", nil, 316, 30)
check("result", "Dash.Result.Time", { time = "1:02.3" }, 316, 30)
check("result", "Dash.Result.Best", { time = "1:02.3" }, 316, 26)
check("hud", "Dash.Checkpoint", { index = "4", total = "4" }, 204, 30)
check("hud", "Dash.Go", nil, 260, 100)
check("hud", "HUD.LevelUp", { level = "20" }, 320, 80)
check("hud", "HUD.XpGain", { xp = "9999" }, 160, 26)
-- Track signs (BillboardGui 300 wide: name 284 x 40, note 284 x 24) and track toasts
check("sign", "Track.DeskName", nil, 284, 40)
check("sign", "Track.KeysName", nil, 284, 40)
check("sign", "Track.LockedSign", nil, 284, 24)
check("toast", "Track.Locked", nil, 424, 36)
check("toast", "Track.Unlocked", nil, 424, 36)
check("board", "Track.DeskName", nil, 840, 28)
check("board", "Track.KeysName", nil, 840, 28)
-- Records screen (rows 372 wide, name/best labels 222 wide) and its opener (130 px button)
check("btn", "HUD.Records", nil, 114, 36)
check("title", "Records.Title", nil, 372, 34)
check("records", "Records.None", nil, 222, 26)
check("records", "Dash.Result.Best", { time = "1:02.3" }, 222, 26)
check("records", "Track.DeskName", nil, 222, 28)
check("records", "Track.KeysName", nil, 222, 28)
-- World board and load-failed screen
check("board", "Board.Title", nil, 840, 70)
check("board", "Board.Empty", nil, 800, 100, true)
for _, key in { "Error.LoadFailed", "Error.UpdateRequired", "Error.SessionElsewhere" } do
	check("load", key, nil, 460, 90, true)
end
check("load", "Error.Title", nil, 460, 44)
check("load", "Error.RejoinHint", nil, 460, 56, true)

local over, tight = {}, {}
for _, row in rows do
	if string.sub(row, 1, 4) == "OVER" then
		table.insert(over, row)
	else
		local width, box = string.match(row, "%s(%d+)x%s?%d+ / (%d+)x")
		if width and tonumber(width) / tonumber(box) > 0.85 then
			table.insert(tight, row)
		end
	end
end
return { checked = #rows, over = over, tight = tight }
