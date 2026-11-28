--!strict
-- Paid items (docs/ECONOMY.md 9, docs/ARCHITECTURE.md 8.5). Receipts, the Spring Boots Game Pass,
-- skip tokens and cosmetics. The client only asks ("use a skip", "equip X", "boots on"); the server
-- checks ownership. Anything that helps a run (skip, boots) marks the run as assisted, so it earns no
-- medal, record or reward. Receipts are idempotent: a purchase id seen before is acknowledged, not
-- granted again.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Validators = require(ReplicatedStorage.Shared.Net.Validators)

local Net = require(script.Parent.Parent.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TelemetryService = require(script.Parent.TelemetryService)
local ShopLogic = require(script.Parent.Logic.ShopLogic)
local ObstacleDash = require(script.Parent.Minigames.ObstacleDash)

local MonetizationService = {}

local DEFAULT_JUMP_HEIGHT = 7.2 -- R15 default; Spring Boots replace it
local RECEIPT_WAIT_SEC = 10
local PASS_RECHECKS = 3

local TRAIL_NAME = "ShopTrail"

local function sequenceFor(itemId: string, color: { number }?): ColorSequence
	if itemId == "trail_rainbow" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 220, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)),
		})
	elseif itemId == "trail_fire" then
		return ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(230, 60, 30))
	end
	local c = color or { 255, 255, 255 }
	return ColorSequence.new(Color3.fromRGB(c[1], c[2], c[3]))
end

-- Jump height and trail follow the saved data. Safe to call any time; replaces what was there.
local function applyEffects(player: Player)
	local data = PlayerDataService:Get(player)
	local character = player.Character
	if data == nil or character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.JumpHeight = if data.Shop.SpringOn and data.Shop.SpringBoots
			then Shop.SpringJumpHeight
			else DEFAULT_JUMP_HEIGHT
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local old = root:FindFirstChild(TRAIL_NAME)
	if old then
		old:Destroy()
	end
	for _, name in { "ShopTrailA", "ShopTrailB" } do
		local attachment = root:FindFirstChild(name)
		if attachment then
			attachment:Destroy()
		end
	end
	local item = Shop.ById[data.Shop.Trail]
	if item == nil or item.Kind ~= "Trail" then
		return
	end
	local a = Instance.new("Attachment")
	a.Name = "ShopTrailA"
	a.Position = Vector3.new(0, 0.9, 0)
	a.Parent = root
	local b = Instance.new("Attachment")
	b.Name = "ShopTrailB"
	b.Position = Vector3.new(0, -0.9, 0)
	b.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = TRAIL_NAME
	trail.Attachment0 = a
	trail.Attachment1 = b
	trail.Color = sequenceFor(item.Id, item.Color)
	trail.Lifetime = 0.7
	trail.LightEmission = 0.6
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = root
end

local function notify(player: Player, key: string)
	Net.fireClient("Notify", player, key, nil)
end

-- The player's Game Pass ownership, asked from Roblox. nil when the check failed.
local function ownsPass(player: Player, passId: number): boolean?
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok then
		return owns == true
	end
	warn(`[MonetizationService] pass check failed for {player.UserId}: {owns}`)
	return nil
end

