-- One-off diagnostic: /lpprobe, then /reload, then send
-- WTF\Account\<ACCOUNT>\SavedVariables\LegacyPathProbe.lua
-- Read-only. Records only achievement/Legacy data, nothing about other players.

local CURRENCY = 4225 -- Legacy Points trait currency, as used by the Legacy Forever addon (unverified)

local function clean(v)
	if issecretvalue and issecretvalue(v) then return "<secret>" end
	local t = type(v)
	if t == "string" or t == "number" or t == "boolean" then return v end
	return v ~= nil and ("<" .. t .. ">") or nil
end

local function pack(...)
	local out = {}
	for i = 1, select("#", ...) do out[i] = clean((select(i, ...))) end
	return out
end

local function try(fn, ...)
	if type(fn) ~= "function" then return { missing = true } end
	local r = { pcall(fn, ...) }
	if not r[1] then return { error = tostring(r[2]) } end
	return pack(unpack(r, 2))
end

local function points(id)
	local fn = C_Traits and C_Traits.GetTraitCurrencyForAchievement
	if not fn then return nil end
	local ok, n = pcall(fn, CURRENCY, id)
	return ok and clean(n) or nil
end

local function run()
	local db = { time = time(), build = pack(GetBuildInfo()), categories = {}, challenges = {}, globals = {}, strings = {} }
	db.class, db.level, db.faction = select(2, UnitClass("player")), UnitLevel("player"), UnitFactionGroup("player")

	db.has = {}
	for _, name in ipairs({ "GetCategoryList", "GetCategoryInfo", "GetCategoryNumAchievements", "GetAchievementInfo",
		"GetAchievementNumCriteria", "GetAchievementCriteriaInfo", "GetAchievementLink", "issecretvalue" }) do
		db.has[name] = type(_G[name]) == "function"
	end
	db.hasPointsApi = (C_Traits and C_Traits.GetTraitCurrencyForAchievement) ~= nil

	-- Anything Legacy-named the client exposes.
	for k, v in pairs(_G) do
		if type(k) == "string" then
			if k:find("Legacy") and type(v) ~= "string" then
				local entry = { type = type(v) }
				if type(v) == "table" and k:find("^C_") then
					entry.keys = {}
					for name in pairs(v) do entry.keys[#entry.keys + 1] = tostring(name) end
				end
				db.globals[k] = entry
			elseif k:find("^LEGACY_") and type(v) == "string" then
				db.strings[k] = v
			end
		end
	end
	db.consts = {}
	for k, v in pairs(Constants and Constants.LegacyConsts or {}) do db.consts[k] = clean(v) end
	local faction = db.consts.LEGACY_REWARD_TRACK_FACTION_ID
	if faction and C_MajorFactions then
		db.renownLevel = try(C_MajorFactions.GetCurrentRenownLevel, faction)
		db.renown = {}
		for level = 1, 80 do
			local ok, rewards = pcall(C_MajorFactions.GetRenownRewardsForLevel, faction, level)
			if not ok or type(rewards) ~= "table" or #rewards == 0 then break end
			db.renown[level] = {}
			for i, r in ipairs(rewards) do
				db.renown[level][i] = { name = clean(r.name), description = clean(r.description), itemID = clean(r.itemID),
					mountID = clean(r.mountID), toyID = clean(r.toyID) }
			end
		end
	end
	if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
		local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, CURRENCY)
		db.currency = ok and type(info) == "table" and { name = clean(info.name), quantity = clean(info.quantity) } or tostring(info)
	end

	-- Every achievement category, and every achievement that awards Legacy Points
	-- (or everything, if the points API is missing, so nothing is silently dropped).
	local total = 0
	for _, cat in ipairs(GetCategoryList and GetCategoryList() or {}) do
		db.categories[cat] = try(GetCategoryInfo, cat)
		for i = 1, GetCategoryNumAchievements(cat) or 0 do
			local info = try(GetAchievementInfo, cat, i)
			local id = info[1]
			total = total + 1
			local pts = type(id) == "number" and points(id)
			if type(id) == "number" and ((type(pts) == "number" and pts > 0) or not db.hasPointsApi) then
				local c = { category = cat, info = info, points = pts, criteria = {} }
				for n = 1, GetAchievementNumCriteria(id) or 0 do
					c.criteria[n] = try(GetAchievementCriteriaInfo, id, n)
				end
				db.challenges[id] = c
			end
		end
	end
	db.totalAchievements = total

	LegacyPathProbeDB = db
	local n = 0
	for _ in pairs(db.challenges) do n = n + 1 end
	print(("|cff66ccffLegacyPath Probe|r: recorded %d of %d achievements. Now type /reload."):format(n, total))
end

SLASH_LEGACYPATHPROBE1 = "/lpprobe"
SlashCmdList.LEGACYPATHPROBE = function()
	local ok, err = pcall(run)
	if not ok then
		LegacyPathProbeDB = { error = tostring(err) }
		print("|cff66ccffLegacyPath Probe|r failed: " .. tostring(err) .. " — /reload and send the file anyway.")
	end
end
