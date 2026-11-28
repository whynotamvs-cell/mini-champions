--!strict
-- Funny falls: when the local character plunges off a platform it goes limp (ragdoll) until the
-- server puts it back on the checkpoint. Purely cosmetic and local; the server alone decides the reset.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Juice = require(script.Parent.Parent.UI.Juice)

local FallController = {}

local FALL_SPEED = -85 -- studs/s downward (a drop of ~18 studs) before the body goes limp
local TELEPORT_JUMP = 25 -- studs moved in one frame that count as a server teleport

local limp = false
local lastPos: Vector3? = nil

local function recover(humanoid: Humanoid)
	if limp then
		limp = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

function FallController:Init() end

function FallController:Start()
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid == nil or root == nil or not root:IsA("BasePart") or humanoid.Health <= 0 then
			limp = false
			lastPos = nil
			return
		end
		local position = root.Position
		if lastPos and (position - lastPos).Magnitude > TELEPORT_JUMP then
			recover(humanoid)
		end
		lastPos = position
		if limp and humanoid:GetState() ~= Enum.HumanoidStateType.Ragdoll then
			limp = false -- the engine already got the body upright again (landed)
		end
		if not limp and not Juice.isReducedMotion() and root.AssemblyLinearVelocity.Y < FALL_SPEED then
			limp = true
			humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
		end
	end)
end

return FallController
