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

-- This character's profession skills, keyed by skill line id and by name. Like Blizzard's
-- profession window, uses whichever of the two skill sources is filled in.
function API.Professions()
	local out = {}
	for _, index in pairs({ call(G.GetProfessions) }) do
		local name, _, rank, _, _, _, line = call(G.GetProfessionInfo, index)
		name, rank, line = plain(name), tonumber(plain(rank)) or 0, plain(line)
		local info = line and G.C_TradeSkillUI and call(G.C_TradeSkillUI.GetProfessionInfoBySkillLineID, line)
		rank = math.max(rank, type(info) == "table" and tonumber(plain(info.skillLevel)) or 0)
		if name and rank > 0 then out[name] = rank end
		if line and rank > 0 then out[line] = rank end
	end
	return out
end

function API.Player()
	local className, class = call(G.UnitClass, "player")
	local first, surname = call(G.UnitName, "player") -- Forever returns the surname second
	local realm = plain(call(G.GetRealmName)) or "" -- empty on Forever, where full names are unique
	first, surname = plain(first) or "Unknown", plain(surname)
	if type(surname) ~= "string" or surname == "" or surname == realm then surname = nil end
	local consts = G.Constants and G.Constants.CharacterNameSeparatorConsts
	return {
		name = surname and first .. (consts and consts.CHARACTERNAME_SURNAME_SEPARATOR or " ") .. surname or first,
		first = surname and first, -- nil when there is no surname
		realm = realm,
		class = plain(class),
		className = plain(className),
		level = tonumber(plain(call(G.UnitLevel, "player"))) or 0,
		profs = API.Professions(),
	}
end

-- One Legacy Challenge as the client reports it, or nil.
-- Completion and criteria are account-wide. The API's "earned by this character" value is not
-- used: level 1 alts report it for challenges only another character can have earned.
function API.Challenge(id)
	local _, name, _, done, month, day, year, desc, _, icon = call(G.GetAchievementInfo, id)
	name = plain(name)
	if type(name) ~= "string" then return nil end
	local c = { name = name, desc = plain(desc), icon = plain(icon), done = plain(done) == true, criteria = {} }
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

-- Legacy Points this character can still spend, read the way Blizzard's Legacy panel reads
-- "Available points": the Legacy trees' shared currency, via the Professions tree.
-- Returns { available, cap } or nil before Legacy unlocks or if the client says nothing.
function API.Points()
	local traits, consts = G.C_Traits, G.Constants and G.Constants.LegacyConsts
	local tree = consts and consts.LEGACY_TREE_PROFESSIONS_ID
	if not (traits and tree) then return nil end
	local config = plain(call(traits.GetConfigIDByTreeID, tree))
	local list = config and call(traits.GetTreeCurrencyInfo, config, tree, false)
	local info = type(list) == "table" and list[1]
	local available = type(info) == "table" and tonumber(plain(info.quantity))
	if not available then return nil end
	return { available = available, cap = tonumber(plain(info.maxQuantity)) }
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
