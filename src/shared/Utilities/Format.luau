--!strict
-- Language-neutral number formatting for the UI. Pure.

local Format = {}

-- 62_345 ms -> "1:02.3"; 9_870 ms -> "0:09.8". Tenths are truncated, never rounded up.
function Format.time(ms: number): string
	local safe = if ms ~= ms or ms < 0 then 0 else math.floor(ms)
	local tenths = math.floor(safe / 100)
	local minutes = math.floor(tenths / 600)
	local seconds = math.floor(tenths / 10) % 60
	return string.format("%d:%02d.%d", minutes, seconds, tenths % 10)
end

-- 1234567 -> "1 234 567" (thin grouping that reads correctly in English and Russian).
function Format.integer(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local grouped = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	return (if n < 0 then "-" else "") .. grouped
end

return Format
