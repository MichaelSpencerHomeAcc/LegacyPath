-- Optional minimap launcher. Drag it around the minimap edge; the angle is saved.
local _, ns = ...

local button

local function Place()
	local angle = math.rad(ns.db.settings.minimapAngle)
	button:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(angle), 80 * math.sin(angle))
end

local function FollowCursor()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	ns.db.settings.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
	Place()
end

local function Create()
	button = CreateFrame("Button", "LegacyPathMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameLevel(8)
	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", FollowCursor) end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnClick", function() ns.UI.Toggle() end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("LegacyPath")
		GameTooltip:AddLine("Click to open. Drag to move.", 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Place()
end

local function Update()
	if ns.db.settings.minimap and not button then Create() end
	if button then button:SetShown(ns.db.settings.minimap) end
end

ns.On("READY", Update)
ns.On("SETTINGS", Update)
