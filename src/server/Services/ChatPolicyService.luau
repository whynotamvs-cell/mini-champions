--!strict
-- Verifies that free text chat is off (docs/ARCHITECTURE.md 7.1, layer 4). The properties are
-- set by default.project.json (layer 1); this service checks them at runtime and removes any
-- TextChannel that appears. Violation: warn + telemetry; in Studio and the test place: error.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local TelemetryService = require(script.Parent.TelemetryService)

local CHECK_DELAY_SEC = 3 -- default channels are created shortly after start when enabled

local ChatPolicyService = {}

local strict = false

local function violation(message: string)
	warn(`[ChatPolicy] {message}`)
	-- No player to attribute this to; telemetry needs one, so it is only logged for the first player.
	local first = game:GetService("Players"):GetPlayers()[1]
	if first then
		TelemetryService:Custom(first, "ChatPolicyViolation", 1)
	end
	if strict then
		task.spawn(error, `[ChatPolicy] {message}`)
	end
end

local function removeChannel(instance: Instance)
	if instance:IsA("TextChannel") then
		violation(`TextChannel "{instance:GetFullName()}" found; destroying it`)
		instance:Destroy()
	end
end

function ChatPolicyService:Init()
	strict = RunService:IsStudio() or game.PlaceId == GameConfig.TestPlaceId
end

function ChatPolicyService:Start()
	if TextChatService.CreateDefaultTextChannels then
		violation("TextChatService.CreateDefaultTextChannels is true (must be false)")
	end
	if TextChatService.CreateDefaultCommands then
		violation("TextChatService.CreateDefaultCommands is true (must be false)")
	end
	TextChatService.DescendantAdded:Connect(removeChannel)
	task.delay(CHECK_DELAY_SEC, function()
		for _, descendant in TextChatService:GetDescendants() do
			removeChannel(descendant)
		end
	end)
end

return ChatPolicyService
