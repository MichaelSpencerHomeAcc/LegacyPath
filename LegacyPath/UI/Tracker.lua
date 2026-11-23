-- Pinned challenges as a section docked under the quest tracker. Forever refuses
-- Blizzard's own tracking for Legacy challenges, and adding to Blizzard's tracker
-- frames risks taint, so this is a separate frame styled to match. Dragging the
-- header undocks it; Settings docks it again.
local _, ns = ...

local T = {}
ns.Tracker = T

local WIDTH, GAP = 250, 4
local frame, header
local blocks = {}

local function firstOf(...)
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v then return v end
	end
end

-- Quest trackers to dock under, first one showing wins. Questie replaces Blizzard's
-- tracker, which then sits empty with its bottom near the bottom of the screen.
local TARGETS = { "Questie_BaseFrame", "ObjectiveTrackerFrame" }
local hooked = {}

local function DockTarget()
	for _, name in ipairs(TARGETS) do
		local f = _G[name]
		if type(f) == "table" and f.IsShown then
			if not hooked[f] then
				hooked[f] = true
				f:HookScript("OnShow", function() T.Dock() end)
				f:HookScript("OnHide", function() T.Dock() end)
			end
			if f:IsShown() then return f end
		end
	end
end

-- Places the section. Returns the frame it docked under, or nil when free-standing.
function T.Dock()
	if not frame then return end
	local st = ns.db.settings
	local target = st.trackerDock and DockTarget()
	frame:ClearAllPoints()
	if target then
		-- Blizzard's NineSlice background ends under its last line; Questie's frame fits its content.
		local anchor = type(target.NineSlice) == "table" and target.NineSlice or target
		-- Questie's text starts at its header, which can sit right of the frame's edge.
		local header, dx = _G.Questie_HeaderFrame, 0
		if target == _G.Questie_BaseFrame and header and header:GetLeft() and target:GetLeft() then
			dx = header:GetLeft() - target:GetLeft()
		end
		frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", dx, -8)
		frame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -8)
		return anchor
	end
	local p = st.trackerPos or { "TOPRIGHT", "TOPRIGHT", -100, -300 }
	frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	frame:SetWidth(WIDTH)
end

local function NewBlock()
	local b = CreateFrame("Button", nil, frame)
	b.title = b:CreateFontString(nil, "OVERLAY")
	b.title:SetFontObject(firstOf(_G.ObjectiveTrackerLineFont, _G.ObjectiveFont, GameFontNormal))
	b.title:SetTextColor(0.75, 0.61, 0)
	b.title:SetPoint("TOPLEFT", 4, 0)
	b.body = b:CreateFontString(nil, "OVERLAY")
	b.body:SetFontObject(firstOf(_G.ObjectiveTrackerLineFont, _G.ObjectiveFont, GameFontHighlightSmall))
	b.body:SetTextColor(0.8, 0.8, 0.8)
	b.body:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 8, -2)
	for _, fs in ipairs({ b.title, b.body }) do
		fs:SetJustifyH("LEFT")
	end
	b:SetScript("OnClick", function() ns.UI.Show("planner") end)
	b:SetScript("OnEnter", function() b.title:SetTextColor(1, 0.82, 0) end)
	b:SetScript("OnLeave", function() b.title:SetTextColor(0.75, 0.61, 0) end)
	return b
end

local function Create()
	frame = CreateFrame("Frame", "LegacyPathTrackerFrame", UIParent)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	header = CreateFrame("Button", nil, frame)
	header:SetHeight(24)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header.text = header:CreateFontString(nil, "OVERLAY")
	header.text:SetFontObject(firstOf(_G.ObjectiveTrackerHeaderFont, _G.GameFontNormalMed2, GameFontNormal))
	header.text:SetPoint("LEFT", 4, 0)
	header:SetScript("OnClick", function()
		ns.db.settings.trackerCollapsed = not ns.db.settings.trackerCollapsed
		T.Update()
	end)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() frame:StartMoving() end)
	header:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local point, _, relPoint, x, y = frame:GetPoint(1)
		ns.db.settings.trackerPos = { point, relPoint, x, y }
		ns.db.settings.trackerDock = false
		T.Dock()
		ns.Fire("CHANGED")
	end)
	header:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("LegacyPath")
		GameTooltip:AddLine("Click to collapse. Drag to move.", 1, 1, 1)
		GameTooltip:AddLine("Click a challenge to open your plan.", 1, 1, 1)
		GameTooltip:Show()
	end)
	header:SetScript("OnLeave", function() GameTooltip:Hide() end)
	T.Dock()
end

-- Redraws the section. Returns how many challenges it shows.
function T.Update()
	local st = ns.db and ns.db.settings
	if not st or (not frame and not st.tracker) then return 0 end
	if not frame then Create() else T.Dock() end
	local list = {}
	for _, s in ipairs(ns.Planner.List()) do
		if not s.done then list[#list + 1] = s end
	end
	frame:SetShown(st.tracker and #list > 0)
	local shown = st.tracker and not st.trackerCollapsed and math.min(#list, st.trackerMax) or 0
	header.text:SetText(st.trackerCollapsed and ("LegacyPath (%d)"):format(#list) or "LegacyPath")

	local width = frame:GetWidth()
	width = (width and width > 0) and width or WIDTH
	local y = 26
	for i = 1, math.max(shown, #blocks) do
		local s = i <= shown and list[i]
		if s then
			local b = blocks[i] or NewBlock()
			blocks[i] = b
			local steps, more = ns.Recommend.Steps(s, ns.Progress.player)
			for k, line in ipairs(steps) do
				steps[k] = "- " .. line
			end
			if more > 0 then steps[#steps + 1] = ("and %d more..."):format(more) end
			b.title:SetWidth(width - 8)
			b.body:SetWidth(width - 16)
			b.title:SetText(s.name)
			b.body:SetText(table.concat(steps, "\n"))
			local height = b.title:GetStringHeight() + b.body:GetStringHeight() + 4
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", 0, -y)
			b:SetPoint("TOPRIGHT", 0, -y)
			b:SetHeight(height)
			b:Show()
			y = y + height + GAP
		elseif blocks[i] then
			blocks[i]:Hide()
		end
	end
	frame:SetHeight(y)
	return shown
end

ns.On("CHANGED", T.Update)
ns.On("SETTINGS", T.Dock)

-- Questie builds its tracker a few seconds after login; look again once it has.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function() C_Timer.After(5, T.Update) end)
