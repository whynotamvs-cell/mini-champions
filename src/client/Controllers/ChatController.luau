--!strict
-- Hides every text chat surface on this client (docs/ARCHITECTURE.md 7.1, layer 3).
-- A safety net for properties that may be reset in Studio; the server-side policy is layer 4.

local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local CONFIG_CLASSES = {
	"ChatWindowConfiguration",
	"ChatInputBarConfiguration",
	"BubbleChatConfiguration",
	"ChannelTabsConfiguration",
}

local ChatController = {}

local function disable(instance: Instance)
	if table.find(CONFIG_CLASSES, instance.ClassName) then
		(instance :: any).Enabled = false
	end
end

function ChatController:Init()
	for _, child in TextChatService:GetChildren() do
		disable(child)
	end
	TextChatService.ChildAdded:Connect(disable)
end

function ChatController:Start()
	-- SetCoreGuiEnabled can fail if called before the core scripts are ready; retry briefly.
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		end)
		if ok then
			break
		end
		task.wait(1)
	end
end

return ChatController
