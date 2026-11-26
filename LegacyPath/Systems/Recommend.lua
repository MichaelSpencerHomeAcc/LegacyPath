-- Ranks unfinished challenges. Pure functions over objective states; no game API.
-- score = progress (0-100) + 25 if this character is the closest, or high enough for a dungeon band
--         - 30 if an earlier tier is unfinished + up to 10 for lower estimated difficulty.
local _, ns = ...

local R = {}
ns.Recommend = R

-- " (Name)" when the closest character is not the one being played.
local function tag(s)
	return s.closest and not s.closest.here and not s.o.minLevel and (" (%s)"):format(s.closest.name) or ""
end

-- A counted step's name without its target number: "225 Tailoring Skill" -> "Tailoring Skill".
local function label(c)
	return (c.text:gsub("^" .. c.req .. "%s+", ""))
end

-- What is left to do, in words, from the data we actually have.
function R.Remaining(s)
	local crit = s.criteria
	if s.done then
		return "Complete"
	elseif #crit == 1 and crit[1].req > 1 then
		return ("%d more %s (%d / %d)%s"):format(crit[1].req - crit[1].q, label(crit[1]), crit[1].q, crit[1].req, tag(s))
	elseif #crit > 1 then
		local left = {}
		for _, c in ipairs(crit) do
			if not c.done then left[#left + 1] = c.text end
		end
		return ("%d of %d left: %s%s"):format(#left, #crit, table.concat(left, ", ", 1, math.min(3, #left)), #left > 3 and ", ..." or "")
	elseif s.source == "derived" then
		return ("%d more levels (%d / %d)%s"):format(s.o.level - s.closest.value, s.closest.value, s.o.level, tag(s))
	end
	return s.desc or ""
end

-- Progress as short text for a bar, or nil when there is nothing to count.
function R.Count(s)
	local crit, n = s.criteria, 0
	if #crit == 1 and crit[1].req > 1 then
		return ("%d / %d"):format(crit[1].q, crit[1].req)
	elseif #crit > 1 then
		for _, c in ipairs(crit) do
			if c.done then n = n + 1 end
		end
		return ("%d / %d"):format(n, #crit)
	elseif s.source == "derived" then
		return ("Level %d / %d"):format(s.closest.value, s.o.level)
	end
end

-- Quest-tracker style lines for an unfinished challenge: a counter, the steps left, or the requirement.
-- Also returns how many steps were left off the list (0 when none).
function R.Steps(s, max)
	max = max or 3
	local crit, out = s.criteria, {}
	if #crit == 1 and crit[1].req > 1 then
		out[1] = ("%d/%d %s%s"):format(crit[1].q, crit[1].req, label(crit[1]), tag(s))
	elseif #crit > 1 then
		local left = {}
		for _, c in ipairs(crit) do
			if not c.done then left[#left + 1] = c.text end
		end
		for i = 1, math.min(max, #left) do
			out[i] = left[i]
		end
		return out, math.max(#left - max, 0)
	elseif s.source == "derived" then
		out[1] = ("Level %d/%d%s"):format(s.closest.value, s.o.level, tag(s))
	else
		out[1] = s.desc or s.o.req
	end
	return out, 0
end

-- ctx: { player, states, prefs = { hideCats } }. Returns nil when not recommendable.
function R.Score(s, ctx)
	local o = s.o
	if s.done or (ctx.prefs.hideCats or {})[o.cat] then return nil end
	local frac, best, achievable, why = s.frac, s.closest, false, {}
	if o.kind == "class" or o.skillLine then
		achievable = best ~= nil and best.here
		if achievable then
			why[1] = "this character is closest"
		elseif best then
			why[1] = ("closest: %s, %s %d when last seen"):format(best.name, o.skillLine and o.sub or "level", best.value)
		elseif o.skillLine then
			why[1] = frac > 0 and "closest character not recorded yet" or ("no character recorded with %s"):format(o.sub)
		else
			why[1] = ("needs a %s character"):format(o.sub)
		end
	elseif o.minLevel then
		achievable = ctx.player.level >= o.minLevel
		why[1] = achievable and "this character can work on it now"
			or best and ("closest: %s, level %d when last seen"):format(best.name, best.value)
			or ("content starts at level %d"):format(o.minLevel)
	end
	local pre = o.prereq and ctx.states[o.prereq]
	local blocked = pre ~= nil and not pre.done
	if blocked then why[#why + 1] = "comes after " .. pre.name end
	if frac > 0 then table.insert(why, 1, ("%d%% complete"):format(math.floor(frac * 100))) end
	if #why == 0 then why[1] = "not started" end
	return {
		s = s, frac = frac, achievable = achievable, blocked = blocked, why = table.concat(why, "; "),
		score = frac * 100 + (achievable and 25 or 0) - (blocked and 30 or 0) + (3 - o.diff) * 5,
	}
end

local cache
ns.On("CHANGED", function() cache = nil end)

function R.List(limit)
	if not cache then
		local P = ns.Progress
		local ctx = { player = P.player, states = P.states, prefs = ns.db.settings }
		cache = {}
		for _, s in ipairs(P.list) do
			local r = R.Score(s, ctx)
			if r then
				r.remaining = R.Remaining(s)
				cache[#cache + 1] = r
			end
		end
		table.sort(cache, function(a, b)
			if a.score ~= b.score then return a.score > b.score end
			return a.s.id < b.s.id
		end)
	end
	local out = {}
	for i = 1, math.min(limit or #cache, #cache) do
		out[i] = cache[i]
	end
	return out
end
