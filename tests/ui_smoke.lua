-- UI smoke test. Run from the repo root:  luajit tests/ui_smoke.lua
-- Loads every file in the .toc order against a stub of the WoW widget API, then opens
-- each tab and presses every row and button. It catches Lua errors (typos, nil calls);
-- it cannot tell whether the real client draws anything correctly.
local ROOT = "LegacyPath/"

local frames = {}
local returns = {
	GetWidth = function() return 500 end, GetHeight = function() return 20 end, GetStringWidth = function() return 40 end, GetStringHeight = function() return 12 end,
	GetText = function(self) return self.text or "" end, SetText = function(self, t) self.text = t end,
	IsShown = function() return true end, GetSize = function() return 580, 460 end,
	GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end, GetCenter = function() return 0, 0 end,
	GetEffectiveScale = function() return 1 end,
	SetScript = function(self, name, fn) self.scripts[name] = fn end,
	HookScript = function(self, name, fn) self.scripts[name] = fn end,
}
local function widget()
	local w = { scripts = {} }
	frames[#frames + 1] = w
	return setmetatable(w, { __index = function(_, key)
		if not key:find("^[A-Z]") or key == "TitleText" or key == "EditBox" then return nil end -- a field, not a method
		if key == "GetFontString" or key == "GetParent" or key:find("^Create") then return function() return widget() end end
		return returns[key] or function() end
	end })
end

local function run(w, script, ...)
	if w.scripts[script] then w.scripts[script](w, ...) end
end

CreateFrame = function(_, _, _, template)
	local w = widget()
	if template == "BasicFrameTemplateWithInset" then w.TitleText = widget() end
	return w
end
UIParent, Minimap, GameTooltip, GameFontNormal, GameFontHighlight = widget(), widget(), widget(), widget(), widget()
UISpecialFrames, StaticPopupDialogs, SlashCmdList = {}, {}, {}
tinsert, date, time = table.insert, os.date, os.time
ACCEPT, CANCEL = "Accept", "Cancel"
RAID_CLASS_COLORS = { WARLOCK = { colorStr = "ff8788ee" } }
C_Timer = { After = function(_, fn) fn() end }
InCombatLockdown = function() return false end
GetCursorPosition = function() return 10, 10 end
StaticPopup_Show = function(which, _, _, data)
	local popup = widget()
	popup.EditBox = widget()
	StaticPopupDialogs[which].OnShow(popup, data)
	popup.EditBox.text = "a note"
	StaticPopupDialogs[which].OnAccept(popup, data)
end
ObjectiveTrackerFrame = widget()
ObjectiveTrackerFrame.NineSlice = widget()
local hooks = {}
Enum = { TooltipDataType = { Achievement = 1 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) hooks[#hooks + 1] = fn end }
local printed, panelCallback = 0, nil
EventRegistry = { RegisterCallback = function(_, _, fn) panelCallback = fn end }
print = function() printed = printed + 1 end

-- Load in .toc order.
local ns, files = {}, 0
for line in io.lines(ROOT .. "LegacyPath.toc") do
	if line:find("%.lua$") then
		assert(loadfile(ROOT .. line:gsub("\\", "/")))("LegacyPath", ns)
		files = files + 1
	end
end

-- A fake game: one finished challenge, one in progress, one with several criteria.
local world = { [62009] = { done = true, mine = true, date = 20261109 }, [62018] = { q = 135, req = 150 }, [62034] = { n = 13 } }
ns.API = {
	Available = function() return true end, Now = os.time, Discover = function() return {} end,
	Points = function() return { available = 2, cap = 16 } end,
	Player = function() return { name = "Main", realm = "Realm", class = "WARLOCK", className = "Warlock", level = 27 } end,
	Challenge = function(id)
		local c, crit = world[id] or {}, {}
		if c.req then crit[1] = { text = "Skill", done = false, q = c.q, req = c.req } end
		for i = 1, c.n or 0 do crit[i] = { text = "Boss " .. i, done = i < 3, q = 0, req = 1 } end
		return { name = ns.Data.byId[id].name, desc = "desc", done = c.done == true, mine = c.mine == true, date = c.date, criteria = crit }
	end,
}

for _, f in ipairs(frames) do run(f, "OnEvent", "ADDON_LOADED", "LegacyPath") end
for _, f in ipairs(frames) do run(f, "OnEvent", "PLAYER_ENTERING_WORLD", true, false) end
assert(#ns.Progress.list == 65, "progress loaded")
assert(printed >= 1, "unspent points reminder printed at login")
assert(ns.UI.views.dashboard("")[1].title:find("unspent", 1, true) or ns.UI.views.dashboard("")[2].title:find("unspent", 1, true), "dashboard shows unspent points")
ns.db.chars["Alt-Realm"] = { name = "Alt", realm = "Realm", class = "MAGE", className = "Mage", level = 12, seen = 1, profs = { [171] = 40 }, unspent = 2 }

-- Open every tab; click every row and action, re-reading the view after each press.
local presses = 0
for _, cmd in ipairs({ "", "next", "scale 1.2", "minimap", "minimap", "reset", "help" }) do SlashCmdList.LEGACYPATH(cmd) end
for _, tab in ipairs(ns.UI.tabs) do
	ns.UI.Show(tab.key)
	for _, text in ipairs({ "", "warlock" }) do
		local count = #ns.UI.views[tab.key](text)
		for i = 1, count do
			local row = ns.UI.views[tab.key](text)[i]
			if row and row.onClick and row.onClick ~= ns.UI.ResetPosition then row.onClick(); presses = presses + 1 end
			row = ns.UI.views[tab.key](text)[i]
			for _, action in ipairs(row and row.actions or {}) do
				if action[1] ~= "Forget" then action[3](); presses = presses + 1 end
			end
		end
	end
end
ns.UI.Show("objectives", "Raids")
ns.Progress.Refresh()
assert(ns.Progress.states[61994].closest.name == "Alt", "the Mage alt is closest to Novice Mage")
for _, row in ipairs(ns.UI.views.characters("")) do
	for _, action in ipairs(row.actions or {}) do
		if action[1] == "Forget" then action[3]() end
	end
end
assert(ns.Progress.states[61994].closest == nil, "a forgotten character is no longer named")

-- Widget scripts: hover, click, drag and resize on everything that was created.
for _, script in ipairs({ "OnEnter", "OnLeave", "OnClick", "OnDragStart", "OnUpdate", "OnDragStop", "OnMouseDown", "OnMouseUp", "OnSizeChanged" }) do
	for i = 1, #frames do
		local f = frames[i]
		if script ~= "OnClick" or f.data or f.fn then run(f, script) end
	end
end

-- Planner survives a round trip, the tooltip hook and the completion message work.
ns.db.plan = { 62018, 684 }
ns.UI.Show("planner")
assert(#ns.UI.views.planner("") == 2, "planner lists pinned challenges")
for _, hook in ipairs(hooks) do
	hook(widget(), { id = 62018 })
	hook(widget(), { id = 1 })
end
world[62018] = { done = true, mine = true }
local before = printed
for _, f in ipairs(frames) do run(f, "OnEvent", "ACHIEVEMENT_EARNED", 62018) end
assert(printed == before + 1, "completion is announced once")
LegacyPath_OnAddonCompartmentClick()

-- Quest tracker section: shows unfinished pinned challenges, collapses, undocks and re-docks.
-- Unspent points bubble: chat line when it cannot show, bubble otherwise.
before = printed
SlashCmdList.LEGACYPATH("points")
assert(printed == before + 1, "no Legacy button: the reminder goes to chat")
local visible, shown = true, false
LegacyMicroButton = widget()
LegacyMicroButton.IsVisible = function() return visible end
local makeFrame = CreateFrame
CreateFrame = function(kind, name, parent, template)
	if template == "GlowBoxTemplate" then error("no such template") end
	return makeFrame(kind, name, parent, template)
end
SlashCmdList.LEGACYPATH("points")
assert(printed == before + 2, "missing bubble template: the reminder goes to chat")
local box
CreateFrame = function(kind, name, parent, template)
	local w = makeFrame(kind, name, parent, template)
	if name == "LegacyPathBubble" then
		box = w
		w.Show, w.Hide, w.IsShown = function() shown = true end, function() shown = false end, function() return shown end
		w.text = widget() -- replaced by the addon
	end
	return w
end
SlashCmdList.LEGACYPATH("points")
assert(shown and printed == before + 2, "bubble shows instead of the chat line")
assert(box.text.text:find("2 unspent Legacy Points", 1, true), "bubble says how many")
ns.Fire("CHANGED")
assert(shown, "stays while there are points to spend")
local realPoints = ns.Progress.points
ns.Progress.points = { available = 1 }
ns.Fire("CHANGED")
assert(box.text.text:find("1 unspent Legacy Point on", 1, true), "count updates while shown")
ns.Progress.points = { available = 0 }
ns.Fire("CHANGED")
assert(not shown, "hides when all are spent")
ns.Progress.points = realPoints
SlashCmdList.LEGACYPATH("points")
LegacySystemFrame = { IsShown = function() return false end }
panelCallback()
assert(shown, "stays while the Legacy panel is closed")
LegacySystemFrame = { IsShown = function() return true end }
panelCallback()
assert(not shown, "hides when the Legacy panel opens")
LegacyMicroButton.GetCenter = function() return 0, 1000 end
SlashCmdList.LEGACYPATH("points")
assert(shown, "shows below a micro menu at the top of the screen")
CreateFrame = makeFrame

local T, st = ns.Tracker, ns.db.settings
st.tracker, st.trackerCollapsed, st.trackerDock, st.trackerMax = true, false, true, 3
ns.db.plan = { 62018, 684, 62034, 62010, 62054 } -- 62018 was completed above
assert(T.Update() == 3, "tracker shows up to the limit")
st.trackerMax = 5
assert(T.Update() == 4, "finished pins are left out")
st.trackerCollapsed = true
assert(T.Update() == 0, "collapsed shows none")
st.trackerCollapsed, st.tracker = false, false
assert(T.Update() == 0, "turned off shows none")
st.tracker = true
for i = 1, #frames do if frames[i].scripts.OnDragStop then run(frames[i], "OnDragStart"); run(frames[i], "OnDragStop") end end
assert(st.trackerDock == false and st.trackerPos, "dragging undocks and saves the position")
st.trackerDock = true
ns.Fire("SETTINGS")
assert(T.Dock() == ObjectiveTrackerFrame.NineSlice, "docks under Blizzard's tracker by default")
Questie_BaseFrame = widget()
assert(T.Dock() == Questie_BaseFrame, "prefers Questie's tracker when it is showing")
Questie_BaseFrame.IsShown = function() return false end
assert(T.Dock() == ObjectiveTrackerFrame.NineSlice, "falls back when Questie's tracker is hidden")
st.trackerDock = false
assert(T.Dock() == nil, "free-standing when undocked")
st.trackerDock = true
ns.db.plan = {}
assert(T.Update() == 0, "empty plan hides the section")

io.write(("UI smoke test passed: %d files, %d widgets, %d presses\n"):format(files, #frames, presses))
