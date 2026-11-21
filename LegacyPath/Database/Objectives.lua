-- The 65 Legacy Challenges. IDs, names and categories were read from the game client
-- (LegacyPathProbe, build 1.60.1.70862). Names and requirements are replaced by live
-- client text when available; `req` is the fallback wording.
-- `diff` (1-3) and `prereq` are LegacyPath's own estimates/ordering, not Blizzard data.
local _, ns = ...

local D = {
	list = {},
	byId = {},
	rejected = {},
	categories = { "Classes", "Tradeskills", "Player vs. Player", "Dungeons", "Raids", "Adventure" },
	source = "Game client, build 1.60.1.70862",
}
ns.Data = D

local validCat = {}
for _, cat in ipairs(D.categories) do validCat[cat] = true end

-- Adds a record, or rejects it with a reason. Challenges the client lists but this file
-- does not (`uncatalogued`) may bring a new category with them.
function D.Add(o)
	if type(o) == "table" and o.uncatalogued and type(o.cat) == "string" and not validCat[o.cat] then
		validCat[o.cat] = true
		D.categories[#D.categories + 1] = o.cat
	end
	local why = type(o) ~= "table" and "not a table"
		or type(o.id) ~= "number" and "missing id"
		or (type(o.name) ~= "string" or o.name == "") and "missing name"
		or not validCat[o.cat] and "unknown category"
		or D.byId[o.id] and "duplicate id"
	if why then
		D.rejected[#D.rejected + 1] = why
		return false, why
	end
	o.sub, o.diff = o.sub or o.cat, o.diff or 2
	D.list[#D.list + 1] = o
	D.byId[o.id] = o
	return true
end

local classes = {
	{ "WARRIOR", "Warrior", 61499, 61500, 61501 }, { "DRUID", "Druid", 61502, 61503, 61504 },
	{ "HUNTER", "Hunter", 61989, 61992, 61993 }, { "MAGE", "Mage", 61994, 61995, 61996 },
	{ "PALADIN", "Paladin", 61997, 61998, 61999 }, { "PRIEST", "Priest", 62000, 62001, 62002 },
	{ "ROGUE", "Rogue", 62003, 62004, 62005 }, { "SHAMAN", "Shaman", 62006, 62007, 62008 },
	{ "WARLOCK", "Warlock", 62009, 62010, 62011 },
}
for _, c in ipairs(classes) do
	for i, tier in ipairs({ { "Novice", 25 }, { "Experienced", 45 }, { "Master", 60 } }) do
		D.Add({ id = c[2 + i], cat = "Classes", sub = c[2], name = tier[1] .. " " .. c[2], kind = "class", class = c[1],
			level = tier[2], diff = i, prereq = i > 1 and c[1 + i] or nil,
			req = ("Reach level %d for the first time on a %s."):format(tier[2], c[2]) })
	end
end

local professions = {
	{ "Alchemy", "Alchemist", 62012 }, { "Blacksmithing", "Blacksmith", 62015 }, { "Enchanting", "Enchanter", 62018 },
	{ "Engineering", "Engineer", 62021 }, { "Leatherworking", "Leatherworker", 62024 }, { "Tailoring", "Tailor", 62028 },
}
for _, p in ipairs(professions) do
	for i, tier in ipairs({ { "Journeyman", 150 }, { "Expert", 225 }, { "Artisan", 300 } }) do
		local id = p[3] + i - 1
		D.Add({ id = id, cat = "Tradeskills", sub = p[1], name = tier[1] .. " " .. p[2], diff = i, prereq = i > 1 and id - 1 or nil,
			req = ("Reach %d skill in %s for the first time."):format(tier[2], p[1]) })
	end
end

local PVP = "Player vs. Player"
for i, rank in ipairs({ 3, 7, 10, 13, 14 }) do
	D.Add({ id = 62040 + i, cat = PVP, sub = "Ranks", name = "Rank " .. rank, diff = math.min(i, 3), prereq = i > 1 and 62039 + i or nil,
		req = ("Reach rank %d in the Player vs. Player Honor System."):format(rank) })
end
for i, bg in ipairs({ "Alterac Valley", "Arathi Basin", "Warsong Gulch", "Darkspear Islands" }) do
	D.Add({ id = 62045 + i, cat = PVP, sub = "Reputations", name = "Master of " .. bg, diff = 3,
		req = ("Reach exalted reputation with your faction's %s battleground reputation."):format(bg) })
end
for i, week in ipairs({ 4, 7, 10 }) do
	D.Add({ id = 63339 + i, cat = PVP, sub = "Season Journey", name = "Field of Honor: Week " .. week, diff = i, prereq = i > 1 and 63338 + i or nil,
		req = ("Complete Week %d of the Field of Honor Journey."):format(week) })
end

-- Dungeon level bands are from Blizzard's Legacy System post.
for i, t in ipairs({ { "Novice", 15, 25 }, { "Experienced", 26, 45 }, { "Master", 46, 60 } }) do
	D.Add({ id = 62030 + i, cat = "Dungeons", name = t[1] .. " Spelunker", diff = i, minLevel = t[2],
		req = ("Defeat the final boss in all level %d to %d dungeons."):format(t[2], t[3]) })
end

D.Add({ id = 684, cat = "Raids", name = "Conqueror of the Lair", diff = 3, req = "Defeat Onyxia." })
D.Add({ id = 62034, cat = "Raids", name = "Conqueror of the Wilds", diff = 3, req = "Defeat all 13 encounters in Hyjal Summit." })
D.Add({ id = 62035, cat = "Raids", name = "Conqueror of the Deeps", diff = 3, req = "Defeat all 8 encounters in the Barrow Deeps." })

D.Add({ id = 62382, cat = "Adventure", sub = "Explorer", name = "Explorer", diff = 2, req = "Have a character with the Explore Azeroth achievement." })
D.Add({ id = 62054, cat = "Adventure", name = "Lord Valthalak Laid to Rest", diff = 3,
	req = "Complete the questline beginning with An Earnest Proposition, and ending with Saving the Best for Last." })
