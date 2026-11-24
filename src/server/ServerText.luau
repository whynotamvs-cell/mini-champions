--!strict
-- Localized text that the server must show directly (kick messages). Everything else goes to
-- the client as a localization key. Falls back to the English source string, then to the key.

local LocalizationService = game:GetService("LocalizationService")

local ServerText = {}

function ServerText.forPlayer(player: Player, key: string, args: { [string]: any }?): string
	local ok, result = pcall(function()
		local translator = LocalizationService:GetTranslatorForPlayerAsync(player)
		return translator:FormatByKey(key, args)
	end)
	if ok and type(result) == "string" and result ~= "" then
		return result
	end
	warn(`[ServerText] no translation for "{key}": {tostring(result)}`)
	return key
end

function ServerText.kick(player: Player, key: string)
	if player.Parent == nil then
		return
	end
	player:Kick(ServerText.forPlayer(player, key))
end

return ServerText
