-- The unspent points reminder: a bubble pointing at the Legacy button on the micro menu, or a
-- chat line when that button is hidden or the bubble cannot be drawn. It is a frame of our own
-- in Blizzard's style: the micro menu's alert functions share state, so calling them risks taint.
local _, ns = ...

local bubble

local function Message(n)
	return ("You have %d unspent Legacy Point%s on this character. Spend %s in the Legacy panel."):format(n, n == 1 and "" or "s", n == 1 and "it" or "them")
end

local function SetText(n)
	bubble.text:SetText(Message(n))
	bubble:SetHeight(bubble.text:GetStringHeight() + 28)
end

local function Create()
	local f = CreateFrame("Frame", "LegacyPathBubble", UIParent, "GlowBoxTemplate")
	f:Hide()
	f:SetWidth(226)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f.arrow = CreateFrame("Frame", nil, f, "GlowBoxArrowTemplate")
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.text:SetPoint("LEFT", 14, 0)
	f.text:SetWidth(180)
	f.text:SetJustifyH("LEFT")
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetSize(22, 22)
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() f:Hide() end)
	bubble = f
end

-- Returns true when the bubble is on screen.
local function ShowBubble(n)
	local button = _G.LegacyMicroButton
	if not (button and button:IsVisible()) then return false end
	if not bubble then Create() end
	local _, y = button:GetCenter()
	local below = y * button:GetEffectiveScale() > UIParent:GetHeight() * UIParent:GetEffectiveScale() / 2
	SetText(n)
	bubble:ClearAllPoints()
	bubble.arrow:ClearAllPoints()
	if below then -- a micro menu at the top of the screen; the arrow art only points down
		bubble:SetPoint("TOP", button, "BOTTOM", 0, -4)
	else
		bubble:SetPoint("BOTTOM", button, "TOP", 0, 18)
		bubble.arrow:SetPoint("BOTTOM", button, "TOP", 0, 0) -- to the button, so clamping the box cannot misalign it
	end
	bubble.arrow:SetShown(not below)
	bubble:Show()
	return true
end

ns.On("UNSPENT", function(n)
	local ok, shown = pcall(ShowBubble, n)
	if not (ok and shown) then ns.Print(Message(n)) end
end)

ns.On("CHANGED", function()
	if not (bubble and bubble:IsShown()) then return end
	local n = ns.Progress.points and ns.Progress.points.available or 0
	if n > 0 and ns.db.settings.unspent then SetText(n) else bubble:Hide() end
end)

-- Blizzard fires this as the Legacy panel opens.
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("Legacy.UpdateCurrencyInfo", function()
		if bubble and LegacySystemFrame and LegacySystemFrame:IsShown() then bubble:Hide() end
	end, ns)
end
