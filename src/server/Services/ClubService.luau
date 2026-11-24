--!strict
-- Club plots and upgrades (docs/ARCHITECTURE.md 9). A plot is assigned on profile load and freed
-- on leave; it is session state and never saved. Purchases only ever touch the buyer's own data,
-- so another player's club cannot be changed by construction.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Signal = require(ReplicatedStorage.Shared.Utilities.Signal)
local Validators = require(ReplicatedStorage.Shared.Net.Validators)

local Net = require(script.Parent.Parent.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local PurchaseLogic = require(script.Parent.Logic.PurchaseLogic)

export type PurchaseResponse = { ok: boolean, reason: string?, index: number? }

local ClubService = {}

-- Fired after a committed purchase: (player, index). Handlers must not yield.
ClubService.Purchased = Signal.new() :: Signal.Signal<Player, number>

local plots: { [number]: BasePart } = {}
local owners: { [number]: Player } = {}
local plotOf: { [Player]: number } = {}
local rendered: { [Player]: { Instance } } = {}
local upgradeModels: Instance? = nil

local function upgradeTemplate(index: number): Model?
	local upgrade = Economy.Upgrades[index]
	local found = upgrade and upgradeModels and upgradeModels:FindFirstChild(upgrade.Id)
	return if found and found:IsA("Model") then found else nil
end

-- Upgrade models are authored around the origin with y = 0 at the plot's top surface.
local function placeUpgrade(player: Player, index: number)
	local plotIndex = plotOf[player]
	local template = upgradeTemplate(index)
	if plotIndex == nil or template == nil then
		return
	end
	local plot = plots[plotIndex]
	local base = plot.CFrame * CFrame.new(0, plot.Size.Y / 2, 0)
	local clone = template:Clone()
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame = base * descendant.CFrame
			descendant.Anchored = true
		end
	end
	clone.Name = `{plot.Name}_{template.Name}`
	clone.Parent = plot
	rendered[player] = rendered[player] or {}
	table.insert(rendered[player], clone)
end

local function clearPlot(player: Player)
	local list = rendered[player]
	if list then
		for _, instance in list do
			instance:Destroy()
		end
	end
	rendered[player] = nil
end

local function assignPlot(player: Player, upgradesOwned: number)
	if #plots == 0 then
		return -- plots are collected in Start(); Start() assigns players that loaded earlier
	end
	for index = 1, #plots do
		if not owners[index] then
			owners[index] = player
			plotOf[player] = index
			plots[index]:SetAttribute("OwnerUserId", player.UserId)
			for i = 1, upgradesOwned do
				placeUpgrade(player, i)
			end
			return
		end
	end
	warn(`[ClubService] no free plot for {player.UserId} (more players than plots?)`)
end

local function releasePlot(player: Player)
	clearPlot(player)
	local index = plotOf[player]
	if index then
		owners[index] = nil
		plots[index]:SetAttribute("OwnerUserId", nil)
	end
	plotOf[player] = nil
end

function ClubService:Purchase(player: Player, index: number): PurchaseResponse
	if plotOf[player] == nil then
		return { ok = false, reason = "no_plot" }
	end
	if upgradeTemplate(index) == nil then
		-- No model yet (stage 1 ships only the first upgrade): never sell something invisible.
		return { ok = false, reason = "unavailable" }
	end

	local result: PurchaseLogic.Result? = nil
	local failure: string? = nil
	local committed = PlayerDataService:Update(player, function(data): boolean?
		local ok, value = PurchaseLogic.apply(data, index)
		if not ok then
			failure = value :: string
			return false
		end
		result = value :: PurchaseLogic.Result
		return true
	end)
	if not committed or result == nil then
		return { ok = false, reason = failure or "not_committed" }
	end

	PlayerDataService:SaveNow(player) -- decision D4
	TelemetryService:Economy(
		player,
		"Sink",
		result.price,
		result.balance - result.levelUpStars,
		"Shop",
		result.upgradeId
	)
	if result.levelUpStars > 0 then
		TelemetryService:Economy(player, "Source", result.levelUpStars, result.balance, "Gameplay", "level_up")
	end
	placeUpgrade(player, index)
	ClubService.Purchased:Fire(player, index)
	return { ok = true, index = index }
end

function ClubService:Init()
	upgradeModels = ServerStorage:FindFirstChild("ClubUpgrades")
	if upgradeModels == nil then
		warn("[ClubService] ServerStorage.ClubUpgrades is missing")
	end
	-- Tell clients how many upgrades (in order) can be built, so the menu never offers one
	-- that has no model yet. ServerStorage itself is not visible to clients.
	local available = 0
	while upgradeTemplate(available + 1) do
		available += 1
	end
	ReplicatedStorage:SetAttribute("AvailableUpgrades", available)

	Net.onServerInvoke("PurchaseUpgrade", {
		rate = { count = 2, per = 1 },
		validate = Validators.tuple(Validators.integer(1, #Economy.Upgrades)),
	}, function(player: Player, index: number): PurchaseResponse
		return ClubService:Purchase(player, index)
	end)

	PlayerDataService.Loaded:Connect(function(player, data)
		assignPlot(player, data.Club.UpgradesOwned)
	end)
end

function ClubService:Start()
	local world = Workspace:WaitForChild("DeskWorld")
	for _, plot in world:WaitForChild("Plots"):GetChildren() do
		local index = plot:GetAttribute("PlotIndex")
		if plot:IsA("BasePart") and type(index) == "number" then
			plots[index] = plot
		end
	end
	assert(#plots > 0, "[ClubService] no plots found in Workspace.DeskWorld.Plots")
	Players.PlayerRemoving:Connect(releasePlot)
	-- Players whose profile loaded before plots were collected.
	for _, player in Players:GetPlayers() do
		local data = PlayerDataService:Get(player)
		if data and plotOf[player] == nil then
			assignPlot(player, data.Club.UpgradesOwned)
		end
	end
end

function ClubService:GetPlotIndex(player: Player): number?
	return plotOf[player]
end

return ClubService
