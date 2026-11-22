--!strict
-- Player settings (docs/ARCHITECTURE.md 6.1 UpdateSettings). The client sends changes; the server
-- keeps only valid known keys, clamps volumes and writes through PlayerDataService:Update, which
-- also pushes a fresh snapshot back (so the client always shows what was actually saved).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Validators = require(ReplicatedStorage.Shared.Net.Validators)

local Net = require(script.Parent.Parent.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SettingsLogic = require(script.Parent.Logic.SettingsLogic)

local SettingsService = {}

function SettingsService:Init()
	Net.onServerEvent("UpdateSettings", {
		-- Burst of 4, refilled at 2 per second; the client coalesces changes into one call.
		rate = { count = 4, per = 2 },
		validate = Validators.tuple(Validators.plainTable()),
	}, function(player: Player, changes: any)
		local sanitized = SettingsLogic.sanitize(changes)
		if SettingsLogic.isEmpty(sanitized) then
			return
		end
		PlayerDataService:Update(player, function(data)
			SettingsLogic.apply(data, sanitized)
			return true
		end)
	end)
end

function SettingsService:Start() end

return SettingsService
