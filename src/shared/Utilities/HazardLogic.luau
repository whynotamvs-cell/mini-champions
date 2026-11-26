--!strict
-- Pure time-based hazard maths shared by the server (hit tests) and the client (visuals).
-- Hazards are deterministic functions of Workspace:GetServerTimeNow(), so nothing replicates per
-- frame: both sides evaluate the same formulas. Numbers only (no Roblox types) so it runs in Lune.

local HazardLogic = {}

-- Margin added around a hazard when testing a player: the root part is not a point.
HazardLogic.HitPad = 0.8

-- A pulsing laser: on for `onSec` out of every `period` seconds, shifted by `phase`.
function HazardLogic.laserOn(t: number, period: number, onSec: number, phase: number): boolean
	if period <= 0 then
		return false
	end
	return (t + phase) % period < onSec
end

-- Seconds until a laser switches on (0 while on). Drives the warning flicker.
function HazardLogic.secondsUntilOn(t: number, period: number, onSec: number, phase: number): number
	if period <= 0 then
		return math.huge
	end
	local local_t = (t + phase) % period
	if local_t < onSec then
		return 0
	end
	return period - local_t
end

-- Angle in radians of a spinner bar at time t.
function HazardLogic.spinnerAngle(t: number, speed: number, phase: number): number
	return t * speed + phase
end

-- Axis-aligned box test (lasers). Centre (cx,cy,cz), full sizes (sx,sy,sz).
function HazardLogic.inBox(
	px: number,
	py: number,
	pz: number,
	cx: number,
	cy: number,
	cz: number,
	sx: number,
	sy: number,
	sz: number
): boolean
	local pad = HazardLogic.HitPad
	return math.abs(px - cx) <= sx / 2 + pad and math.abs(py - cy) <= sy / 2 + pad and math.abs(pz - cz) <= sz / 2 + pad
end

-- A bar of `length` x `width` (plan view), `height` tall, centred on (cx,cy,cz), turned by `angle` about Y.
function HazardLogic.inBar(
	px: number,
	py: number,
	pz: number,
	cx: number,
	cy: number,
	cz: number,
	length: number,
	height: number,
	width: number,
	angle: number
): boolean
	local pad = HazardLogic.HitPad
	if math.abs(py - cy) > height / 2 + pad then
		return false
	end
	local dx, dz = px - cx, pz - cz
	local c, s = math.cos(angle), math.sin(angle)
	local along = dx * c + dz * s
	local across = -dx * s + dz * c
	return math.abs(along) <= length / 2 + pad and math.abs(across) <= width / 2 + pad
end

return HazardLogic
