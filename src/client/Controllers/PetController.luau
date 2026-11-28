--!strict
-- Shows every player's equipped pet (the player attribute "Pet" set by PetService) following its
-- owner. Pets are built from simple parts per Config.Pets and live only on this client; nothing
-- here is trusted or replicated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Juice = require(script.Parent.Parent.UI.Juice)

local PetController = {}

type Follower = { model: Model, root: BasePart, petId: string, offset: Vector3, seed: number }

local followers: { [Player]: Follower } = {}
local folder: Folder? = nil

local function block(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function ball(model: Model, name: string, diameter: number, color: Color3, material: Enum.Material?): Part
	local part = block(model, name, Vector3.new(diameter, diameter, diameter), color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Parts of a pet in its own space: each entry is (part, offset from the body centre). The body is the primary part.
local function build(pet: Pets.Pet): (Model, { { part: Part, offset: CFrame } })
	local model = Instance.new("Model")
	model.Name = `Pet_{pet.Id}`
	local c = Color3.fromRGB(pet.Color[1], pet.Color[2], pet.Color[3])
	local dark = Color3.fromRGB(pet.Color[1] * 0.55, pet.Color[2] * 0.55, pet.Color[3] * 0.55)
	local s = pet.Size
	local body = ball(model, "Body", 2.2 * s, c)
	model.PrimaryPart = body
	local parts: { { part: Part, offset: CFrame } } = { { part = body, offset = CFrame.new() } }
	local function add(part: Part, offset: CFrame)
		table.insert(parts, { part = part, offset = offset })
	end
	-- Eyes and a little shine, facing forward (-Z).
	for _, x in { -0.45, 0.45 } do
		add(ball(model, "Eye", 0.55 * s, Color3.new(1, 1, 1)), CFrame.new(x * s, 0.25 * s, -0.95 * s))
		add(ball(model, "Pupil", 0.28 * s, Color3.fromRGB(20, 20, 40)), CFrame.new(x * s, 0.25 * s, -1.2 * s))
	end
	local kind = pet.Kind
	if kind == "bunny" then
		for _, x in { -0.5, 0.5 } do
			add(
				block(model, "Ear", Vector3.new(0.5, 1.7, 0.4) * s, c),
				CFrame.new(x * s, 1.7 * s, 0) * CFrame.Angles(0, 0, math.rad(-x * 14))
			)
		end
	elseif kind == "pup" then
		for _, x in { -1, 1 } do
			add(
				block(model, "Ear", Vector3.new(0.5, 1.1, 0.7) * s, dark),
				CFrame.new(x * 1.05 * s, 0.7 * s, 0) * CFrame.Angles(0, 0, math.rad(x * 18))
			)
		end
		add(ball(model, "Nose", 0.5 * s, Color3.fromRGB(30, 30, 40)), CFrame.new(0, -0.15 * s, -1.15 * s))
	elseif kind == "cat" then
		for _, x in { -0.6, 0.6 } do
			add(
				block(model, "Ear", Vector3.new(0.6, 0.8, 0.3) * s, c),
				CFrame.new(x * s, 1.2 * s, 0) * CFrame.Angles(0, 0, math.rad(-x * 25))
			)
		end
		add(
			block(model, "Tail", Vector3.new(0.35, 1.5, 0.35) * s, dark),
			CFrame.new(0, 0.3 * s, 1.3 * s) * CFrame.Angles(math.rad(-30), 0, 0)
		)
	elseif kind == "dino" then
		for i = 1, 3 do
			add(
				block(model, "Spike", Vector3.new(0.35, 0.8, 0.5) * s, dark),
				CFrame.new(0, (1.0 - (i - 1) * 0.1) * s + 0.2, (0.4 + (i - 1) * 0.45) * s)
			)
		end
		add(block(model, "Tail", Vector3.new(0.7, 0.7, 1.4) * s, c), CFrame.new(0, -0.3 * s, 1.6 * s))
	elseif kind == "bug" then
		for _, x in { -0.4, 0.4 } do
			add(
				block(model, "Antenna", Vector3.new(0.12, 1.3, 0.12) * s, dark),
				CFrame.new(x * s, 1.3 * s, -0.2 * s) * CFrame.Angles(0, 0, math.rad(-x * 40))
			)
		end
	elseif kind == "dragon" then
		for _, x in { -0.6, 0.6 } do
			add(
				block(model, "Horn", Vector3.new(0.35, 0.9, 0.35) * s, Color3.fromRGB(255, 220, 120)),
				CFrame.new(x * s, 1.2 * s, -0.1 * s) * CFrame.Angles(0, 0, math.rad(-x * 22))
			)
			add(
				block(model, "Wing", Vector3.new(1.5, 0.15, 1.1) * s, dark),
				CFrame.new(x * 1.9 * s, 0.5 * s, 0.4 * s) * CFrame.Angles(0, math.rad(x * 25), math.rad(-x * 20))
			)
		end
		add(block(model, "Tail", Vector3.new(0.5, 0.5, 1.5) * s, c), CFrame.new(0, -0.4 * s, 1.6 * s))
	end
	return model, parts
end

local layouts: { [Model]: { { part: Part, offset: CFrame } } } = {}

local function clear(player: Player)
	local follower = followers[player]
	if follower then
		layouts[follower.model] = nil
		follower.model:Destroy()
		followers[player] = nil
	end
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
	local model, parts = build(Pets.ById[wanted])
	model.Parent = folder
	layouts[model] = parts
	local side = if player.UserId % 2 == 0 then 1 else -1
	followers[player] = {
		model = model,
		root = root,
		petId = wanted,
		offset = Vector3.new(2.6 * side, -0.6, 3.4),
		seed = player.UserId % 7,
	}
	-- Start beside the owner.
	local body = model.PrimaryPart :: BasePart
	body.CFrame = root.CFrame * CFrame.new(followers[player].offset)
end

local function place(follower: Follower, dt: number, t: number)
	local body = follower.model.PrimaryPart :: BasePart
	local root = follower.root
	if not root.Parent then
		return
	end
	local bob = if Juice.isReducedMotion() then 0 else math.sin(t * 5 + follower.seed) * 0.35
	local target = root.CFrame * CFrame.new(follower.offset + Vector3.new(0, 0.6 + bob, 0))
	local alpha = 1 - math.exp(-9 * dt)
	local pos = body.Position:Lerp(target.Position, alpha)
	if (pos - target.Position).Magnitude > 40 then
		pos = target.Position -- the owner was teleported: do not fly across the map
	end
	local cf = CFrame.new(pos) * (root.CFrame - root.CFrame.Position) -- same heading as the owner
	local parts = layouts[follower.model]
	if parts then
		for _, entry in parts do
			entry.part.CFrame = cf * entry.offset
		end
	end
end

function PetController:Init() end

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
