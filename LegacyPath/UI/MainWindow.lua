-- The window: bottom tabs, a search box, a category list (Challenges tab) and one scrolling list
-- of pooled rows. Each view in UI.views returns row descriptions. A row is one of:
--   { title, right, detail, lines, frac, bar, icon, check, tip = { lines }, onClick, actions = { { label, tip, fn, icon } } }
--   { title, header = true }
--   { title, cells = { { text, frac, done, pinned, tip, onClick } } }
local _, ns = ...

local UI = { views = {}, tabs = {}, tab = "dashboard" }
ns.UI = UI

local WIDTH, HEIGHT, MIN_W, MIN_H, SIDE = 620, 520, 580, 400, 160
local GAP, CELL, BAR, LABEL = 4, 20, 14, 110
local FLAT = "Interface\\Buttons\\WHITE8X8"
local CARD = { bgFile = FLAT, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } }
local TICK, STAR = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12|t "
local frame, inset, scroll, content, search, status
local rows, side = {}, {}

local function ShowTip(owner, lines)
	if not lines then return end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(lines[1])
	for i = 2, #lines do
		GameTooltip:AddLine(lines[i], 1, 1, 1, true)
	end
	GameTooltip:Show()
end

local function HideTip() GameTooltip:Hide() end

local function SavePlace()
	local w = ns.db.window
	local point, _, rel, x, y = frame:GetPoint(1)
	w.point, w.rel, w.x, w.y = point, rel, x, y
	w.w, w.h = frame:GetSize()
end

-- A pooled button whose data table carries tip and onClick.
local function NewButton(parent, template)
	local b = CreateFrame("Button", nil, parent, template)
	b.data = {}
	b:SetScript("OnClick", function(self) if self.data.onClick then self.data.onClick() end end)
	b:SetScript("OnEnter", function(self) ShowTip(self, self.data.tip) end)
	b:SetScript("OnLeave", HideTip)
	return b
end

local function SetData(b, d)
	b.data = d
	b:EnableMouse((d.tip or d.onClick) and true or false)
end

-- A bar with text in it: a row's progress, a category tile or a square in a challenge grid.
local function NewCell(parent)
	local c = NewButton(parent, "BackdropTemplate")
	c:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
	c:SetBackdropColor(0, 0, 0, 0.6)
	c.bar = CreateFrame("StatusBar", nil, c)
	c.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	c.bar:SetMinMaxValues(0, 1)
	c.bar:SetPoint("TOPLEFT", 1, -1)
	c.bar:SetPoint("BOTTOMRIGHT", -1, 1)
	c.text = c.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	c.text:SetPoint("CENTER")
	return c
end

local function SetCell(c, d)
	SetData(c, d)
	c.bar:SetValue(d.frac or 0)
	if d.done then c.bar:SetStatusBarColor(0.12, 0.4, 0.1) else c.bar:SetStatusBarColor(0.6, 0.44, 0.05) end
	if d.pinned then c:SetBackdropBorderColor(1, 0.82, 0) else c:SetBackdropBorderColor(0.4, 0.36, 0.28) end
	c.text:SetText((d.pinned and STAR or "") .. (d.done and TICK or d.text))
end

local function NewAction(row, icon)
	local b = CreateFrame("Button", nil, row, not icon and "UIPanelButtonTemplate" or nil)
	b:SetSize(20, 20)
	b:SetScript("OnClick", function(self) self.fn() end)
	b:SetScript("OnEnter", function(self) ShowTip(self, { self.tip }) end)
	b:SetScript("OnLeave", HideTip)
	if icon then b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD") end
	return b
end

local function NewRow()
	local row = NewButton(content, "BackdropTemplate")
	row:SetBackdrop(CARD)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(32, 32)
	row.icon:SetPoint("LEFT", 9, 0)
	row.check = row:CreateTexture(nil, "OVERLAY")
	row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	row.check:SetAllPoints(row.icon)
	row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.right = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.detail:SetTextColor(0.8, 0.75, 0.65)
	for _, fs in ipairs({ row.title, row.detail }) do
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
	end
	row.bar = NewCell(row)
	row.actions, row.icons, row.cells = {}, {}, {}
	return row
end

-- Action buttons, right to left. Returns the width they take.
local function LayoutActions(row, actions)
	local used, count = 8, { actions = 0, icons = 0 }
	for _, a in ipairs(actions) do
		local pool = a[4] and "icons" or "actions"
		local i = count[pool] + 1
		count[pool] = i
		local b = row[pool][i] or NewAction(row, a[4])
		row[pool][i] = b
		b.tip, b.fn = a[2], a[3]
		if a[4] then
			b:SetNormalTexture(a[4])
		else
			b:SetText(a[1])
			b:SetWidth(b:GetFontString():GetStringWidth() + 20)
		end
		b:ClearAllPoints()
		b:SetPoint("RIGHT", -used, 0)
		b:Show()
		used = used + b:GetWidth() + 2
	end
	for pool, n in pairs(count) do
		for i = n + 1, #row[pool] do row[pool][i]:Hide() end
	end
	return used
