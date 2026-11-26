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
		Points = function() return world.points end,
		Challenge = function(id)
			local c = world.challenges[id]
			if c == false then return nil end
			c = c or {}
			return { name = c.name or ns.Data.byId[id].name, desc = c.desc, done = c.done == true,
				date = c.date, criteria = c.criteria or {} }
		end,
	}
	ns.db = ns.Migrate(nil)
	return ns, world
end

local function skill(q, req) return { { text = req .. " Enchanting Skill", done = q >= req, q = q, req = req } } end
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
		if id == 1 then return 1, "One", 0, true, 11, 9, 26, "Desc", 0, 134400, "", false, true end
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
	eq(c.done, true, "adapter: account completion read")
	eq(c.mine, nil, "adapter: no per-character completion, the API's value is wrong for Legacy")
	eq(c.date, 20261109, "adapter: completion date")
	eq(c.icon, 134400, "adapter: icon")
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
	local ns, world = fresh({ player = { name = "Main", realm = "Realm", class = "WARLOCK", className = "Warlock", level = 27,
		profs = { [333] = 135 } }, challenges = {
		[62009] = { done = true },
		[62018] = { criteria = skill(135, 150) },
		[62019] = { criteria = skill(135, 225) },
		[62024] = { criteria = skill(78, 150) },
	} })
	ns.Progress.Refresh()
	local by = recs(ns)
	eq(by[62018].rank, 1, "closest achievable challenge ranks first")
	check(by[62018].why:find("this character is closest", 1, true), "reason says this character is closest")
	check(not by[684].achievable and not by[684].why:find("can work on it", 1, true), "no claim about raids this character may not be able to do")
	eq(by[684].why, "not started", "a reason is always given")
	eq(by[62009], nil, "completed challenges are not recommended")
	check(by[62018].score > by[62024].score, "more progress scores higher")
	eq(by[62019].blocked, true, "unfinished earlier tier blocks the next")
	check(by[62019].why:find("comes after Journeyman Enchanter", 1, true), "blocked reason names the prerequisite")
	eq(by[62010].blocked, false, "finished prerequisite does not block")
	check(by[62010].why:find("60% complete", 1, true), "reason includes progress")
	eq(by[62010].remaining, "18 more levels (27 / 45)", "remaining levels")
	eq(by[62018].remaining, "15 more Enchanting Skill (135 / 150)", "remaining skill")

	eq(by[61499].achievable, false, "another class is not achievable on this character")
	check(by[61499].why:find("needs a Warrior character", 1, true), "reason asks for the class")
	eq(by[62031].achievable, true, "level 27 can do the level 15 dungeon band")
	eq(by[62033].achievable, false, "level 27 cannot do the level 46 band")
	check(by[62033].score < by[62031].score, "unachievable ranks lower")

	-- an alt's snapshot feeds class challenges, and is described as a snapshot
	ns.db.chars["Alt-Realm"] = { name = "Alt", realm = "Realm", class = "WARRIOR", level = 20, seen = 1 }
	ns.Progress.Refresh()
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
	eq(ns.Recommend.Remaining(ns.Progress.states[62035]), "1 of 2 left: B", "remaining encounters")

	-- tracker lines
	local steps = ns.Recommend.Steps
	local st = ns.Progress.states
	eq(steps(st[62018])[1], "135/150 Enchanting Skill", "tracker: counter line")
	eq(steps(st[62010])[1], "Level 27/45", "tracker: derived level line")
	eq(steps(st[684])[1], "Defeat Onyxia.", "tracker: requirement when no criteria")
	world.challenges[62034] = { criteria = {} }
	for i = 1, 6 do world.challenges[62034].criteria[i] = { text = "Boss " .. i, done = i == 1, q = 0, req = 1 } end
	ns.Progress.Refresh()
	local bosses, more = steps(st[62034], 3)
	eq(#bosses, 3, "tracker: three steps")
	eq(bosses[1], "Boss 2", "tracker: finished steps are left out")
	eq(more, 2, "tracker: the rest are counted")
	eq(select(2, steps(st[62035])), 0, "tracker: short lists have nothing left over")
	eq(select(2, steps(st[684])), 0, "tracker: no criteria, nothing left over")
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

-- Characters: what is account-wide, what belongs to a character, and who is closest -----
do
	local main = { name = "Main", realm = "Realm", class = "WARLOCK", className = "Warlock", level = 56, profs = { [197] = 204 } }
	local rogue = { name = "Alt", realm = "Realm", class = "ROGUE", className = "Rogue", level = 1, profs = {} }
	local tailor = { { text = "225 Tailoring Skill", done = false, q = 204, req = 225 } }
	local ns, world = fresh({ player = main, challenges = { [62009] = { done = true }, [62029] = { criteria = tailor } } })
	local P, R = ns.Progress, ns.Recommend
	local function play(player) world.player = player; P.Refresh(); return P.states, recs(ns) end

	local st, by = play(main)
	eq(st[62029].closest.here, true, "playing the tailor: this character is closest")
	eq(R.Steps(st[62029])[1], "204/225 Tailoring Skill", "no name needed on that character")
	eq(R.Count(st[62029]), "204 / 225", "bar text for a counter")
	eq(R.Count(st[62011]), "Level 56 / 60", "bar text for a level")
	eq(R.Count({ criteria = { { done = true, req = 1 }, { done = false, req = 1 } } }), "1 / 2", "bar text for steps")
	eq(R.Count({ criteria = {}, source = "live" }), nil, "no bar text when nothing is counted")
	eq(R.Steps(st[62011])[1], "Level 56/60", "own class level")
	eq(by[62029].achievable, true, "and can work on it")

	world.now = 2000
	st, by = play(rogue)
	eq(st[62009].done, true, "completion is account-wide")
	eq(st[62029].frac, 204 / 225, "skill progress is account-wide")
	eq(R.Steps(st[62029])[1], "204/225 Tailoring Skill (Main)", "on an alt, the tracker names the tailor")
	eq(R.Steps(st[62011])[1], "Level 56/60 (Main)", "and the closest Warlock")
	eq(R.Remaining(st[62011]), "4 more levels (56 / 60) (Main)", "remaining names them too")
	eq(by[62029].achievable, false, "the alt is not told it can work on it")
	check(by[62029].why:find("closest: Main, Tailoring 204 when last seen", 1, true), "reason names character and skill")
	check(by[62011].why:find("closest: Main, level 56 when last seen", 1, true), "reason names character and level")
	check(by[62033].why:find("closest: Main, level 56 when last seen", 1, true), "dungeons name a character high enough")
	eq(R.Steps(st[62033])[1], st[62033].desc, "dungeon lines carry no name")
	check(by[62012].why:find("no character recorded with Alchemy", 1, true), "nobody has the profession")
	local alt = ns.db.chars["Alt-Realm"]
	eq(alt.mine, nil, "nothing account-wide is stored per character")
	eq(alt.frac, nil, "no progress stored per character")
	eq(ns.db.chars["Main-Realm"].seen, 1000, "the other snapshot is untouched")
	eq(ns.db.chars["Main-Realm"].profs[197], 204, "and keeps its skills")

	-- the account's best belongs to a character LegacyPath has not seen
	tailor[1].q = 220
	st, by = play(rogue)
	eq(st[62029].closest, nil, "does not credit a lower character")
	check(by[62029].why:find("closest character not recorded yet", 1, true), "says so")
	tailor[1].q = 204

	-- two of the same class, and changes during a session
	ns.db.chars["Second-Realm"] = { name = "Second", realm = "Realm", class = "WARLOCK", level = 51, seen = 1 }
	st = play(rogue)
	eq(st[62011].closest.name, "Main", "the higher of two Warlocks")
	local changes = 0
	ns.On("CHANGED", function() changes = changes + 1 end)
	ns.db.chars["Second-Realm"].level = 58
	st = play(rogue)
	eq(st[62011].closest.name, "Second", "follows whoever is ahead")
	check(changes > 0, "and the views are told")
	rogue.profs = { Tailoring = 204 }
	st = play(rogue)
	eq(st[62029].closest.here, true, "a tie goes to the character being played; names match too")
	ns.db.chars["Old-Realm"] = { name = "Old", realm = "Realm", class = "MAGE", level = 10, seen = 1 }
	st = play(rogue)
	eq(st[61994].closest.name, "Old", "a snapshot without professions is fine")
end

-- Full names ---------------------------------------------------------------------------
do
	local api = fresh().realAPI
	_G.UnitName = function() return "Kat", "Lo" end
	_G.GetRealmName = function() return "" end
	local p = api.Player()
	eq(p.name, "Kat Lo", "adapter: first and last name")
	eq(p.first, "Kat", "adapter: first name kept apart")
	_G.Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = "~" } }
	eq(api.Player().name, "Kat~Lo", "adapter: the game's own separator")
	_G.Constants = nil
	_G.UnitName = function() return "Kat", nil end
	eq(api.Player().name, "Kat", "adapter: no surname")
	eq(api.Player().first, nil, "adapter: and no separate first name")
	_G.UnitName = function() return "Kat", "Realm" end
	_G.GetRealmName = function() return "Realm" end
	eq(api.Player().name, "Kat", "adapter: a realm is not a surname")
	_G.UnitName, _G.GetRealmName = nil, nil

	-- same first name, different characters; old first-name records give way on login
	local function char(first, last, class, level)
		return { name = first .. " " .. last, first = first, realm = "", class = class, className = class, level = level, profs = {} }
	end
	local ns, world = fresh({ player = char("Kat", "Lo", "MAGE", 10), points = { available = 4, cap = 16 } })
	ns.db.chars["Kat-"] = { name = "Kat", realm = "", class = "MAGE", level = 9, seen = 5, unspent = 4 }
	ns.db.chars["Kat-Old"] = { name = "Kat", realm = "Old", class = "WARRIOR", level = 30, seen = 4 }
	local said = 0
	ns.On("UNSPENT", function() said = said + 1 end)
	ns.Progress.Refresh()
	check(ns.db.chars["Kat Lo"], "saved under the full name")
	eq(ns.db.chars["Kat-"], nil, "its old first-name record is replaced")
	check(ns.db.chars["Kat-Old"], "another class's record is left alone")
	eq(said, 0, "its known unspent points carry over, so a reload stays quiet")
	world.player = char("Kat", "Astrofen", "MAGE", 20)
	ns.Progress.Refresh()
	check(ns.db.chars["Kat Lo"] and ns.db.chars["Kat Astrofen"], "two with the same first name and class do not overwrite each other")
	world.player = { name = "Bob", realm = "", class = "ROGUE", className = "Rogue", level = 1, profs = {} }
	ns.Progress.Refresh()
	eq(ns.Recommend.Steps(ns.Progress.states[61994])[1], "Level 20/25 (Kat Astrofen)", "the tracker shows first and last name")
