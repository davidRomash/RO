--!strict
-- Small helpers shared by server and client.

local Util = {}

function Util.FormatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

function Util.FormatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Util.Ordinal(n: number): string
	local suffix = "th"
	local lastTwo = n % 100
	if lastTwo < 11 or lastTwo > 13 then
		local last = n % 10
		if last == 1 then
			suffix = "st"
		elseif last == 2 then
			suffix = "nd"
		elseif last == 3 then
			suffix = "rd"
		end
	end
	return tostring(n) .. suffix
end

return Util
