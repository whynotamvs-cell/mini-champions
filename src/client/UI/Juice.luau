--!strict
-- Small, cheap UI animations ("juice"): pops, count-ups, fades. Client-only and purely
-- cosmetic. Every helper does nothing (or jumps straight to the end state) when reduced
-- motion is on (TEST_PLAN U-05). The Settings screen will drive setReducedMotion.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Juice = {}

local reducedMotion = false

function Juice.setReducedMotion(value: boolean)
	reducedMotion = value
end

function Juice.isReducedMotion(): boolean
	return reducedMotion
end

local function scaleOf(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild("JuiceScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local created = Instance.new("UIScale")
	created.Name = "JuiceScale"
	created.Parent = gui
	return created
end

-- Starts at `from` x size and bounces back to normal size. Anchor the element at its centre
-- (AnchorPoint 0.5) if the pop should grow from the middle.
function Juice.pop(gui: GuiObject, from: number?, duration: number?)
	if reducedMotion then
		return
	end
	local uiScale = scaleOf(gui)
	uiScale.Scale = from or 1.3
	TweenService
		:Create(
			uiScale,
			TweenInfo.new(duration or 0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		:Play()
end

-- Eases an integer from `from` to `to`, calling step(n) each frame. step(to) is always the
-- last call unless isCancelled() turns true first.
function Juice.tweenNumber(from: number, to: number, duration: number, step: (number) -> (), isCancelled: () -> boolean)
	if reducedMotion or duration <= 0 or from == to then
		step(to)
		return
	end
	task.spawn(function()
		local startedAt = os.clock()
		while not isCancelled() do
			local alpha = math.clamp((os.clock() - startedAt) / duration, 0, 1)
			local eased = 1 - (1 - alpha) ^ 3
			step(math.round(from + (to - from) * eased))
			if alpha >= 1 then
				return
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

-- Fades a full-screen cover (and its labels) out, then destroys it.
function Juice.fadeOutAndDestroy(frame: Frame, duration: number?)
	if reducedMotion then
		frame:Destroy()
		return
	end
	local info = TweenInfo.new(duration or 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(frame, info, { BackgroundTransparency = 1 })
	for _, child in frame:GetDescendants() do
		if child:IsA("TextLabel") then
			TweenService:Create(child, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end
	tween.Completed:Once(function()
		frame:Destroy()
	end)
	tween:Play()
end

return Juice
