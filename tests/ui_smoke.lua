-- UI smoke test. Run from the repo root:  luajit tests/ui_smoke.lua
-- Loads every file in the .toc order against a stub of the WoW widget API, then opens
-- each tab and presses every row and button. It catches Lua errors (typos, nil calls);
-- it cannot tell whether the real client draws anything correctly.
local ROOT = "LegacyPath/"

local frames = {}
local returns = {
	GetWidth = function() return 500 end, GetHeight = function() return 20 end, GetStringWidth = function() return 40 end,
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
local hooks = {}
Enum = { TooltipDataType = { Achievement = 1 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) hooks[#hooks + 1] = fn end }
local printed = 0
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
	Player = function() return { name = "Main", realm = "Realm", class = "WARLOCK", className = "Warlock", level = 27 } end,
	Challenge = function(id)
		local c, crit = world[id] or {}, {}
		if c.req then crit[1] = { text = "Skill", done = false, q = c.q, req = c.req } end
		for i = 1, c.n or 0 do crit[i] = { text = "Boss " .. i, done = i < 3, q = 0, req = 1 } end
		return { name = ns.Data.byId[id].name, desc = "desc", done = c.done == true, mine = c.mine == true, date = c.date, criteria = crit }
	end,
}

for _, f in ipairs(frames) do run(f, "OnEvent", "ADDON_LOADED", "LegacyPath") end
for _, f in ipairs(frames) do run(f, "OnEvent", "PLAYER_ENTERING_WORLD") end
assert(#ns.Progress.list == 65, "progress loaded")
ns.db.chars["Alt-Realm"] = { name = "Alt", realm = "Realm", class = "MAGE", level = 12, seen = 1, mine = {}, frac = { [61994] = 0.48 } }

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

io.write(("UI smoke test passed: %d files, %d widgets, %d presses\n"):format(files, #frames, presses))
