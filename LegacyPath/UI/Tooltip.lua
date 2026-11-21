-- One line on achievement tooltips that are Legacy Challenges. Uses the client's own
-- post-call hook, so other tooltip addons are left alone. Skipped if the hook is missing.
local _, ns = ...

local kind = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Achievement
if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and kind) then return end

TooltipDataProcessor.AddTooltipPostCall(kind, function(tooltip, data)
	if not (ns.db and ns.db.settings.tooltip and data) or (issecretvalue and issecretvalue(data.id)) then return end
	local s = ns.Progress.states[data.id]
	if not s then return end
	tooltip:AddLine(("LegacyPath: Legacy Challenge, %s%s"):format(
		s.done and "complete" or math.floor(s.frac * 100) .. "% done",
		ns.Planner.IsPinned(s.id) and " - on your plan" or ""), 0.4, 0.8, 1)
end)
