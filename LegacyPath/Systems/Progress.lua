-- Turns adapter data into objective states, detects changes, and snapshots characters.
-- state.source: "live" (client data), "derived" (from character level), "manual" (user ticks).
local _, ns = ...

local D = ns.Data
local P = { states = {}, list = {} }
ns.Progress = P

-- The known character furthest along on a challenge that belongs to one character (a class level
-- or a profession skill), or the highest one that meets a dungeon band's level. Nil when unknown.
local function closest(o, criteria)
	local best
	for key, c in pairs(ns.db.chars) do
		local value
		if o.kind == "class" then
			value = c.class == o.class and c.level or nil
		elseif o.skillLine then
			value = c.profs and (c.profs[o.skillLine] or c.profs[o.sub])
		elseif o.minLevel then
			value = c.level >= o.minLevel and c.level or nil
		end
		local here = key == P.key
		if value and (not best or value > best.value or (value == best.value and (here or (not best.here and key < best.key)))) then
			best = { key = key, name = c.name, value = value, here = here }
		end
	end
	-- A character LegacyPath has not recorded is further along: name nobody rather than the wrong one.
	if best and o.skillLine and criteria[1] and criteria[1].q > best.value then return nil end
	return best
end

local function fraction(o, live, best)
	local crit = live and live.criteria or {}
	if #crit == 1 and crit[1].req > 1 then
		return math.min(crit[1].q / crit[1].req, 1), "live"
	elseif #crit > 0 then
		local n = 0
		for _, c in ipairs(crit) do
			if c.done then n = n + 1 end
		end
		return n / #crit, "live"
	elseif o.kind == "class" and best then
		return math.min(best.value / o.level, 1), "derived"
	end
	return 0, live and "live" or "manual"
end

-- Stores what really belongs to this character. Returns the snapshot and the previous unspent count.
local function snapshot(player, points)
	if not player.class then return end
	local chars = ns.db.chars
	P.key = player.first and player.name or player.name .. "-" .. player.realm
	local old = chars[P.key]
	if player.first then -- replaces what was saved for this character under its first name only
		for key, c in pairs(chars) do
			if not c.first and c.name == player.first and c.class == player.class then
				old, chars[key] = old or c, nil
			end
		end
	end
	old = old or {}
	local snap = { name = player.name, first = player.first, realm = player.realm, class = player.class, className = player.className,
		level = player.level, profs = player.profs or {}, seen = ns.API.Now(),
		unspent = points and points.available or old.unspent }
	chars[P.key] = snap
	return snap, old.unspent
end

-- Rebuilds every state. Returns the challenges completed since the previous refresh.
function P.Refresh()
	local api, db = ns.API, ns.db
	local player, live = api.Player(), api.Available()
	if live and not P.discovered then
		for id, path in pairs(api.Discover()) do
			P.discovered = true
			if not D.byId[id] then
				D.Add({ id = id, name = "Legacy Challenge " .. id, cat = path.cat, sub = path.sub, uncatalogued = true })
			end
		end
	end
	local points, before = api.Points(), P.points and P.points.available
	local snap, known = snapshot(player, points) -- first, so closest() sees this character
	local newly, changed, list = {}, (points and points.available) ~= before, {}
	for i, o in ipairs(D.list) do
		local c = live and api.Challenge(o.id) or nil
		local best = closest(o, c and c.criteria or {})
		local frac, source = fraction(o, c, best)
		local done = c and c.done or (not c and db.manual[o.id] == true)
		local s = { id = o.id, o = o, name = c and c.name or o.name, desc = c and c.desc or o.req, icon = c and c.icon, done = done,
			date = c and c.date, criteria = c and c.criteria or {}, frac = done and 1 or frac, source = source,
			closest = best, who = best and best.key .. best.value }
		local old = P.states[o.id]
		if old and done and not old.done then newly[#newly + 1] = s end
		if not old or old.done ~= done or old.frac ~= s.frac or old.who ~= s.who then changed = true end
		P.states[o.id], list[i] = s, s
	end
	P.list, P.live, P.player, P.points = list, live, player, points
	if changed then ns.Fire("CHANGED") end
	-- Unspent points: remind at every login (P.login is set by Init.lua; a reload is not one),
	-- and whenever there are more than this character last had.
	if snap and points then
		local login = P.login
		P.login = nil
		if db.settings.unspent and points.available > 0 and (login or points.available > (known or 0)) then
			ns.Fire("UNSPENT", points.available)
		end
	end
	for _, s in ipairs(newly) do
		ns.Fire("COMPLETED", s)
	end
	return newly
end

-- Manual mode only: live data always wins.
function P.SetManual(id, done)
	ns.db.manual[id] = done and true or nil
	return P.Refresh()
end

function P.Summary()
	local sum = { points = 0, total = #P.list, cats = {}, recent = {} }
	for _, s in ipairs(P.list) do
		local c = sum.cats[s.o.cat] or { done = 0, total = 0 }
		sum.cats[s.o.cat] = c
		c.total = c.total + 1
		if s.done then
			c.done, sum.points = c.done + 1, sum.points + 1
			sum.recent[#sum.recent + 1] = s
		end
	end
	table.sort(sum.recent, function(a, b) return (a.date or 0) > (b.date or 0) end)
	for i = #sum.recent, 6, -1 do
		sum.recent[i] = nil
	end
	return sum
end

-- filter: { text = plain substring, cat = category, hideDone = bool }, all optional.
function P.Filter(list, filter)
	filter = filter or {}
	local text, out = (filter.text or ""):lower(), {}
	for _, s in ipairs(list) do
		local hay = (s.name .. " " .. s.o.cat .. " " .. s.o.sub .. " " .. (s.desc or "")):lower()
		if (text == "" or hay:find(text, 1, true))
			and (not filter.cat or filter.cat == s.o.cat)
			and not (filter.hideDone and s.done) then
			out[#out + 1] = s
		end
	end
	return out
end
