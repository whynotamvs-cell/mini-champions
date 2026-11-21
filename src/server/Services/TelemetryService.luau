--!strict
-- The only place that calls AnalyticsService (docs/ARCHITECTURE.md 12).
-- In Studio (unless Config.Game.TelemetryInStudio) events are printed, never sent.
-- Signatures checked against creator-docs AnalyticsService.yaml on 2026-11-21.

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Net = require(script.Parent.Parent.Net)

export type FlowType = "Source" | "Sink"
export type ProgressionStatus = "Start" | "Complete" | "Fail"

local PROGRESSION_PATH = "DeskDash"

local TelemetryService = {}

local sendToAnalytics = false

local function emit(label: string, call: () -> ())
	if not sendToAnalytics then
		print(`[Telemetry] {label}`)
		return
	end
	local ok, err = pcall(call)
	if not ok then
		warn(`[Telemetry] {label} failed: {err}`)
	end
end

function TelemetryService:Init()
	sendToAnalytics = not RunService:IsStudio() or GameConfig.TelemetryInStudio
	Net.setViolationReporter(function(player: Player, remoteName: string, _reason: string)
		TelemetryService:Custom(player, "NetViolation", 1, { remote = remoteName })
	end)
end

function TelemetryService:Start() end

-- Callers guarantee once-per-lifetime via Tutorial.Step in the profile.
function TelemetryService:Onboarding(player: Player, step: number, stepName: string)
	emit(`onboarding {player.UserId} {step} {stepName}`, function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

function TelemetryService:Economy(
	player: Player,
	flowType: FlowType,
	amount: number,
	endingBalance: number,
	transactionType: string,
	itemSku: string
)
	if amount <= 0 then
		return
	end
	local flow = if flowType == "Source"
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	emit(`economy {player.UserId} {flowType} {amount} -> {endingBalance} {transactionType} {itemSku}`, function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			Economy.CurrencyName,
			amount,
			endingBalance,
			transactionType,
			itemSku
		)
	end)
end

function TelemetryService:Progression(player: Player, status: ProgressionStatus, levelName: string?)
	emit(`progression {player.UserId} {PROGRESSION_PATH} {status}`, function()
		if status == "Start" then
			AnalyticsService:LogProgressionStartEvent(player, PROGRESSION_PATH, 1, levelName)
		elseif status == "Complete" then
			AnalyticsService:LogProgressionCompleteEvent(player, PROGRESSION_PATH, 1, levelName)
		else
			AnalyticsService:LogProgressionFailEvent(player, PROGRESSION_PATH, 1, levelName)
		end
	end)
end

-- customFields: only ids from our own enums, never free text or personal data.
function TelemetryService:Custom(player: Player, eventName: string, value: number?, customFields: { [string]: string }?)
	emit(`custom {player.UserId} {eventName} {value or 1}`, function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1, customFields :: any)
	end)
end

return TelemetryService
