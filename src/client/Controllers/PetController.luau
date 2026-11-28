--!strict
-- Shows every player's equipped pet (the player attribute "Pet" set by PetService) following its
-- owner, alive: it hops when the owner jumps, wags and flutters while running, and celebrates when the
-- local player finishes a run. Pets live only on this client; nothing here is trusted or replicated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Components = require(script.Parent.Parent.UI.Components)
local Juice = require(script.Parent.Parent.UI.Juice)
local PetModel = require(script.Parent.Parent.UI.PetModel)
local DashController = require(script.Parent.DashController)
local LocalizationController = require(script.Parent.LocalizationController)

local L = LocalizationController.L

local PetController = {}

type Follower = {
	built: PetModel.Built,
	root: BasePart,
	humanoid: Humanoid?,
	petId: string,
	offset: Vector3,
	seed: number,
	nameLabel: TextLabel,
	joyUntil: number,
	hop: number,
	lastPos: Vector3,
}

local followers: { [Player]: Follower } = {}
local folder: Folder? = nil

local JOY_SECONDS = 3.2

local function nameText(petId: string): string
	return L(`Pets.Item.{petId}.Name`)
end

local function clear(player: Player)
	local follower = followers[player]
	if follower then
		follower.built.model:Destroy()
		followers[player] = nil
	end
end

local function makeNameTag(built: PetModel.Built, petId: string): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 34)
	gui.StudsOffset = Vector3.new(0, built.height / 2 + 1.2, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 70
	gui.Adornee = built.body
	gui.Parent = built.body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Components.Theme.Font
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Components.Theme.TextStroke
	label.TextStrokeTransparency = 0.2
	label.AutoLocalize = false
	label.Text = nameText(petId)
	label.Parent = gui
	return label
end

local function sparkleBurst(body: Part)
	if Juice.isReducedMotion() then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.LightEmission = 0.8
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 120, 190), Color3.fromRGB(255, 230, 120))
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = body
	emitter:Emit(24)
	task.delay(2, function()
		emitter:Destroy()
	end)
end

local function sync(player: Player)
	local petId = player:GetAttribute("Pet")
	local current = followers[player]
	local wanted = if type(petId) == "string" and Pets.ById[petId] then petId else nil
	if current and current.petId == wanted then
		return
	end
	clear(player)
	if wanted == nil or folder == nil then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local built = PetModel.build(Pets.ById[wanted], folder)
	local side = if player.UserId % 2 == 0 then 1 else -1
	local follower: Follower = {
		built = built,
		root = root,
		humanoid = character and character:FindFirstChildOfClass("Humanoid"),
		petId = wanted,
		offset = Vector3.new(3.2 * side, -0.4, 4.0),
		seed = player.UserId % 7,
		nameLabel = makeNameTag(built, wanted),
		joyUntil = 0,
		hop = 0,
		lastPos = root.Position,
	}
	followers[player] = follower
	built.body.CFrame = root.CFrame * CFrame.new(follower.offset)
	PetModel.place(built, built.body.CFrame, 0, { moving = false, air = false, joy = false })
end

local function place(follower: Follower, dt: number, t: number)
	local body = follower.built.body
	local root = follower.root
	if not root.Parent then
		return
	end
	local velocity = (root.Position - follower.lastPos) / math.max(dt, 1e-3)
	follower.lastPos = root.Position
	local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2
		and Vector3.new(velocity.X, 0, velocity.Z).Magnitude < 60
	local humanoid = follower.humanoid
	local air = humanoid ~= nil and (humanoid.FloorMaterial == Enum.Material.Air) and math.abs(velocity.Y) < 200
	local joy = t < follower.joyUntil
	local reduced = Juice.isReducedMotion()

	-- Hop with the owner, a little bounce while running, a big dance when celebrating.
	local targetHop = if air then 1.6 elseif joy then 0 else 0
	follower.hop += (targetHop - follower.hop) * (1 - math.exp(-10 * dt))
	local bob = 0.0
	if not reduced then
		if joy then
			bob = math.abs(math.sin(t * 9)) * 2.2
		elseif moving then
			bob = math.abs(math.sin(t * 11 + follower.seed)) * 0.5
		else
			bob = math.sin(t * 2.5 + follower.seed) * 0.15
		end
	end
	local target = root.CFrame * CFrame.new(follower.offset + Vector3.new(0, 0.9 + bob + follower.hop, 0))
	local alpha = 1 - math.exp(-9 * dt)
	local pos = body.Position:Lerp(target.Position, alpha)
	if (pos - target.Position).Magnitude > 40 then
		pos = target.Position -- the owner was teleported: do not fly across the map
	end
	local heading = root.CFrame - root.CFrame.Position
	local base = CFrame.new(pos) * heading
	if joy and not reduced then
		base *= CFrame.Angles(0, t * 8, 0)
	end
	PetModel.place(follower.built, base, t, { moving = moving, air = air, joy = joy })
end

local function refreshNames()
	for _, follower in followers do
		follower.nameLabel.Text = nameText(follower.petId)
	end
end

function PetController:Init()
	LocalizationController.Changed:Connect(refreshNames)
	-- The local player's pet celebrates a counted finish.
	DashController.Event:Connect(function(event)
		if event.kind == "finish" and event.valid == true then
			local follower = followers[Players.LocalPlayer]
			if follower then
				follower.joyUntil = os.clock() + JOY_SECONDS
				sparkleBurst(follower.built.body)
			end
		end
	end)
end

function PetController:Start()
	local f = Instance.new("Folder")
	f.Name = "Pets"
	f.Parent = Workspace
	folder = f

	local function watch(player: Player)
		player:GetAttributeChangedSignal("Pet"):Connect(function()
			sync(player)
		end)
		player.CharacterAdded:Connect(function()
			clear(player)
			task.wait(0.5)
			sync(player)
		end)
		task.defer(sync, player)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(clear)

	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock()
		for _, follower in followers do
			place(follower, dt, t)
		end
	end)
end

return PetController
