-- Reference only. From Blizzard's Legacy System post (23 Sep 2026). Reward thresholds
-- and perk costs are not published and the client did not report them, so none are listed.
local _, ns = ...

ns.Reference = {
	source = "Blizzard news post; thresholds and costs not published",
	spendCap = 16, -- points one character can spend at launch
	rewards = {
		{ name = "Replica Ironforge Air Rifle", kind = "Toy" },
		{ name = "Spectral Bear Cub", kind = "Pet" },
		{ name = "Spectral Bear Tabard", kind = "Tabard" },
		{ name = "Reins of the Spectral Bear", kind = "Mount" },
	},
	perks = {
		{ tree = "Professions", "Working Overtime", "Bountiful Harvest", "Bartering", "Performance", "Master Chef", "Luremaster", "Dedicated Study" },
		{ tree = "Adventure", "Well Rested", "Thrill of Adventure", "High Alert", "Field Guide", "Field Medicine", "Talented", "Frequent Flier" },
		{ tree = "Resourcefulness", "Gourmand", "The Quick and the Dead", "Reinforce", "For Great Honor", "Permanence", "Diplomat", "Reagent Economy" },
	},
}