end

local function LayoutCells(row, cells, left, width)
	local each = (width - left - GAP * 2) / 3 -- always three columns
	for i = 1, math.max(#cells, #row.cells) do
		local c = row.cells[i] or NewCell(row)
		row.cells[i] = c
		c:SetShown(cells[i] ~= nil)
		if cells[i] then
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", left + (i - 1) * (each + GAP), 0)
			c:SetSize(each, CELL)
			SetCell(c, cells[i])
		end
	end
end

local function Layout(row, d, width, y)
	local plain = d.header or d.cells
	local left = plain and 4 or d.icon and 50 or 12
	local detail = d.detail and 13 * (d.lines or 1) + 2 or 0
	local height = plain and CELL or math.max(d.icon and 46 or 0, 28 + detail + (d.frac and BAR + 4 or 0))
	SetData(row, d)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", 0, -y)
	row:SetSize(width, height)
	row:SetBackdropColor(0.1, 0.08, 0.05, plain and 0 or 0.75)
	row:SetBackdropBorderColor(0.5, 0.45, 0.35, plain and 0 or 1)

	local used = LayoutActions(row, d.actions or {})
	LayoutCells(row, d.cells or {}, d.title and LABEL or 0, width)
	row.icon:SetShown(d.icon ~= nil)
	row.check:SetShown(d.check == true)
	if d.icon then
		row.icon:SetTexture(d.icon)
		if d.check == nil then row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) else row.icon:SetTexCoord(0, 1, 0, 1) end
	end
	row.right:SetText(d.right or "")
	row.right:ClearAllPoints()
	row.right:SetPoint("TOPRIGHT", -used - 4, plain and -4 or -9)
	row.title:SetText(d.title or "")
	row.title:ClearAllPoints()
	row.title:SetPoint("TOPLEFT", left, plain and -4 or -8)
	row.title:SetWidth(d.cells and LABEL - 8 or math.max(40, width - left - used - 12 - row.right:GetStringWidth()))
	row.detail:SetText(d.detail or "")
	row.detail:ClearAllPoints()
	row.detail:SetPoint("TOPLEFT", left, -24)
	row.detail:SetWidth(math.max(40, width - left - used - 8))
	row.detail:SetWordWrap(d.lines ~= nil)
	row.detail:SetMaxLines(d.lines or 1)
	row.bar:SetShown(d.frac ~= nil)
	if d.frac then
		row.bar:ClearAllPoints()
		row.bar:SetPoint("BOTTOMLEFT", left, 8)
		row.bar:SetPoint("BOTTOMRIGHT", -used - 4, 8)
		row.bar:SetHeight(BAR)
		SetCell(row.bar, { frac = d.frac, text = d.bar })
	end
	row:Show()
	return height + GAP
end

-- The category list beside the Challenges tab.
local function LayoutSide(list)
	for i = 1, math.max(#list, #side) do
		local b, d = side[i], list[i]
		if not b then
			b = NewButton(inset)
			b:SetSize(SIDE - 12, 24)
			b:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 26)
			b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
			b.on = b:CreateTexture(nil, "BACKGROUND")
			b.on:SetAllPoints()
			b.on:SetColorTexture(0.6, 0.44, 0.05, 0.4)
			b.title = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			b.title:SetPoint("LEFT", 6, 0)
			b.right = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			b.right:SetPoint("RIGHT", -6, 0)
			side[i] = b
		end
		b:SetShown(d ~= nil)
		if d then
			SetData(b, d)
			b.on:SetShown(d.selected)
			b.title:SetText(d.title)
			b.right:SetText(d.right or "")
		end
	end
end

-- The current tab's position and description, or 0 for Settings, which the cog opens.
local function CurrentTab()
	for i, tab in ipairs(UI.tabs) do
		if tab.key == UI.tab then return i, tab end
	end
	return 0, {}
end