end

-- Real adapter: profession skills ----------------------------------------------------------
do
	local api = fresh().realAPI
	eq(next(api.Professions()), nil, "no profession API, no skills")
	_G.GetProfessions = function() return 5, nil, nil, 9, 11 end
	local data = { [5] = { "Tailoring", 1, 204, 225, 1, 1, 197 }, [9] = { "Fishing", 1, 0, 0, 1, 1, 356 }, [11] = { "Cooking", 1, 0, 0, 1, 1, 185 } }
	_G.GetProfessionInfo = function(i) return unpack(data[i]) end
	local p = api.Professions()
	eq(p[197], 204, "skill by skill line")
	eq(p.Tailoring, 204, "skill by name")
	eq(p[356], nil, "zero skill is not recorded")
	_G.C_TradeSkillUI = { GetProfessionInfoBySkillLineID = function(l) return { skillLevel = l == 185 and 77 or 0 } end }
	p = api.Professions()
	eq(p[185], 77, "second source used when the first is empty")
	eq(p[197], 204, "first source kept when the second is empty")
	_G.GetProfessionInfo = function() error("boom") end
	eq(next(api.Professions()), nil, "erroring API is no data")
	_G.GetProfessions, _G.GetProfessionInfo, _G.C_TradeSkillUI = nil, nil, nil
