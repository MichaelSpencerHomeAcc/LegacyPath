-- The only file that reads Legacy data from the game. Every call is guarded: a missing
-- function, an error or a secret value becomes nil. Tests replace fields of ns.API.
local _, ns = ...

local API = {}
ns.API = API
local G = _G

local function plain(v)
	if G.issecretvalue and G.issecretvalue(v) then return nil end
	return v
end

local function ok(success, ...)
	if success then return ... end
end

local function call(fn, ...)
	if type(fn) == "function" then return ok(pcall(fn, ...)) end
end

function API.Available()
	return type(G.GetAchievementInfo) == "function" and type(G.GetAchievementCriteriaInfo) == "function"
end

function API.Now()
	return G.time and G.time() or os.time()
end

function API.Player()
	local className, class = call(G.UnitClass, "player")
	return {
		name = plain(call(G.UnitName, "player")) or "Unknown",
		realm = plain(call(G.GetRealmName)) or "",
		class = plain(class),
		className = plain(className),
		level = tonumber(plain(call(G.UnitLevel, "player"))) or 0,
	}
end

-- One Legacy Challenge as the client reports it, or nil.
-- done = earned on the account; mine = earned by this character.
function API.Challenge(id)
	local _, name, _, done, month, day, year, desc, _, _, _, _, mine = call(G.GetAchievementInfo, id)
	name = plain(name)
	if type(name) ~= "string" then return nil end
	local c = { name = name, desc = plain(desc), done = plain(done) == true, mine = plain(mine) == true, criteria = {} }
	month, day, year = tonumber(plain(month)), tonumber(plain(day)), tonumber(plain(year))
	if c.done and month and day and year then
		c.date = (year < 100 and 2000 + year or year) * 10000 + month * 100 + day
	end
	for i = 1, tonumber(plain(call(G.GetAchievementNumCriteria, id))) or 0 do
		local text, _, cdone, quantity, required = call(G.GetAchievementCriteriaInfo, id, i)
		c.criteria[i] = {
			text = plain(text) or "?",
			done = plain(cdone) == true,
			q = tonumber(plain(quantity)) or 0,
			req = tonumber(plain(required)) or 1,
		}
	end
	return c
end

local function categoryPath(cat)
	local name, parent = call(G.GetCategoryInfo, cat)
	local sub, top = name, name
	while type(parent) == "number" and parent ~= -1 do
		top, parent = call(G.GetCategoryInfo, parent)
	end
	return { cat = top, sub = sub }
end

-- Every achievement that awards Legacy Points: id -> { cat, sub }. Used to notice
-- challenges added by a patch that Database/Objectives.lua does not list yet.
function API.Discover()
	local found = {}
	local points = G.C_Traits and G.C_Traits.GetTraitCurrencyForAchievement
	local consts = G.Constants and G.Constants.LegacyConsts
	local currency = consts and consts.LEGACY_POINTS_TRAIT_CURRENCY_ID
	if not (points and currency) then return found end
	for _, cat in ipairs(call(G.GetCategoryList) or {}) do
		for i = 1, call(G.GetCategoryNumAchievements, cat) or 0 do
			local id = plain(call(G.GetAchievementInfo, cat, i))
			local n = id and plain(call(points, currency, id))
			if type(n) == "number" and n > 0 then found[id] = categoryPath(cat) end
		end
	end
	return found
end
