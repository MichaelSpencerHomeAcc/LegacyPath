-- Non-UI tests. Run from the repo root:  luajit tests/run.lua
-- Loads the addon's logic files outside the game with a mock API adapter.
local ROOT = "LegacyPath/"
local FILES = { "Core.lua", "Utils/Migration.lua", "Database/Objectives.lua", "Database/Rewards.lua",
	"Systems/APIAdapter.lua", "Systems/Progress.lua", "Systems/Recommend.lua", "Systems/Planner.lua" }

local passed, failed = 0, 0
local function check(cond, label)
	if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. label) end
end
local function eq(a, b, label) check(a == b, ("%s (got %s, want %s)"):format(label, tostring(a), tostring(b))) end

-- A fresh addon instance with a mock adapter. `world` is what the fake game reports.
local function fresh(world)
	local ns = {}
	for _, file in ipairs(FILES) do
		assert(loadfile(ROOT .. file))("LegacyPath", ns)
	end
	ns.Print = function() end
	ns.realAPI = ns.API
	world = world or {}
	world.player = world.player or { name = "Main", realm = "Realm", class = "WARLOCK", className = "Warlock", level = 27 }
	world.challenges = world.challenges or {}
	ns.API = {
		Available = function() return world.available ~= false end,
		Now = function() return world.now or 1000 end,
		Player = function() return world.player end,
		Discover = function() return world.discover or {} end,
		Challenge = function(id)
			local c = world.challenges[id]
			if c == false then return nil end
			c = c or {}
			return { name = c.name or ns.Data.byId[id].name, desc = c.desc, done = c.done == true, mine = c.mine == true,
				date = c.date, criteria = c.criteria or {} }
		end,
	}
	ns.db = ns.Migrate(nil)
	return ns, world
end

local function skill(q, req) return { { text = req .. " Skill", done = q >= req, q = q, req = req } } end
local function recs(ns)
	ns.Fire("CHANGED") -- drop the cache
	local by = {}
	for i, r in ipairs(ns.Recommend.List()) do r.rank = i; by[r.s.id] = r end
	return by
end

