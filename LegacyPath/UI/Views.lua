-- The four tabs and the settings page. Each view returns row descriptions for UI/MainWindow.lua to draw.
local _, ns = ...

local UI, P, R, Planner, D = ns.UI, ns.Progress, ns.Recommend, ns.Planner, ns.Data
local GREEN, GREY = "|cff40c040", "|cff808080"
local SOURCE = {
	live = "live from the game client",
	derived = "worked out from your closest character's level",
	manual = "manual tracking (the client reported no data)",
}

-- Categories drawn as a grid: one row per class or profession, one column per tier.
local GRID = { Classes = { "Novice", "Experienced", "Master" }, Tradeskills = { "Journeyman", "Expert", "Artisan" } }
local REWARDS, ICONS = "Rewards and perks", "Interface\\Icons\\"

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

-- A challenge row. `o` may override detail and right, and replace the Pin button with other actions.
local function objective(s, o)
	o = o or {}
	local actions = o.actions or { { Planner.IsPinned(s.id) and "Unpin" or "Pin", "Add to or remove from your plan", function() Planner.Toggle(s.id) end } }
	if s.source == "manual" then
		actions[#actions + 1] = { s.done and "Undo" or "Done", "Tick this off by hand", function() P.SetManual(s.id, not s.done) end }
	end
	local count = R.Count(s)
	local detail = s.done and (s.desc or "") or R.Remaining(s):gsub(" %(%d+ / %d+%)", "") -- the bar has the numbers
	return {
		title = (s.done and GREEN or "") .. s.name, right = o.right or (s.done and "Done" or nil), icon = s.icon, detail = o.detail or detail,
		frac = not s.done and (count or s.frac > 0) and s.frac or nil, bar = count or pct(s.frac),
		tip = tip(s, o.tip), actions = actions,
	}
end

UI.views.dashboard = function()
	local sum, out = P.Summary(), {}
	local function add(row) out[#out + 1] = row end
	if not P.live then
		add({ title = "|cffff8040Live Legacy data is unavailable|r", detail = "Manual mode: tick challenges off in the Challenges tab." })
	end
	add({ title = "Legacy Points", right = "account-wide", icon = ICONS .. "INV_Misc_Map_01",
		frac = sum.points / math.max(sum.total, 1), bar = ("%d / %d"):format(sum.points, sum.total),
		tip = { "Legacy Points", ("Each character can spend up to %d in the Legacy panel."):format(ns.Reference.spendCap) } })
	local unspent = P.points and P.points.available or 0
	if unspent > 0 then
		add({ title = ("%d unspent Legacy Point%s"):format(unspent, unspent == 1 and "" or "s"),
			detail = "This character can spend " .. (unspent == 1 and "it" or "them") .. " in the Legacy panel's perk trees." })
	end

	add({ header = true, title = "Do this next" })
	local list = R.List(UI.more and 15 or 5)
	if #list == 0 then add({ title = "Nothing to recommend", detail = "Everything is done or hidden by your settings." }) end
	for i, r in ipairs(list) do
		if i == 2 then add({ header = true, title = "Close behind" }) end
		add(objective(r.s, { right = ("%s - est. %s"):format(r.s.o.sub, ns.DIFFICULTY[r.s.o.diff]:lower()), tip = "Why: " .. r.why }))
	end
	if #list >= 5 then
		add({ cells = { { text = UI.more and "Show fewer" or "Show more", onClick = function() UI.more = not UI.more; UI.Render() end } } })
	end

	add({ header = true, title = "Categories" })
	local cells = {}
	for _, cat in ipairs(D.categories) do
		local c = sum.cats[cat]
		if c then
			cells[#cells + 1] = { text = ("%s  %d / %d"):format(cat, c.done, c.total), frac = c.done / c.total, onClick = function() UI.Show("objectives", cat) end }
		end
	end
	for i = 1, #cells, 3 do
		add({ cells = { cells[i], cells[i + 1], cells[i + 2] } })
	end

	add({ header = true, title = "Recently completed" })
	for _, s in ipairs(sum.recent) do
		add({ title = GREEN .. s.name, right = s.date and ymd(s.date) or "", detail = s.o.cat, icon = s.icon, tip = tip(s) })
	end
	if #sum.recent == 0 then add({ title = "No challenges completed yet" }) end
	return out
end

local function rewards()
	local out = { { title = "For reference", lines = 2,
		detail = "Blizzard has not published unlock thresholds or perk costs. Spend points in the game's Legacy panel." } }
	for _, reward in ipairs(ns.Reference.rewards) do
		out[#out + 1] = { title = reward.name, right = reward.kind }
	end
	for _, tree in ipairs(ns.Reference.perks) do
		local perks = table.concat(tree, ", ")
		out[#out + 1] = { title = tree.tree .. " perks", detail = perks, lines = 3, tip = { tree.tree .. " perks", perks } }
	end
	return out
end

-- Grid rows for a category, then list rows for challenges a patch added.
local function grid(cat, list)
	local out, bySub, added = { { title = " ", cells = {} } }, {}, {}
	for i, tier in ipairs(GRID[cat]) do out[1].cells[i] = { text = "|cffffd100" .. tier .. "|r" } end
	for _, s in ipairs(list) do
		local pinned = Planner.IsPinned(s.id)
		if s.o.uncatalogued then
			added[#added + 1] = objective(s)
		else
			local row = bySub[s.o.sub]
			if not row then
				local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[s.o.class]
				row = { title = ("|c%s%s|r"):format(color and color.colorStr or "ffffffff", s.o.sub), cells = {} }
				bySub[s.o.sub], out[#out + 1] = row, row
			end
			local click = not s.done and "Click to " .. (pinned and "unpin" or "pin") or nil
			row.cells[s.o.diff] = { text = pct(s.frac), frac = s.frac, done = s.done, pinned = pinned and not s.done, tip = tip(s, click),
				onClick = click and function() Planner.Toggle(s.id) end }
		end
	end
	for _, row in ipairs(added) do out[#out + 1] = row end
	return out
end

UI.views.objectives = function(text)
	local out, cat = {}, text == "" and (UI.cat or D.categories[1]) or nil -- a search covers every category
	if cat == REWARDS then return rewards() end
	local list = P.Filter(P.list, { cat = cat, text = text })
	if cat and GRID[cat] and P.live then return grid(cat, list) end -- manual mode needs rows, for their Done buttons
	for _, s in ipairs(P.Filter(list, { hideDone = ns.db.settings.hideDone })) do
		out[#out + 1] = objective(s)
	end
	if #out == 0 then out[1] = { title = cat and "Nothing left to do here" or "No challenge matches your search" } end
	return out
end

local function categories()
	local sum, out = P.Summary(), {}
	local function add(title, right)
		out[#out + 1] = { title = title, right = right, selected = title == (UI.cat or D.categories[1]), onClick = function() UI.Show("objectives", title) end }
	end
	for _, cat in ipairs(D.categories) do
		local c = sum.cats[cat]
		if c then add(cat, ("%d / %d"):format(c.done, c.total)) end
	end
	add(REWARDS)
	return out
end

UI.tabs = {
	{ key = "dashboard", label = "Overview" }, { key = "objectives", label = "Challenges", search = true, side = categories },
	{ key = "planner", label = "Plan", search = true }, { key = "characters", label = "Characters" },
}

UI.views.planner = function(text)
	local out = {}
	for _, s in ipairs(P.Filter(Planner.List(), { text = text })) do
		local note = ns.db.notes[s.id]
		out[#out + 1] = objective(s, { detail = note and "Note: " .. note or nil, actions = {
			{ "Unpin", "Remove from your plan", function() Planner.Toggle(s.id) end, "Interface\\Buttons\\UI-GroupLoot-Pass-Up" },
			{ "Note", "Write a note", function() UI.EditNote(s) end, "Interface\\Buttons\\UI-GuildButton-PublicNote-Up" },
			{ "Down", "Move down", function() Planner.Move(s.id, 1) end, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up" },
			{ "Up", "Move up", function() Planner.Move(s.id, -1) end, "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up" },
		} })
	end
	if #out == 0 then
		out[1] = text ~= "" and { title = "Nothing in your plan matches your search" }
			or { title = "Your plan is empty", detail = "Use Pin on the Overview or Challenges tab." }
	end
	return out
end

UI.views.characters = function()
	local rows, keys, chars = {}, {}, ns.db.chars
	for key in pairs(chars) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return chars[a].seen > chars[b].seen end)
	rows[1] = { header = true, title = "Characters seen by LegacyPath", right = "Challenge progress is account-wide" }
	for _, key in ipairs(keys) do
		local c, current = chars[key], key == P.key
		local realm = c.realm ~= "" and " - " .. c.realm or ""
		local lines, info, near = { c.name .. realm, "Closest to:" }, {}, {}
		for _, s in ipairs(P.list) do
			if not s.done and not s.o.minLevel and s.closest and s.closest.key == key then
				lines[#lines + 1] = ("%s - %s"):format(s.name, pct(s.frac))
				if s.frac > 0 and not (s.o.prereq and not P.states[s.o.prereq].done) then near[#near + 1] = s.name end
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
			icon = c.class and ICONS .. "ClassIcon_" .. c.class,
			detail = table.concat(info, ", ") .. (#near > 0 and "\nClosest to: " .. table.concat(near, ", ") or ""), lines = #near > 0 and 2 or nil,
			tip = lines,
			actions = not current and { { "Forget", "Delete this snapshot", function() chars[key] = nil; P.Refresh(); UI.Render() end } } or nil,
		}
	end
	return rows
end

UI.views.settings = function()
	local st = ns.db.settings
	local function check(title, detail, on, fn)
		return { title = title, detail = detail, check = on, icon = "Interface\\Buttons\\UI-CheckBox-Up", onClick = fn }
	end
	local function toggle(title, detail, key)
		return check(title, detail, st[key], function()
			st[key] = not st[key]
			ns.Fire("SETTINGS")
			ns.Fire("CHANGED")
		end)
	end
	local rows = {
		toggle("Completion messages", "Print a chat line when a Legacy Challenge completes.", "notify"),
		toggle("Unspent points reminder", "A bubble by the Legacy button if this character has points to spend: at every login, and when you earn more.", "unspent"),
		toggle("Minimap button", "Show the LegacyPath button on the minimap.", "minimap"),
		toggle("Tooltip line", "Add a LegacyPath line to Legacy Challenge achievement tooltips.", "tooltip"),
		toggle("Hide completed challenges", "Leave them out of lists. The class and profession grids always show them.", "hideDone"),
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
		rows[#rows + 1] = check(cat, nil, not st.hideCats[cat], function()
			st.hideCats[cat] = not st.hideCats[cat] or nil
			ns.Fire("CHANGED")
		end)
	end
	return rows
end
