-- TitanFish: the fishing skill at which fish stop getting away in each zone
-- (Timesaver's Forever table, checked 2026-11-22). Below it you still catch fish,
-- just with more misses. English zone names; unknown zones show no number.
local ADDON, TF = ...

TF.ZONE_SKILL = {}
local TIERS = {
	[25] = { "Dun Morogh", "Elwynn Forest", "Teldrassil", "Durotar", "Mulgore", "Tirisfal Glades" },
	[75] = { "Blackfathom Deeps", "Darkshore", "Darnassus", "Ironforge", "Loch Modan", "Silverpine Forest",
		"Stormwind City", "The Barrens", "The Deadmines", "Wailing Caverns", "Westfall", "Orgrimmar",
		"Thunder Bluff", "Undercity" },
	[150] = { "Ashenvale", "Duskwood", "Hillsbrad Foothills", "Redridge Mountains", "Stonetalon Mountains", "Wetlands" },
	[225] = { "Alterac Mountains", "Arathi Highlands", "Desolace", "Dustwallow Marsh", "Scarlet Monastery",
		"Stranglethorn Vale", "Swamp of Sorrows", "Thousand Needles" },
	[300] = { "Azshara", "Felwood", "Feralas", "Jaguero Isle", "Maraudon", "Moonglade", "Sunken Temple", "Tanaris",
		"The Hinterlands", "Un'Goro Crater", "Western Plaguelands" },
}
for skill, zones in pairs(TIERS) do
	for _, z in ipairs(zones) do TF.ZONE_SKILL[z] = skill end
end
-- Capital-city alias the game sometimes uses.
TF.ZONE_SKILL["Stormwind"] = 75

-- Lures, best first: item ID, bonus, minimum fishing skill to use.
TF.LURES = {
	{ id = 6533, bonus = 100, min = 100 }, -- Aquadynamic Fish Attractor
	{ id = 6532, bonus = 75,  min = 100 }, -- Bright Baubles
	{ id = 7307, bonus = 75,  min = 100 }, -- Flesh Eating Worm
	{ id = 6530, bonus = 50,  min = 50 },  -- Nightcrawlers
	{ id = 6811, bonus = 50,  min = 50 },  -- Aquadynamic Fish Lens
	{ id = 6529, bonus = 25,  min = 1 },   -- Shiny Bauble
}

-- What to do next, by base skill.
function TF.NextStep(skill, max)
	if skill < 50 then return "Journeyman at 50 (character level 10)" end
	if max <= 75 then return "learn Journeyman from a fishing trainer" end
	if skill < 125 then return "Expert book in Booty Bay at 125 (level 20)" end
	if max <= 150 then return "read Expert Fishing - The Bass and You (Booty Bay)" end
	if skill < 225 then return "Nat Pagle's quest at 225 (level 35)" end
	if max <= 225 then return "Nat Pagle, Dustwallow Marsh: Artisan quest" end
	if skill < 300 then return "Feralas with Bright Baubles to 300" end
	return "maxed: Sunday Extravaganza for the Arcanite pole"
end
