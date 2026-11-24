--!strict
-- Current Translator and L(key, args) for all UI (docs/ARCHITECTURE.md 10). The server sends keys,
-- never text. Language: Settings.Language "auto" = account language (unsupported -> English).

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Utilities.Format)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local DataController = require(script.Parent.DataController)

local LocalizationController = {}

-- Fired when the translator changes; every screen re-renders its texts. Handlers must not yield.
LocalizationController.Changed = Signal.new() :: Signal.Signal<>

local translator: Translator? = nil
local choice: string? = nil
local requestId = 0

local function setLanguage(language: string)
	if language == choice then
		return
	end
	choice = language
	requestId += 1
	local myRequest = requestId
	task.spawn(function()
		local ok, result = pcall(function(): Translator
			if language == "en" or language == "ru" then
				return LocalizationService:GetTranslatorForLocaleAsync(language)
			end
			return LocalizationService:GetTranslatorForPlayerAsync(Players.LocalPlayer)
		end)
		if myRequest ~= requestId then
			return -- a newer choice arrived while this one was loading
		end
		if ok then
			translator = result
			LocalizationController.Changed:Fire()
		else
			warn(`[Localization] translator for "{language}" failed: {result}`)
		end
	end)
end

function LocalizationController:Init()
	DataController.Changed:Connect(function(snapshot)
		setLanguage(snapshot.Settings.Language)
	end)
end

function LocalizationController:Start()
	if choice == nil then
		setLanguage("auto")
	end
end

-- Translator:FormatByKey renders a plain number argument as "1.00", so numbers go in as text:
-- integers grouped like the rest of the UI, fractions via tostring.
local function textArgs(args: { [string]: any }?): { [string]: any }?
	if args == nil then
		return nil
	end
	local out = {}
	for name, value in args do
		if type(value) == "number" then
			out[name] = if value == math.floor(value) and math.abs(value) < math.huge
				then Format.integer(value)
				else tostring(value)
		else
			out[name] = value
		end
	end
	return out
end

-- Translated text for `key`; the key itself when no translator is ready or the key is missing.
function LocalizationController.L(key: string, args: { [string]: any }?): string
	if translator == nil then
		return ""
	end
	local formatArgs = textArgs(args)
	local ok, text = pcall(function(): string
		return (translator :: Translator):FormatByKey(key, formatArgs)
	end)
	return if ok then text else key
end

function LocalizationController:IsReady(): boolean
	return translator ~= nil
end

return LocalizationController
