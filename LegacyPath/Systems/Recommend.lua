-- Ranks unfinished challenges. Pure functions over objective states; no game API.
-- score = progress (0-100) + 25 if this character can work on it now
--         - 30 if an earlier tier is unfinished + up to 10 for lower estimated difficulty.
local _, ns = ...

local R = {}
ns.Recommend = R

local function bestAlt(class, chars, skip)
	local best
	for key, c in pairs(chars) do
		if key ~= skip and c.class == class and (not best or c.level > best.level) then best = c end
	end
	return best
end

-- What is left to do, in words, from the data we actually have.
function R.Remaining(s, player)
	local crit = s.criteria
	if s.done then
		return "Complete"
	elseif #crit == 1 and crit[1].req > 1 then
		return ("%d more - %s (%d / %d)"):format(crit[1].req - crit[1].q, crit[1].text, crit[1].q, crit[1].req)
	elseif #crit > 1 then
		local left = {}
		for _, c in ipairs(crit) do
			if not c.done then left[#left + 1] = c.text end
		end
		return ("%d of %d left: %s%s"):format(#left, #crit, table.concat(left, ", ", 1, math.min(3, #left)), #left > 3 and ", ..." or "")
	elseif s.source == "derived" and player then
		return ("%d more levels (%d / %d)"):format(s.o.level - player.level, player.level, s.o.level)
	end
	return s.desc or ""
end

-- ctx: { player, states, chars, key, prefs = { hideCats } }. Returns nil when not recommendable.
function R.Score(s, ctx)
	local o = s.o
	if s.done or (ctx.prefs.hideCats or {})[o.cat] then return nil end
	local frac, achievable, why = s.frac, true, {}
	if o.kind == "class" and o.class ~= ctx.player.class then
		achievable = false
		local alt = bestAlt(o.class, ctx.chars, ctx.key)
		frac = alt and math.min(alt.level / o.level, 1) or 0
		why[1] = alt and ("needs your %s %s (level %d when last seen)"):format(o.sub, alt.name, alt.level)
			or ("needs a %s character"):format(o.sub)
	elseif o.minLevel and ctx.player.level < o.minLevel then
		achievable = false
		why[1] = ("content starts at level %d"):format(o.minLevel)
	end
	local pre = o.prereq and ctx.states[o.prereq]
	local blocked = pre ~= nil and not pre.done
	if blocked then why[#why + 1] = "comes after " .. pre.name end
	if achievable and not blocked then why[#why + 1] = "this character can work on it now" end
	if frac > 0 then table.insert(why, 1, ("%d%% complete"):format(math.floor(frac * 100))) end
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
		local ctx = { player = P.player, states = P.states, chars = ns.db.chars, key = P.key, prefs = ns.db.settings }
		cache = {}
		for _, s in ipairs(P.list) do
			local r = R.Score(s, ctx)
			if r then
				r.remaining = R.Remaining(s, ctx.player)
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