local function syncPass(player: Player, assumePurchased: boolean)
	local passId = Shop.ById.spring.RobloxId
	if passId == 0 then
		return
	end
	local owned: boolean? = nil
	for attempt = 1, PASS_RECHECKS do
		owned = ownsPass(player, passId)
		if owned == true or not assumePurchased or player.Parent ~= Players then
			break
		end
		task.wait(attempt * 1.5) -- the service can lag behind a purchase for a moment
	end
	if owned == nil then
		return
	end
	if assumePurchased and owned == false then
		-- Roblox told us it was purchased; trust that event when the ownership cache is behind.
		owned = true
	end
	PlayerDataService:Update(player, function(data): boolean?
		if data.Shop.SpringBoots == owned then
			return false
		end
		ShopLogic.setSpringOwned(data, owned :: boolean)
		return true
	end)
	applyEffects(player)
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local item = Shop.findByRobloxId(info.ProductId, false)
	if item == nil then
		warn(`[MonetizationService] receipt for unknown product {tostring(info.ProductId)}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local deadline = os.clock() + RECEIPT_WAIT_SEC
	while not PlayerDataService:IsReady(player) do
		if player.Parent ~= Players or os.clock() > deadline then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		task.wait(0.25)
	end

	local grantId = ShopLogic.receiptGrantId(tostring(info.PurchaseId))
	local duplicate = false
	local committed = PlayerDataService:Update(player, function(data): boolean?
		local ok, reason = ShopLogic.applyProduct(data, item, grantId)
		if not ok then
			duplicate = reason == "duplicate"
			return false
		end
		return true
	end)
	if duplicate then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not committed then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Save before telling Roblox it was granted: a crash must not lose paid goods.
	PlayerDataService:SaveNow(player)
	TelemetryService:Custom(player, "ShopPurchase", 1, { item = item.Id })
	if item.Kind == "StarsPack" then
		local after = PlayerDataService:Get(player)
		TelemetryService:Economy(player, "Source", item.Stars or 0, if after then after.Stars else 0, "IAP", item.Id)
	end
	applyEffects(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function springIsOn(player: Player): boolean
	local data = PlayerDataService:Get(player)
	return data ~= nil and data.Shop.SpringOn and data.Shop.SpringBoots
end

-- Exposed so a test place can feed receipts without a real purchase; Roblox calls it through ProcessReceipt.
MonetizationService.ProcessReceipt = processReceipt

function MonetizationService:Init()
	Net.onServerEvent("UseSkip", {
		rate = { count = 1, per = 2 },
		validate = Validators.none,
	}, function(player: Player)
		local run = ObstacleDash:GetRun(player)
		if run == nil or run.state ~= "Running" then
			notify(player, "Shop.Skip.NoRun")
			return
		end
		if not PlayerDataService:Update(player, ShopLogic.useSkip) then
			notify(player, "Shop.Skip.None")
			return
		end
		local failure = ObstacleDash:SkipStage(player)
		if failure then
			-- The run ended in between: give the token back.
			PlayerDataService:Update(player, function(data): boolean?
				data.Shop.SkipTokens = math.min(Shop.MaxSkipTokens, data.Shop.SkipTokens + 1)
				return true
			end)
			notify(player, "Shop.Skip.NoRun")
			return
		end
		TelemetryService:Custom(player, "SkipUsed", 1, { track = run.track.Id })
		notify(player, "Shop.Skip.Used")
	end)

	Net.onServerEvent("SetSpring", {
		rate = { count = 2, per = 1 },
		validate = Validators.tuple(Validators.boolean()),
	}, function(player: Player, on: boolean)
		local committed = PlayerDataService:Update(player, function(data): boolean?
			return ShopLogic.setSpring(data, on)
		end)
		if not committed then
			return
		end
		if on then
			local run = ObstacleDash:GetRun(player)
			if run and (run.state == "Running" or run.state == "Countdown") then
				ObstacleDash:MarkAssisted(player)
				notify(player, "Shop.Spring.Assisted")
			end
		end
		applyEffects(player)
	end)

	Net.onServerEvent("EquipCosmetic", {
		rate = { count = 3, per = 2 },
		validate = Validators.tuple(Validators.enumString(Shop.equipIds())),
	}, function(player: Player, id: string)
		PlayerDataService:Update(player, function(data): boolean?
			return ShopLogic.equip(data, id)
		end)
		applyEffects(player)
	end)

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, wasPurchased: boolean)
			if wasPurchased and passId == Shop.ById.spring.RobloxId and passId ~= 0 then
				task.spawn(syncPass, player, true)
			end
		end
	)

	PlayerDataService.Loaded:Connect(function(player: Player)
		task.spawn(syncPass, player, false)
		task.defer(applyEffects, player)
	end)

	ObstacleDash.RunStarted:Connect(function(player: Player)
		if springIsOn(player) then
			ObstacleDash:MarkAssisted(player)
			notify(player, "Shop.Spring.Assisted")
		end
	end)
end

function MonetizationService:Start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(applyEffects, player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return MonetizationService
