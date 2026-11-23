-- Versioned SavedVariables. ns.migrations[n] upgrades a database from version n to n + 1.
local _, ns = ...

ns.DB_VERSION = 1
ns.migrations = {}

local function defaults()
	return {
		settings = { scale = 1, minimap = true, minimapAngle = 215, notify = true, tooltip = true, hideDone = false, hideCats = {},
			tracker = true, trackerDock = true, trackerMax = 3, trackerCollapsed = false }, -- trackerPos is set by dragging
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