-- Database -------------------------------------------------------------------
do
	local ns = fresh()
	local D = ns.Data
	eq(#D.list, 65, "65 challenges catalogued")
	eq(#D.rejected, 0, "no catalogue record rejected")
	local counts = {}
	for _, o in ipairs(D.list) do counts[o.cat] = (counts[o.cat] or 0) + 1 end
	eq(counts["Classes"], 27, "27 class challenges")
	eq(counts["Tradeskills"], 18, "18 tradeskill challenges")
	eq(counts["Player vs. Player"], 12, "12 PvP challenges")
	eq(counts["Dungeons"], 3, "3 dungeon challenges")
	eq(counts["Raids"], 3, "3 raid challenges")
	eq(counts["Adventure"], 2, "2 adventure challenges")
	for _, o in ipairs(D.list) do
		check(not o.prereq or D.byId[o.prereq], "prerequisite of " .. o.name .. " exists")
	end
	eq(D.byId[62010].prereq, 62009, "Experienced Warlock follows Novice Warlock")
	eq(D.byId[62028].name, "Journeyman Tailor", "Tailor ids skip 62027")

	-- invalid or incomplete records
	eq(D.Add("nope"), false, "non-table rejected")
	eq(D.Add({ name = "x", cat = "Raids" }), false, "missing id rejected")
	eq(D.Add({ id = 1, cat = "Raids" }), false, "missing name rejected")
	eq(D.Add({ id = 1, name = "x", cat = "Fishing" }), false, "unknown category rejected")
	eq(D.Add({ id = 684, name = "x", cat = "Raids" }), false, "duplicate id rejected")
	eq(#D.list, 65, "rejected records are not stored")
	eq(#D.rejected, 5, "rejections are counted")
end

-- Real adapter with no game API at all ---------------------------------------
do
	local ns = fresh()
	local api = ns.realAPI
	eq(api.Available(), false, "adapter: unavailable without the game")
	eq(api.Challenge(684), nil, "adapter: no challenge data")
	eq(next(api.Discover()), nil, "adapter: nothing discovered")
	local p = api.Player()
	eq(p.level, 0, "adapter: level defaults to 0")
	eq(p.class, nil, "adapter: class unknown")
end

-- Real adapter against fake globals, including secret values and errors ---------
do
	local SECRET = {}
	_G.issecretvalue = function(v) return v == SECRET end
	_G.GetAchievementInfo = function(id)
		if id == 1 then return 1, "One", 0, true, 11, 9, 26, "Desc", 0, 0, "", false, true end
		if id == 2 then return 2, SECRET end
		if id == 3 then error("boom") end
	end
	_G.GetAchievementNumCriteria = function() return 2 end
	_G.GetAchievementCriteriaInfo = function(_, i)
		if i == 1 then return "A", 0, false, 135, 150 end
		return "B", 0, false, SECRET, 300
	end
	local api = fresh().realAPI
	local c = api.Challenge(1)
	eq(c.done and c.mine, true, "adapter: account and character completion read")
	eq(c.date, 20261109, "adapter: completion date")
	eq(c.criteria[1].q, 135, "adapter: criteria quantity")
	eq(c.criteria[2].q, 0, "adapter: secret quantity becomes 0")
	eq(api.Challenge(2), nil, "adapter: secret name is treated as no data")
	eq(api.Challenge(3), nil, "adapter: erroring API is treated as no data")
	_G.issecretvalue, _G.GetAchievementInfo, _G.GetAchievementNumCriteria, _G.GetAchievementCriteriaInfo = nil, nil, nil, nil
end

-- Live progress, derived progress, session changes -----------------------------
do
	local fired = {}
	local ns, world = fresh({ challenges = {
		[62009] = { done = true, mine = true, date = 20261109 },
		[62018] = { criteria = skill(135, 150) },
		[62034] = { criteria = { { text = "A", done = true, q = 1, req = 1 }, { text = "B", done = false, q = 0, req = 1 },
			{ text = "C", done = false, q = 0, req = 1 }, { text = "D", done = true, q = 1, req = 1 } } },
	} })
	ns.On("COMPLETED", function(s) fired[#fired + 1] = s.id end)
	local P = ns.Progress
	eq(#P.Refresh(), 0, "first refresh announces nothing")
	eq(P.states[62018].frac, 0.9, "single criterion uses quantity")
	eq(P.states[62018].source, "live", "criteria progress is live")
	eq(P.states[62034].frac, 0.5, "multiple criteria use the completed share")
	eq(P.states[62010].frac, 0.6, "own class level is derived")
	eq(P.states[62010].source, "derived", "derived progress is labelled")
	eq(P.states[61500].frac, 0, "another class has no progress here")
	eq(P.states[62009].frac, 1, "completed challenge is 100%")
	local sum = P.Summary()
	eq(sum.points, 1, "summary counts points")
	eq(sum.cats["Classes"].done, 1, "summary by category")
	eq(sum.recent[1].id, 62009, "recently completed")

	world.challenges[62018] = { done = true, mine = true, date = 20261110, criteria = skill(150, 150) }
	local newly = P.Refresh()
	eq(#newly, 1, "a completion during the session is detected")
	eq(fired[1], 62018, "completion event fired")
	eq(#P.Refresh(), 0, "no repeat announcement")
	eq(#fired, 1, "completion fired once")
	eq(P.Summary().recent[1].id, 62018, "newest completion first")

	world.player.level = 28
	local changes = 0
	ns.On("CHANGED", function() changes = changes + 1 end)
	P.Refresh()
	eq(changes, 1, "level-up changes derived progress")
	P.Refresh()
	eq(changes, 1, "no change event when nothing changed")
end

-- Missing data: manual mode ---------------------------------------------------
do
	local ns = fresh({ available = false })
	local P = ns.Progress
	P.Refresh()
	eq(P.live, false, "manual mode when the API is missing")
	eq(P.states[684].source, "manual", "state labelled manual")
	eq(P.states[684].desc, "Defeat Onyxia.", "fallback requirement text")
	eq(P.states[62010].source, "derived", "level-derived progress still works")
	eq(#P.SetManual(684, true), 1, "manual tick completes")
	eq(P.Summary().points, 1, "manual tick counts")
	P.SetManual(684, false)
	eq(P.Summary().points, 0, "manual tick can be undone")

	-- live data wins over an old manual tick; one missing challenge falls back alone
	local ns2, world2 = fresh({ challenges = { [62054] = false } })
	ns2.db.manual[684] = true
	ns2.db.manual[62054] = true
	ns2.Progress.Refresh()
	eq(ns2.Progress.states[684].done, false, "live data overrides a manual tick")
	eq(ns2.Progress.states[62054].done, true, "challenge without live data uses the manual tick")
	eq(ns2.Progress.states[62054].source, "manual", "and is labelled manual")
	eq(world2.available, nil, "world untouched")
end

-- Uncatalogued challenges from a future patch ------------------------------------
do
	local ns = fresh({ discover = { [70001] = { cat = "Raids", sub = "New Raid" }, [70002] = { cat = "Fishing" }, [684] = { cat = "Raids" } },
		challenges = { [70001] = { name = "Conqueror of Something" } } })
	ns.Progress.Refresh()
	eq(#ns.Data.list, 67, "new challenges are added, known ones are not duplicated")
	eq(ns.Progress.states[70001].name, "Conqueror of Something", "live name used")
	eq(ns.Data.categories[7], "Fishing", "new category appended")
end

-- Recommendation scoring ---------------------------------------------------------
do
	local ns, world = fresh({ challenges = {
		[62009] = { done = true, mine = true },
		[62018] = { criteria = skill(135, 150) },
		[62019] = { criteria = skill(135, 225) },
		[62024] = { criteria = skill(78, 150) },
	} })
	ns.Progress.Refresh()
	local by = recs(ns)
	eq(by[62018].rank, 1, "closest achievable challenge ranks first")
	eq(by[62009], nil, "completed challenges are not recommended")
	check(by[62018].score > by[62024].score, "more progress scores higher")
	eq(by[62019].blocked, true, "unfinished earlier tier blocks the next")
	check(by[62019].why:find("comes after Journeyman Enchanter", 1, true), "blocked reason names the prerequisite")
	eq(by[62010].blocked, false, "finished prerequisite does not block")
	check(by[62010].why:find("60% complete", 1, true), "reason includes progress")
	eq(by[62010].remaining, "18 more levels (27 / 45)", "remaining levels")
	eq(by[62018].remaining, "15 more - 150 Skill (135 / 150)", "remaining skill")

	eq(by[61499].achievable, false, "another class is not achievable on this character")
	check(by[61499].why:find("needs a Warrior character", 1, true), "reason asks for the class")
	eq(by[62031].achievable, true, "level 27 can do the level 15 dungeon band")
	eq(by[62033].achievable, false, "level 27 cannot do the level 46 band")
	check(by[62033].score < by[62031].score, "unachievable ranks lower")

	-- an alt's snapshot feeds class challenges, and is described as a snapshot
	ns.db.chars["Alt-Realm"] = { name = "Alt", realm = "Realm", class = "WARRIOR", level = 20, seen = 1, mine = {}, frac = {} }
	by = recs(ns)
	eq(by[61499].frac, 0.8, "alt level drives class progress")
	check(by[61499].why:find("level 20 when last seen", 1, true), "alt data is labelled as last seen")

	-- preferences
	ns.db.settings.hideCats["Tradeskills"] = true
	by = recs(ns)
	eq(by[62018], nil, "hidden category is excluded")
	eq(#ns.Recommend.List(3), 3, "list respects its limit")

	-- multi-criteria remaining text
	world.challenges[62035] = { criteria = { { text = "A", done = true, q = 1, req = 1 }, { text = "B", done = false, q = 0, req = 1 } } }
	ns.Progress.Refresh()
	eq(ns.Recommend.Remaining(ns.Progress.states[62035], world.player), "1 of 2 left: B", "remaining encounters")
end

-- Planner ------------------------------------------------------------------------
do
	local ns = fresh()
	ns.Progress.Refresh()
	local Pl = ns.Planner
	Pl.Toggle(684); Pl.Toggle(62018); Pl.Toggle(62054)
	Pl.Toggle(999999)
	eq(#ns.db.plan, 3, "unknown ids cannot be pinned")
	eq(Pl.IsPinned(62018), true, "pinned")
	Pl.Move(62054, -1)
	eq(ns.db.plan[2], 62054, "custom order: move up")
	Pl.Move(684, -1)
	eq(ns.db.plan[1], 684, "moving past the top does nothing")
	Pl.Toggle(62018)
	eq(Pl.IsPinned(62018), false, "unpinned")
	Pl.SetNote(684, "  bring fire resist  ")
	eq(ns.db.notes[684], "bring fire resist", "note stored trimmed")
	Pl.SetNote(684, "   ")
	eq(ns.db.notes[684], nil, "blank note clears")
	ns.db.plan[#ns.db.plan + 1] = 123456
	eq(#Pl.List(), 2, "ids the game no longer lists are skipped")
	eq(Pl.List()[1].id, 684, "list follows plan order")
end

-- Characters: per-character versus account-wide ---------------------------------------
do
	local ns, world = fresh({ challenges = { [62009] = { done = true, mine = true }, [62018] = { criteria = skill(135, 150) } } })
	ns.Progress.Refresh()
	local main = ns.db.chars["Main-Realm"]
	eq(main.mine[62009], true, "snapshot records what this character earned")
	eq(main.frac[62018], 0.9, "snapshot records progress")
	eq(main.frac[62010], 0.6, "snapshot records derived progress")

	world.player = { name = "Alt", realm = "Realm", class = "MAGE", className = "Mage", level = 5 }
	world.challenges[62009] = { done = true, mine = false }
	world.challenges[62018] = nil
	world.now = 2000
	ns.Progress.Refresh()
	eq(ns.Progress.states[62009].done, true, "account-wide completion shows on the alt")
	eq(ns.db.chars["Alt-Realm"].mine[62009], nil, "but is not credited to the alt")
	eq(ns.db.chars["Main-Realm"].seen, 1000, "the other character's snapshot is untouched")
	eq(ns.db.chars["Main-Realm"].frac[62018], 0.9, "and keeps its own progress")
	eq(ns.Progress.key, "Alt-Realm", "current character key")
end

-- SavedVariables migration -------------------------------------------------------------
do
	local ns = fresh()
	local db = ns.Migrate(nil)
	eq(db.version, 1, "new database is versioned")
	eq(db.settings.notify, true, "defaults filled")
	eq(ns.Migrate("garbage").version, 1, "garbage input is replaced")

	db = ns.Migrate({ version = 1, plan = { 684 }, settings = { notify = false, hideCats = { Raids = true } }, chars = "bad" })
	eq(db.plan[1], 684, "existing data kept")
	eq(db.settings.notify, false, "existing setting kept, even when false")
	eq(db.settings.hideCats.Raids, true, "nested data kept")
	eq(db.settings.scale, 1, "missing setting filled")
	eq(type(db.chars), "table", "wrong-typed table repaired")

	ns.DB_VERSION = 3
	ns.migrations[1] = function(d) d.plan, d.pinned = d.pinned, nil end
	ns.migrations[2] = function(d) d.steps = (d.steps or 0) + 1 end
	db = ns.Migrate({ version = 1, pinned = { 684 } })
	eq(db.plan[1], 684, "migration 1 -> 2 ran")
	eq(db.steps, 1, "migration 2 -> 3 ran")
	eq(db.version, 3, "version bumped")
	db = ns.Migrate(db)
	eq(db.steps, 1, "migrations do not run twice")
	eq(ns.Migrate({ version = 9 }).version, 9, "a newer database is not downgraded")
end

-- Search and filtering --------------------------------------------------------------------
do
	local ns = fresh({ challenges = { [62009] = { done = true } } })
	local P = ns.Progress
	P.Refresh()
	eq(#P.Filter(P.list), 65, "no filter returns everything")
	eq(#P.Filter(P.list, { text = "WARLOCK" }), 3, "search is case-insensitive")
	eq(#P.Filter(P.list, { text = "warlock", hideDone = true }), 2, "hide completed")
	eq(#P.Filter(P.list, { cat = "Raids" }), 3, "category filter")
	eq(#P.Filter(P.list, { text = "enchanting" }), 3, "search matches the sub-category")
	eq(#P.Filter(P.list, { text = "onyxia" }), 1, "search matches the requirement")
	eq(#P.Filter(P.list, { text = "vs. player" }), 12, "search matches the category")
	eq(#P.Filter(P.list, { text = "(.*" }), 0, "search text is plain, not a pattern")
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
