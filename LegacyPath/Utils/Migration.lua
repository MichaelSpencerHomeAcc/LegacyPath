-- Versioned SavedVariables. ns.migrations[n] upgrades a database from version n to n + 1.
local _, ns = ...

ns.DB_VERSION = 3
ns.migrations = {
	-- 1 -> 2: drop account-wide progress that was stored as if it belonged to each character.
	[1] = function(db)
		for _, c in pairs(type(db.chars) == "table" and db.chars or {}) do
			c.mine, c.frac = nil, nil
		end
	end,
	-- 2 -> 3: Forever dropped realm names, which saved characters a second time. Keep the newest.
	[2] = function(db)
		local newest = {}
		for key, c in pairs(type(db.chars) == "table" and db.chars or {}) do
			local id = tostring(c.name) .. "/" .. tostring(c.class)
			local other = newest[id]
			if other and (db.chars[other].seen or 0) >= (c.seen or 0) then
				db.chars[key] = nil
			else
				if other then db.chars[other] = nil end
				newest[id] = key
			end
		end
	end,
}

local function defaults()
	return {
		settings = { scale = 1, minimap = true, minimapAngle = 215, notify = true, tooltip = true, hideDone = false, hideCats = {},
			unspent = true, tracker = true, trackerDock = true, trackerMax = 3, trackerCollapsed = false }, -- trackerPos is set by dragging
		window = {}, -- position and size
		collapsed = {}, -- category -> true
		plan = {}, -- ordered challenge ids
		notes = {}, -- id -> text
		manual = {}, -- id -> true, used only when the client gives no data
		chars = {}, -- "Name-Realm" -> snapshot
	}
end

local function fill(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			fill(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function ns.Migrate(db)
	if type(db) ~= "table" then db = {} end
	local version = tonumber(db.version) or 0
	for v = version, ns.DB_VERSION - 1 do
		if ns.migrations[v] then ns.migrations[v](db) end
	end
	fill(db, defaults())
	db.version = math.max(version, ns.DB_VERSION) -- never downgrade a newer database
	return db
end
