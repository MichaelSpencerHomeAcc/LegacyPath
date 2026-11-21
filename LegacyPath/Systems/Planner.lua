-- The personal plan: an ordered list of pinned challenge ids, plus notes. Account-wide.
local _, ns = ...

local Planner = {}
ns.Planner = Planner

local function index(id)
	for i, v in ipairs(ns.db.plan) do
		if v == id then return i end
	end
end

function Planner.IsPinned(id)
	return index(id) ~= nil
end

function Planner.Toggle(id)
	local i = index(id)
	if i then
		table.remove(ns.db.plan, i)
	elseif ns.Data.byId[id] then
		table.insert(ns.db.plan, id)
	end
	ns.Fire("CHANGED")
end

function Planner.Move(id, delta)
	local plan, i = ns.db.plan, index(id)
	local j = i and i + delta
	if j and plan[j] then
		plan[i], plan[j] = plan[j], plan[i]
		ns.Fire("CHANGED")
	end
end

function Planner.SetNote(id, text)
	text = (text or ""):match("^%s*(.-)%s*$")
	ns.db.notes[id] = text ~= "" and text or nil
	ns.Fire("CHANGED")
end

-- Pinned states in plan order. Ids the game no longer lists are skipped, not deleted.
function Planner.List()
	local out = {}
	for _, id in ipairs(ns.db.plan) do
		local s = ns.Progress.states[id]
		if s then out[#out + 1] = s end
	end
	return out
end
