-- TitanUI page for TitanTips.
local ADDON, UI = ...

local function Build(p, TT)
	local db = TT.db
	local function Get(k) return function() return db[k] end end
	local function Set(k) return function(v) db[k] = v end end
	p:Header("Items")
	p:Check("Item level on gear", Get("itemLevel"), Set("itemLevel"))
	p:Check("Which of your professions use it", Get("usedIn"), Set("usedIn"),
		"Learned from TitanCraft: open each profession once and its reagents show up here.")
	p:Check("How many your other characters have (bags, bank, worn)", Get("altCounts"), Set("altCounts"),
		"Each character is remembered when you log in on it. Banks are remembered when you open them.")
	p:Check("Item ID", Get("itemID"), Set("itemID"))
	p:Header("Units and spells")
	p:Check("Class-coloured player names", Get("classColors"), Set("classColors"))
	p:Check("Who they're targeting", Get("unitTarget"), Set("unitTarget"))
	p:Check("Spell ID", Get("spellID"), Set("spellID"))
	p:Header("Remembered characters")
	p:Note(function()
		local names = {}
		for _, c in ipairs(TT:Characters()) do table.insert(names, c.name) end
		return #names > 0 and table.concat(names, ", ") or "none yet"
	end)
	p:Note("To forget a character you deleted: /ttips forget Name")
end

UI:Register({
	name = "TitanTips", global = "TitanTips",
	summary = "Better tooltips: item level, what your crafts use, alt counts, unit targets.",
	ready = function(ns) return ns.db ~= nil and ns.ready end,
	pages = { { key = "main", label = "TitanTips", build = Build } },
})