end

-- Unspent Legacy Points ---------------------------------------------------------------
do
	local ns, world = fresh()
	local told = {}
	ns.On("UNSPENT", function(n) told[#told + 1] = n end)
	local P = ns.Progress
	P.Refresh()
	eq(P.points, nil, "no points before Legacy unlocks")
	eq(#told, 0, "no reminder without data")
	world.points = { available = 2, cap = 16 }
	P.Refresh()
	eq(told[1], 2, "reminder when points appear")
	eq(ns.db.chars["Main-Realm"].unspent, 2, "snapshot records unspent points")
	P.Refresh()
	eq(#told, 1, "no repeat while the count stays the same")
	world.points = { available = 1, cap = 16 }
	local changes = 0
	ns.On("CHANGED", function() changes = changes + 1 end)
	P.Refresh()
	eq(#told, 1, "spending a point does not remind")
	eq(changes, 1, "spending a point updates the views")
	world.points = { available = 2, cap = 16 }
	P.Refresh()
	eq(told[2], 2, "earning another point reminds again")
	world.points = { available = 0, cap = 16 }
	P.Refresh()
	eq(#told, 2, "all spent: no reminder")
	eq(ns.db.chars["Main-Realm"].unspent, 0, "snapshot shows none left")

	-- across sessions: a new addon instance on the same saved data
	local db = { v = ns.db }
	local function start(available, isLogin, player)
		local n2, w = fresh({ points = { available = available, cap = 16 }, player = player })
		n2.db = db.v
		n2.Progress.login = isLogin or nil
		local said = { n = 0 }
		n2.On("UNSPENT", function() said.n = said.n + 1 end)
		n2.Progress.Refresh()
		n2.Progress.Refresh()
		return said, n2, w
	end
	local alt = { name = "Alt", realm = "Realm", class = "MAGE", className = "Mage", level = 1 }
	eq(start(7, true, alt).n, 1, "a login reminds, once")
	eq(start(7, true, alt).n, 1, "the next login reminds again")
	eq(start(7, false, alt).n, 0, "a reload does not")
	eq(start(8, false, alt).n, 1, "unless there are more points to spend")
	eq(start(5, false, alt).n, 0, "spending and reloading does not")
	eq(start(0, true, alt).n, 0, "nothing to spend, nothing said")
	eq(start(3, true).n, 1, "another character reminds at its own login")
	db.v.settings.unspent = false
	eq(start(9, true, alt).n, 0, "turned off: silent")
	db.v.settings.unspent = true
	local said, n3, w3 = start(9, true, alt)
	eq(said.n, 1, "turned back on: reminds at the next login")
	w3.points = { available = 8, cap = 16 }
	n3.Progress.Refresh()
	w3.points = nil
	n3.Progress.Refresh()
	w3.points = { available = 8, cap = 16 }
	n3.Progress.Refresh()
	eq(said.n, 1, "spending, or a gap in the data, does not remind again")
	-- points not ready at the first refresh after login
	local n4, w4 = fresh({ player = alt })
	n4.db, n4.Progress.login = db.v, true
	said = 0
	n4.On("UNSPENT", function() said = said + 1 end)
	n4.Progress.Refresh()
	w4.points = { available = 8, cap = 16 }
	n4.Progress.Refresh()
	eq(said, 1, "still reminds when the points arrive late")

	-- real adapter against fake trait globals
	local api = ns.realAPI
	eq(api.Points(), nil, "adapter: no trait API, no points")
	_G.Constants = { LegacyConsts = { LEGACY_TREE_PROFESSIONS_ID = 1187 } }
	local info = { quantity = 3, maxQuantity = 16 }
	_G.C_Traits = {
		GetConfigIDByTreeID = function(tree) return tree == 1187 and 77 or nil end,
		GetTreeCurrencyInfo = function(config, tree, staged)
			assert(config == 77 and tree == 1187 and staged == false)
			return { info }
		end,
	}
	local pts = api.Points()
	eq(pts and pts.available, 3, "adapter: available points read like Blizzard's panel")
	eq(pts and pts.cap, 16, "adapter: spend cap")
	_G.issecretvalue = function(v) return v == info.quantity end
	eq(api.Points(), nil, "adapter: secret quantity is no data")
	_G.issecretvalue = nil
	_G.C_Traits.GetConfigIDByTreeID = function() return nil end
	eq(api.Points(), nil, "adapter: no config before Legacy unlocks")
	_G.C_Traits.GetConfigIDByTreeID = function() error("boom") end
	eq(api.Points(), nil, "adapter: erroring API is no data")
	_G.Constants, _G.C_Traits = nil, nil
end

-- SavedVariables migration -------------------------------------------------------------
do
	local ns = fresh()
	local db = ns.Migrate(nil)
	eq(db.version, 3, "new database is versioned")
	eq(db.settings.notify, true, "defaults filled")
	eq(ns.Migrate("garbage").version, 3, "garbage input is replaced")
	db = ns.Migrate({ version = 2, chars = {
		["A-"] = { name = "A", class = "MAGE", seen = 9, level = 20 }, ["A-Realm"] = { name = "A", class = "MAGE", seen = 3, level = 10 },
		["B-Realm"] = { name = "B", class = "MAGE", seen = 1 }, ["B-"] = { name = "B", class = "ROGUE", seen = 2 }, ["C-"] = {} } })
	eq(db.chars["A-"].level, 20, "duplicate characters: the newest is kept")
	eq(db.chars["A-Realm"], nil, "and the older one dropped")
	check(db.chars["B-Realm"] and db.chars["B-"], "same first name but another class is not a duplicate")
	check(db.chars["C-"], "an incomplete record is tolerated")
	db = ns.Migrate({ version = 1, chars = { ["A-R"] = { level = 1, unspent = 7, mine = { [1] = true }, frac = { [2] = 0.9 } } } })
	eq(db.chars["A-R"].mine, nil, "wrong per-character completions are dropped")
	eq(db.chars["A-R"].frac, nil, "wrong per-character progress is dropped")
	eq(db.chars["A-R"].unspent, 7, "real per-character data is kept")

	db = ns.Migrate({ version = 1, plan = { 684 }, settings = { notify = false, hideCats = { Raids = true } }, chars = "bad" })
	eq(db.plan[1], 684, "existing data kept")
	eq(db.settings.notify, false, "existing setting kept, even when false")
	eq(db.settings.hideCats.Raids, true, "nested data kept")
	eq(db.settings.scale, 1, "missing setting filled")
	eq(type(db.chars), "table", "wrong-typed table repaired")

	ns.DB_VERSION, ns.migrations = 3, {}
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
