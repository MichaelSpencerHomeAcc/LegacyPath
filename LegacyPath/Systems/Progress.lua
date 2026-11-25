-- Turns adapter data into objective states, detects changes, and snapshots characters.
-- state.source: "live" (client data), "derived" (from character level), "manual" (user ticks).
local _, ns = ...

local D = ns.Data
local P = { states = {}, list = {} }
ns.Progress = P

local function fraction(o, live, player)
	local crit = live and live.criteria or {}
	if #crit == 1 and crit[1].req > 1 then
		return math.min(crit[1].q / crit[1].req, 1), "live"
	elseif #crit > 0 then
		local n = 0
		for _, c in ipairs(crit) do
			if c.done then n = n + 1 end
		end
		return n / #crit, "live"
	elseif o.kind == "class" and o.class == player.class and player.level > 0 then
		return math.min(player.level / o.level, 1), "derived"
	end
	return 0, live and "live" or "manual"
end

local function snapshot(player)
	if not player.class then return end
	local snap = { name = player.name, realm = player.realm, class = player.class, className = player.className,
		level = player.level, seen = ns.API.Now(), mine = {}, frac = {}, unspent = P.points and P.points.available }
	for _, s in ipairs(P.list) do
		if s.mine then
			snap.mine[s.id] = true
		elseif not s.done and s.frac > 0 then
			snap.frac[s.id] = s.frac
		end
	end
	P.key = player.name .. "-" .. player.realm
	ns.db.chars[P.key] = snap
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
	local newly, changed, list = {}, false, {}
	for i, o in ipairs(D.list) do
		local c = live and api.Challenge(o.id) or nil
		local frac, source = fraction(o, c, player)
		local done = c and c.done or (not c and db.manual[o.id] == true)
		local s = { id = o.id, o = o, name = c and c.name or o.name, desc = c and c.desc or o.req, done = done,
			mine = c and c.mine or false, date = c and c.date, criteria = c and c.criteria or {},
			frac = done and 1 or frac, source = source }
		local old = P.states[o.id]
		if old and done and not old.done then newly[#newly + 1] = s end
		if not old or old.done ~= done or old.frac ~= s.frac then changed = true end
		P.states[o.id], list[i] = s, s
	end
	local points, before = api.Points(), P.points and P.points.available
	if (points and points.available) ~= before then changed = true end
	P.list, P.live, P.player, P.points = list, live, player, points
	snapshot(player)
	if changed then ns.Fire("CHANGED") end
	-- Unspent points: say so once per session, and again whenever there are more to spend.
	if points and points.available > 0 and (before == nil or points.available > before) then
		ns.Fire("UNSPENT", points.available)
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