function UI.Render()
	if not (frame and scroll and frame:IsShown()) then return end
	local _, tab = CurrentTab()
	local sum = ns.Progress.Summary()
	status:SetText(("Legacy Points: |cffffffff%d / %d|r"):format(sum.points, sum.total))
	local list = tab.side and tab.side() or {}
	LayoutSide(list)
	scroll:SetPoint("TOPLEFT", inset, 8 + (#list > 0 and SIDE or 0), -8)
	search:SetShown(tab.search == true)
	local data = UI.views[UI.tab](tab.search and search:GetText() or "")
	local width, y = scroll:GetWidth(), 0
	content:SetWidth(width)
	for i, d in ipairs(data) do
		rows[i] = rows[i] or NewRow()
		y = y + Layout(rows[i], d, width, y)
	end
	for i = #data + 1, #rows do
		rows[i]:Hide()
	end
	content:SetHeight(math.max(y, 1))
end

local function Build()
	local w = ns.db.window
	frame = CreateFrame("Frame", "LegacyPathFrame", UIParent, "PortraitFrameTemplate")
	frame:SetTitle("LegacyPath")
	frame:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Map_01")
	frame:SetSize(math.max(w.w or WIDTH, MIN_W), math.max(w.h or HEIGHT, MIN_H))
	frame:SetPoint(w.point or "CENTER", UIParent, w.rel or "CENTER", w.x or 0, w.y or 0)
	frame:SetScale(ns.db.settings.scale)
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetClampRectInsets(0, 0, 0, -30) -- keeps the tabs on screen
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetResizeBounds(MIN_W, MIN_H, 1000, 900)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePlace() end)
	tinsert(UISpecialFrames, "LegacyPathFrame") -- Escape closes it

	for i, tab in ipairs(UI.tabs) do
		local b = CreateFrame("Button", "LegacyPathFrameTab" .. i, frame, "PanelTabButtonTemplate")
		b:SetText(tab.label)
		if i == 1 then b:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 2) end -- PanelTemplates chains the rest
		b:SetScript("OnClick", function() UI.Show(tab.key) end)
	end
	PanelTemplates_SetNumTabs(frame, #UI.tabs)

	local cog = CreateFrame("Button", nil, frame)
	cog:SetSize(18, 18)
	cog:SetPoint("TOPRIGHT", -14, -34)
	cog:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
	cog:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	cog:SetScript("OnClick", function() UI.Show("settings") end)
	cog:SetScript("OnEnter", function(self) ShowTip(self, { "Settings" }) end)
	cog:SetScript("OnLeave", HideTip)

	status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	status:SetPoint("TOPLEFT", 68, -36)
	search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
	search:SetSize(200, 20)
	search:SetPoint("RIGHT", cog, "LEFT", -10, 0)
	search:SetAutoFocus(false)
	search:HookScript("OnTextChanged", UI.Render)

	inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 4, -60)
	inset:SetPoint("BOTTOMRIGHT", -6, 6)
	scroll = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("BOTTOMRIGHT", inset, -28, 8)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)

	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:SetFrameLevel(frame:GetFrameLevel() + 510) -- above the frame's border
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing(); SavePlace() end)
	frame:SetScript("OnSizeChanged", UI.Render)
end

-- Opens the window on a tab, optionally on one category of the Challenges tab.
function UI.Show(tab, cat)
	if not frame then Build() end
	UI.tab, UI.cat = tab or UI.tab, cat or UI.cat
	PanelTemplates_SetTab(frame, (CurrentTab()))
	frame:Show()
	scroll:SetVerticalScroll(0)
	if tab then search:SetText("") end
	UI.Render()
end

function UI.Toggle()
	if frame and frame:IsShown() then frame:Hide() else UI.Show() end
end

function UI.SetScale(scale)
	ns.db.settings.scale = math.max(0.6, math.min(1.6, scale))
	if frame then frame:SetScale(ns.db.settings.scale) end
	UI.Render()
end

function UI.ResetPosition()
	ns.db.window = {}
	if frame then
		frame:ClearAllPoints()
		frame:SetPoint("CENTER")
		frame:SetSize(WIDTH, HEIGHT)
	end
end

-- The popup's edit box has had three names across client versions.
local function editBox(popup)
	return popup.GetEditBox and popup:GetEditBox() or popup.EditBox or popup.editBox
end

StaticPopupDialogs.LEGACYPATH_NOTE = {
	text = "Note for %s", button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, editBoxWidth = 260, maxLetters = 200,
	timeout = 0, whileDead = true, hideOnEscape = true,
	OnShow = function(self, id) editBox(self):SetText(ns.db.notes[id] or "") end,
	OnAccept = function(self, id) ns.Planner.SetNote(id, editBox(self):GetText()) end,
	EditBoxOnEnterPressed = function(self, id)
		ns.Planner.SetNote(id, self:GetText())
		self:GetParent():Hide()
	end,
}

function UI.EditNote(s)
	StaticPopup_Show("LEGACYPATH_NOTE", s.name, nil, s.id)
end

ns.On("CHANGED", UI.Render)
