-- The window: tabs, search box and one scrolling list of pooled rows.
-- Each tab is a function in UI.views that returns row descriptions:
--   { title, right, detail, frac, header, tip = { lines }, onClick, actions = { { label, tip, fn } } }
local _, ns = ...

local UI = { views = {}, tabs = {}, tab = "dashboard" }
ns.UI = UI

local ROW, HEADER, WIDTH, HEIGHT = 36, 22, 580, 460
local frame, scroll, content, search
local rows, tabButtons = {}, {}

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

local function NewAction(row)
	local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	b:SetHeight(20)
	b:SetScript("OnClick", function(self) self.fn() end)
	b:SetScript("OnEnter", function(self) ShowTip(self, { self.tip }) end)
	b:SetScript("OnLeave", HideTip)
	return b
end

local function NewRow()
	local row = CreateFrame("Button", nil, content)
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.title:SetPoint("TOPLEFT", 6, -4)
	row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
	row.detail:SetTextColor(0.7, 0.7, 0.7)
	for _, fs in ipairs({ row.title, row.detail }) do
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
	end
	row.bar = CreateFrame("StatusBar", nil, row)
	row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	row.bar:SetMinMaxValues(0, 1)
	row.bar:SetHeight(3)
	row.bar:SetPoint("BOTTOMLEFT", 2, 0)
	row.bar:SetPoint("BOTTOMRIGHT", -2, 0)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	row:SetScript("OnClick", function(self) if self.data.onClick then self.data.onClick() end end)
	row:SetScript("OnEnter", function(self) ShowTip(self, self.data.tip) end)
	row:SetScript("OnLeave", HideTip)
	row.actions = {}
	return row
end

local function Layout(row, d, width, y)
	local height = d.header and HEADER or ROW
	row.data = d
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", 0, -y)
	row:SetSize(width, height - 2)
	row.bg:SetColorTexture(1, 1, 1, d.header and 0.12 or 0.04)

	local used = 4 -- width taken by action buttons, laid out right to left
	local actions = d.actions or {}
	for i = 1, math.max(#row.actions, #actions) do
		local a = actions[i]
		if a and not row.actions[i] then row.actions[i] = NewAction(row) end
		local b = row.actions[i]
		b:SetShown(a ~= nil)
		if a then
			b:SetText(a[1])
			b.tip, b.fn = a[2], a[3]
			b:SetWidth(b:GetFontString():GetStringWidth() + 16)
			b:ClearAllPoints()
			b:SetPoint("RIGHT", -used, 0)
			used = used + b:GetWidth() + 2
		end
	end

	row.right:SetText(d.right or "")
	row.right:ClearAllPoints()
	row.right:SetPoint("TOPRIGHT", -used - 2, -5)
	row.title:SetFontObject(d.header and GameFontNormal or GameFontHighlight)
	row.title:SetText(d.title or "")
	row.title:SetWidth(math.max(40, width - used - 18 - row.right:GetStringWidth()))
	row.detail:SetText(d.detail or "")
	row.detail:SetWidth(math.max(40, width - used - 12))
	row.bar:SetShown(d.frac ~= nil)
	if d.frac then
		row.bar:SetValue(d.frac)
		if d.frac >= 1 then row.bar:SetStatusBarColor(0.25, 0.75, 0.25) else row.bar:SetStatusBarColor(1, 0.82, 0) end
	end
	row:Show()
	return height
end

function UI.Render()
	if not (frame and scroll and frame:IsShown()) then return end
	local data = UI.views[UI.tab](search:GetText() or "")
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
	frame = CreateFrame("Frame", "LegacyPathFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(w.w or WIDTH, w.h or HEIGHT)
	frame:SetPoint(w.point or "CENTER", UIParent, w.rel or "CENTER", w.x or 0, w.y or 0)
	frame:SetScale(ns.db.settings.scale)
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	if frame.SetResizeBounds then frame:SetResizeBounds(540, 300, 1000, 900) end
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePlace() end)
	local title = frame.TitleText or (frame.TitleContainer and frame.TitleContainer.TitleText)
	if title then title:SetText("LegacyPath") end
	tinsert(UISpecialFrames, "LegacyPathFrame") -- Escape closes it

	local x = 10
	for _, tab in ipairs(UI.tabs) do
		local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		b:SetText(tab.label)
		b:SetSize(b:GetFontString():GetStringWidth() + 20, 22)
		b:SetPoint("TOPLEFT", x, -28)
		b:SetScript("OnClick", function() UI.Show(tab.key) end)
		x = x + b:GetWidth() + 2
		tabButtons[tab.key] = b
	end

	search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
	search:SetHeight(20)
	search:SetPoint("TOPLEFT", 16, -54)
	search:SetPoint("TOPRIGHT", -12, -54)
	search:SetAutoFocus(false)
	search:HookScript("OnTextChanged", UI.Render)

	scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -80)
	scroll:SetPoint("BOTTOMRIGHT", -30, 10)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)

	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing(); SavePlace() end)
	frame:SetScript("OnSizeChanged", UI.Render)
end

-- Opens the window on a tab, optionally with the search box pre-filled.
function UI.Show(tab, text)
	if not frame then Build() end
	UI.tab = tab or UI.tab
	for key, b in pairs(tabButtons) do
		b:SetEnabled(key ~= UI.tab)
	end
	frame:Show()
	scroll:SetVerticalScroll(0)
	if text then search:SetText(text) end
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
