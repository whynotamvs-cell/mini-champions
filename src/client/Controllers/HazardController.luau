--!strict
-- Animates the timed hazards (lasers, sweeping bars) and presses the keys on Keyboard Dash.
-- Display only: the server evaluates the same formulas from the server time and decides every
-- hit (ObstacleDash). Hazard parameters are attributes on the parts under <Track>/Hazards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local HazardLogic = require(ReplicatedStorage.Shared.Utilities.HazardLogic)
local Juice = require(script.Parent.Parent.UI.Juice)

local HazardController = {}

type Laser = { part: BasePart, period: number, onSec: number, phase: number }
type Spinner = { part: BasePart, base: Vector3, speed: number, phase: number }

local WARNING_SEC = 0.7
local KEY_DEPTH = 0.7
local KEY_RELEASE_DELAY = 0.12
local KEY_PART_PATTERNS = { "^Key%d+$", "^ZigKey%d+$", "^ArrowKey%d+$", "^EnterStep%d+$" }

local lasers: { Laser } = {}
local spinners: { Spinner } = {}
-- Pressed keys: part -> { rest = CFrame, lastContact = clock }
local pressed: { [BasePart]: { rest: CFrame, lastContact: number } } = {}

local function isKeyName(name: string): boolean
	for _, pattern in KEY_PART_PATTERNS do
		if string.match(name, pattern) then
			return true
		end
	end
	return false
end

local function collectHazards(track: Instance)
	local folder = track:FindFirstChild("Hazards")
	if folder == nil then
		return
	end
	for _, part in folder:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local kind = part:GetAttribute("HazardKind")
		if kind == "Laser" then
			table.insert(lasers, {
				part = part,
				period = tonumber(part:GetAttribute("Period")) or 3,
				onSec = tonumber(part:GetAttribute("OnSec")) or 1,
				phase = tonumber(part:GetAttribute("Phase")) or 0,
			})
		elseif kind == "Spinner" then
			table.insert(spinners, {
				part = part,
				base = part.Position,
				speed = tonumber(part:GetAttribute("Speed")) or 1,
				phase = tonumber(part:GetAttribute("Phase")) or 0,
			})
		end
	end
end

local function pressKey(part: BasePart)
	local state = pressed[part]
	if state then
		state.lastContact = os.clock()
		return
	end
	pressed[part] = { rest = part.CFrame, lastContact = os.clock() }
	local goal = part.CFrame - Vector3.new(0, KEY_DEPTH, 0)
	TweenService:Create(part, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal })
		:Play()
end

local function releaseKeys(now: number)
	for part, state in pressed do
		if now - state.lastContact > KEY_RELEASE_DELAY then
			pressed[part] = nil
			TweenService
				:Create(
					part,
					TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ CFrame = state.rest }
				)
				:Play()
		end
	end
end

local function connectKeys(track: Instance)
	local geometry = track:FindFirstChild("Geometry")
	if geometry == nil then
		return
	end
	for _, part in geometry:GetChildren() do
		if part:IsA("BasePart") and isKeyName(part.Name) then
			part.Touched:Connect(function(hit: BasePart)
				local character = Players.LocalPlayer.Character
				-- Only feet on top press the key, not a shoulder against its side.
				if
					character
					and hit:IsDescendantOf(character)
					and hit.Position.Y > part.Position.Y + part.Size.Y / 2 - 0.5
				then
					pressKey(part)
				end
			end)
		end
	end
end

local function step()
	local t = Workspace:GetServerTimeNow()
	local calm = Juice.isReducedMotion()
	for _, laser in lasers do
		local untilOn = HazardLogic.secondsUntilOn(t, laser.period, laser.onSec, laser.phase)
		local transparency: number
		if untilOn == 0 then
			transparency = 0.05
		elseif untilOn < WARNING_SEC and not calm then
			-- warning flicker: faster as the beam is about to fire
			transparency = if math.floor(t * 12) % 2 == 0 then 0.8 else 0.93
		elseif untilOn < WARNING_SEC then
			transparency = 0.8
		else
			transparency = 0.96
		end
		laser.part.Transparency = transparency
	end
	for _, spinner in spinners do
		local angle = HazardLogic.spinnerAngle(t, spinner.speed, spinner.phase)
		spinner.part.CFrame = CFrame.new(spinner.base) * CFrame.Angles(0, -angle, 0)
	end
	releaseKeys(os.clock())
end

function HazardController:Init() end

function HazardController:Start()
	local deskWorld = Workspace:WaitForChild("DeskWorld", 30)
	if deskWorld == nil then
		return
	end
	for _, trackId in Tracks.Order do
		local track = deskWorld:WaitForChild(Tracks.ById[trackId].WorldName, 10)
		if track then
			collectHazards(track)
			if trackId == "keys" then
				connectKeys(track)
			end
		end
	end
	RunService.Heartbeat:Connect(step)
end

return HazardController
