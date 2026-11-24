--!strict
-- Players never collide with each other (decision D12): every character part goes into the
-- "Players" collision group, which does not collide with itself.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local GROUP = "Players"

local CollisionService = {}

local function assign(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = GROUP
	end
end

local function onCharacter(character: Model)
	for _, descendant in character:GetDescendants() do
		assign(descendant)
	end
	character.DescendantAdded:Connect(assign)
end

function CollisionService:Init()
	PhysicsService:RegisterCollisionGroup(GROUP)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end

function CollisionService:Start()
	local function track(player: Player)
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
end

return CollisionService
