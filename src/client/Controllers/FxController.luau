--!strict
-- Cosmetic run feedback: sparkles at checkpoints, medal-coloured confetti at the finish and a
-- small camera "kick" on GO. Display only, driven by server DashEvents; nothing here is
-- trusted by the server. All effects are skipped when motion is reduced (TEST_PLAN U-05).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Juice = require(script.Parent.Parent.UI.Juice)
local DashController = require(script.Parent.DashController)

local FxController = {}

local MEDAL_COLORS: { [string]: Color3 } = {
	Gold = Color3.fromRGB(255, 205, 60),
	Silver = Color3.fromRGB(220, 226, 235),
	Bronze = Color3.fromRGB(214, 140, 80),
}
local CHECKPOINT_COLOR = Color3.fromRGB(110, 235, 150)
local FOV_KICK = 7

local function rootPart(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- One-shot particle burst on the local character. The emitter and its attachment are removed
-- shortly after the particles die.
local function burst(color: Color3, count: number, speed: NumberRange, lifetime: number, size: number)
	if Juice.isReducedMotion() then
		return
	end
	local root = rootPart()
	if root == nil then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "FxBurst"
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.6
	emitter.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
	emitter.Speed = speed
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -12, 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Parent = attachment
	attachment.Parent = root
	emitter:Emit(count)
	Debris:AddItem(attachment, lifetime + 0.5)
end

local function fovKick()
	local camera = Workspace.CurrentCamera
	if camera == nil or Juice.isReducedMotion() then
		return
	end
	local base = camera.FieldOfView
	camera.FieldOfView = base + FOV_KICK
	TweenService
		:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base })
		:Play()
end

local function onDashEvent(event: DashController.DashEvent)
	local kind = event.kind
	if kind == "start" then
		fovKick()
	elseif kind == "checkpoint" then
		burst(CHECKPOINT_COLOR, 24, NumberRange.new(10, 22), 0.9, 1.4)
	elseif kind == "finish" and event.valid == true then
		local color = MEDAL_COLORS[tostring(event.medal)] or MEDAL_COLORS.Bronze
		burst(color, 70, NumberRange.new(16, 34), 1.6, 1.8)
		burst(Color3.new(1, 1, 1), 30, NumberRange.new(8, 20), 1.2, 1.1)
	end
end

function FxController:Init()
	DashController.Event:Connect(onDashEvent)
end

function FxController:Start() end

return FxController
