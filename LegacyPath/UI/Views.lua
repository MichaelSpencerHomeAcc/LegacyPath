-- The six tabs. Each returns row descriptions for UI/MainWindow.lua to draw.
local _, ns = ...

local UI, P, R, Planner, D = ns.UI, ns.Progress, ns.Recommend, ns.Planner, ns.Data
local GREEN, GREY, ON = "|cff40c040", "|cff808080", "|cff40c040On|r"
local SOURCE = {
	live = "live from the game client",
	derived = "worked out from your closest character's level",
	manual = "manual tracking (the client reported no data)",
}

UI.tabs = {
	{ key = "dashboard", label = "Dashboard" }, { key = "next", label = "Next steps" }, { key = "objectives", label = "Objectives" },
	{ key = "planner", label = "Planner" }, { key = "characters", label = "Characters" }, { key = "settings", label = "Settings" },
}

local function pct(frac) return math.floor(frac * 100) .. "%" end

local function ymd(n) return ("%04d-%02d-%02d"):format(math.floor(n / 10000), math.floor(n / 100) % 100, n % 100) end

local function tip(s, extra)
	local t = { s.name, s.desc or "" }
	for _, c in ipairs(s.criteria) do
		t[#t + 1] = (c.done and GREEN or GREY) .. c.text .. (c.req > 1 and (" (%d / %d)"):format(c.q, c.req) or "") .. "|r"
	end
	t[#t + 1] = " "
	t[#t + 1] = s.o.cat .. (s.o.sub ~= s.o.cat and " - " .. s.o.sub or "")
	t[#t + 1] = "Reward: 1 Legacy Point (account-wide)"
	t[#t + 1] = "Estimated difficulty: " .. ns.DIFFICULTY[s.o.diff] .. " (a rough guide, not a measurement)"
	t[#t + 1] = "Progress data: " .. SOURCE[s.source]
	if s.closest and not s.done and not s.o.minLevel then
		t[#t + 1] = "Closest character: " .. s.closest.name .. (s.closest.here and " (this character)" or " (when last seen)")
	end
	if ns.db.notes[s.id] then t[#t + 1] = "Note: " .. ns.db.notes[s.id] end
	if extra then t[#t + 1] = extra end
	return t
end

-- A challenge row. `o` may override detail/right and add actions and a tooltip line.
local function objective(s, o)
	o = o or {}
	local actions = o.actions or {}
	table.insert(actions, 1, { Planner.IsPinned(s.id) and "Unpin" or "Pin", "Add to or remove from your plan", function() Planner.Toggle(s.id) end })
	if s.source == "manual" then
		actions[#actions + 1] = { s.done and "Undo" or "Done", "Tick this off by hand", function() P.SetManual(s.id, not s.done) end }
	end
	return {
		title = (s.done and GREEN or "") .. s.name,
		right = o.right or (s.done and "Done" or pct(s.frac)),
		detail = o.detail or R.Remaining(s),
		frac = s.frac, tip = tip(s, o.tip), actions = actions,
	}
end

local function recommendation(r)
	return objective(r.s, {
		right = ("%s - Est. %s"):format(r.s.o.sub, ns.DIFFICULTY[r.s.o.diff]:lower()),
		detail = ("%s  %s(%s)|r"):format(r.remaining, GREY, r.why),
		tip = "Why: " .. r.why,
	})
end

UI.views.dashboard = function()
	local sum, rows = P.Summary(), {}
	local function add(row) rows[#rows + 1] = row end
	if not P.live then
		add({ title = "|cffff8040Live Legacy data is unavailable|r", detail = "Manual mode: tick challenges off in the Objectives tab." })
	end
	add({ title = "Legacy Points", right = ("%d / %d"):format(sum.points, sum.total), frac = sum.points / math.max(sum.total, 1),
		detail = ("Account-wide. Each character can spend up to %d in the Legacy panel."):format(ns.Reference.spendCap) })

	local unspent = P.points and P.points.available or 0
	if unspent > 0 then
		add({ title = ("|cffffd100%d unspent Legacy Point%s|r"):format(unspent, unspent == 1 and "" or "s"),
			detail = "This character can spend " .. (unspent == 1 and "it" or "them") .. " in the Legacy panel's perk trees." })
	end

	add({ header = true, title = "Next step" })
	local best = R.List(1)[1]
	add(best and recommendation(best) or { title = "Nothing to recommend", detail = "Everything is done or hidden by your settings." })

	add({ header = true, title = "Categories" })
	for _, cat in ipairs(D.categories) do
		local c = sum.cats[cat]
		if c then
			add({ title = cat, right = ("%d / %d"):format(c.done, c.total), frac = c.done / c.total, detail = "Click to browse",
				onClick = function() UI.Show("objectives", cat) end })
		end
	end

	add({ header = true, title = "Recently completed" })
	for _, s in ipairs(sum.recent) do
		add({ title = GREEN .. s.name, right = s.date and ymd(s.date) or "", detail = s.o.cat, tip = tip(s) })
	end
	if #sum.recent == 0 then add({ title = "No challenges completed yet" }) end

	add({ header = true, title = "Rewards and perks (reference)" })
	for _, reward in ipairs(ns.Reference.rewards) do
		add({ title = reward.name, right = reward.kind, detail = "Unlock threshold not published - see the Legacy panel" })
	end
	local perks = { "Legacy perk trees", "Costs are not published; spend points in the Legacy panel." }
	for _, tree in ipairs(ns.Reference.perks) do
		perks[#perks + 1] = tree.tree .. ": " .. table.concat(tree, ", ")
	end
	add({ title = "Legacy perk trees", right = "3 trees", detail = "Professions, Adventure, Resourcefulness - hover for the perks", tip = perks })
	return rows
end

UI.views.next = function(text)
	local rows = {}
	for _, r in ipairs(R.List()) do
		if #rows < 15 and #P.Filter({ r.s }, { text = text }) > 0 then rows[#rows + 1] = recommendation(r) end
	end
	if #rows == 0 then rows[1] = { title = "Nothing to recommend", detail = "Everything is done, hidden by your settings, or filtered out." } end
	return rows
end

UI.views.objectives = function(text)
	local rows, collapsed = {}, ns.db.collapsed
	for _, cat in ipairs(D.categories) do
		local all = P.Filter(P.list, { cat = cat })
		local shown = P.Filter(all, { text = text, hideDone = ns.db.settings.hideDone })
		if #all > 0 and (#shown > 0 or text == "") then
			local closed = collapsed[cat] and text == ""
			rows[#rows + 1] = { header = true, title = (closed and "+ " or "- ") .. cat,
				right = ("%d / %d"):format(#all - #P.Filter(all, { hideDone = true }), #all),
				onClick = function() collapsed[cat] = not collapsed[cat] or nil; UI.Render() end }
			for _, s in ipairs(closed and {} or shown) do
				rows[#rows + 1] = objective(s)
			end
		end
	end
	return rows
end

UI.views.planner = function(text)
	local rows = {}
	for _, s in ipairs(P.Filter(Planner.List(), { text = text })) do
		local note = ns.db.notes[s.id]
		rows[#rows + 1] = objective(s, { detail = note and "Note: " .. note or nil, actions = {
			{ "Note", "Write a note", function() UI.EditNote(s) end },
			{ "Down", "Move down", function() Planner.Move(s.id, 1) end },
			{ "Up", "Move up", function() Planner.Move(s.id, -1) end },
		} })
	end
	if #rows == 0 then rows[1] = { title = "Your plan is empty", detail = "Use Pin on the Next steps or Objectives tab." } end
	return rows
end

UI.views.characters = function()
	local rows, keys, chars = {}, {}, ns.db.chars
	for key in pairs(chars) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return chars[a].seen > chars[b].seen end)
	rows[1] = { header = true, title = "Characters seen by LegacyPath", right = "Challenge progress is account-wide" }
	for _, key in ipairs(keys) do
		local c, current = chars[key], key == P.key
		local realm = c.realm ~= "" and " - " .. c.realm or ""
		local lines, info = { c.name .. realm, "Closest to:" }, {}
		for _, s in ipairs(P.list) do
			if not s.done and not s.o.minLevel and s.closest and s.closest.key == key then
				lines[#lines + 1] = ("%s - %s"):format(s.name, pct(s.frac))
			end
			local skill = s.o.skillLine and c.profs and (c.profs[s.o.skillLine] or c.profs[s.o.sub])
			if skill and not info[s.o.sub] then
				info[s.o.sub] = true
				info[#info + 1] = s.o.sub .. " " .. skill
			end
		end
		if #lines == 2 then lines[2] = "Not the closest to any challenge" end
		if (c.unspent or 0) > 0 then info[#info + 1] = c.unspent .. " unspent" end
		info[#info + 1] = current and "live this session" or "snapshot from " .. date("%Y-%m-%d", c.seen)
		local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
		rows[#rows + 1] = {
			title = (color and color.colorStr and "|c" .. color.colorStr or "") .. c.name .. "|r" .. realm,
			right = ("Level %d %s"):format(c.level, c.className or ""),
			detail = table.concat(info, ", "),
			tip = lines,
			actions = not current and { { "Forget", "Delete this snapshot", function() chars[key] = nil; P.Refresh(); UI.Render() end } } or nil,
		}
	end
	return rows
end

UI.views.settings = function()
	local st = ns.db.settings
	local function toggle(title, detail, key)
		return { title = title, detail = detail, right = st[key] and ON or "Off", onClick = function()
			st[key] = not st[key]
			ns.Fire("SETTINGS")
			ns.Fire("CHANGED")
		end }
	end
	local rows = {
		toggle("Completion messages", "Print a chat line when a Legacy Challenge completes.", "notify"),
		toggle("Unspent points reminder", "A bubble by the Legacy button if this character has points to spend: at every login, and when you earn more.", "unspent"),
		toggle("Minimap button", "Show the LegacyPath button on the minimap.", "minimap"),
		toggle("Tooltip line", "Add a LegacyPath line to Legacy Challenge achievement tooltips.", "tooltip"),
		toggle("Hide completed objectives", "Leave finished challenges out of the Objectives tab.", "hideDone"),
		toggle("Quest tracker section", "Show your unfinished pinned challenges under the quest tracker.", "tracker"),
		toggle("Dock under the quest tracker", "Off after you drag the section somewhere else. Turn on to dock it again.", "trackerDock"),
		{ title = "Challenges in the tracker", right = tostring(st.trackerMax), detail = "Shows the first ones in your plan order.", actions = {
			{ "+", "More", function() st.trackerMax = math.min(st.trackerMax + 1, 5); ns.Fire("CHANGED") end },
			{ "-", "Fewer", function() st.trackerMax = math.max(st.trackerMax - 1, 1); ns.Fire("CHANGED") end },
		} },
		{ title = "Window scale", right = pct(st.scale), detail = "Or type /lp scale 0.6 to 1.6", actions = {
			{ "+", "Larger", function() UI.SetScale(st.scale + 0.1) end },
			{ "-", "Smaller", function() UI.SetScale(st.scale - 0.1) end },
		} },
		{ title = "Reset window position", detail = "Click to move the window back to the centre.", onClick = UI.ResetPosition },
		{ header = true, title = "Recommend challenges from" },
	}
	for _, cat in ipairs(D.categories) do
		rows[#rows + 1] = { title = cat, right = st.hideCats[cat] and "Off" or ON, onClick = function()
			st.hideCats[cat] = not st.hideCats[cat] or nil
			ns.Fire("CHANGED")
		end }
	end
	return rows
end
