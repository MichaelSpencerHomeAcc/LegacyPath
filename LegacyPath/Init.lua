-- Wiring: SavedVariables, game events (debounced, never refreshed in combat) and slash commands.
local ADDON, ns = ...

local frame = CreateFrame("Frame")
local queued, deferred

local function Refresh()
	queued = false
	if InCombatLockdown() then
		deferred = true -- wait for PLAYER_REGEN_ENABLED
	elseif ns.db then
		ns.Progress.Refresh()
	end
end

-- CRITERIA_UPDATE arrives in bursts; one refresh a second is plenty.
local function Queue()
	if not queued then
		queued = true
		C_Timer.After(1, Refresh)
	end
end

frame:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" then
		if arg == ADDON then
			LegacyPathDB = ns.Migrate(LegacyPathDB)
			ns.db = LegacyPathDB
			ns.Fire("READY")
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if deferred then
			deferred = false
			Queue()
		end
	else
		Queue()
	end
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP",
	"ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "RECEIVED_ACHIEVEMENT_LIST" }) do
	frame:RegisterEvent(event)
end

ns.On("COMPLETED", function(s)
	if ns.db.settings.notify then
		ns.Print(("Legacy Challenge complete: %s (+1 Legacy Point)%s"):format(s.name, ns.Planner.IsPinned(s.id) and " - it was on your plan" or ""))
	end
end)

SLASH_LEGACYPATH1, SLASH_LEGACYPATH2 = "/legacypath", "/lp"
SlashCmdList.LEGACYPATH = function(msg)
	local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if cmd == "" then
		ns.UI.Toggle()
	elseif cmd == "next" then
		for i, r in ipairs(ns.Recommend.List(3)) do
			ns.Print(("%d. %s - %s (%s)"):format(i, r.s.name, r.remaining, r.why))
		end
	elseif cmd == "scale" and tonumber(arg) then
		ns.UI.SetScale(tonumber(arg))
	elseif cmd == "minimap" then
		ns.db.settings.minimap = not ns.db.settings.minimap
		ns.Fire("SETTINGS")
		ns.Fire("CHANGED")
	elseif cmd == "reset" then
		ns.UI.ResetPosition()
	else
		ns.Print("/lp - open or close | /lp next - top 3 next steps | /lp scale 0.6-1.6 | /lp minimap | /lp reset - recentre the window")
	end
end

function LegacyPath_OnAddonCompartmentClick()
	ns.UI.Toggle()
end
