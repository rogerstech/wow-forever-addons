-- TitanUI page for TitanCraft.
local ADDON, UI = ...
local P = UI.Percent

local function Build(p, TC)
	local db = TC.db
	local function Get(k) return function() return db[k] end end
	local function Redraw()
		if TC.frame and TC.frame:IsShown() then TC:PlaceWindow(); TC:Refresh() end
	end
	local function Set(k) return function(v) db[k] = v; Redraw() end end

	p:Check("Use TitanCraft instead of Blizzard's profession window", Get("replace"),
		function(v) db.replace = v; TC:Sync() end,
		"Untick to go back to Blizzard's window. The TitanCraft window's \"Blizzard window\" button also switches for one session.")
	p:Header("Recipe list")
	p:Choice("Sort recipes by", function()
		local list = {}
		for i, s in ipairs(TC.SORTS) do list[i] = { s.key, s.label } end
		return list
	end, Get("sort"), Set("sort"))
	p:Check("Only recipes I have materials for", Get("haveMats"), Set("haveMats"))
	p:Check("Hide grey recipes (no skill points)", Get("hideTrivial"), Set("hideTrivial"))
	p:Header("Window")
	p:Slider("Size", 0.6, 1.5, 0.05, Get("scale"), Set("scale"), P)
	p:Slider("Height", 380, 1000, 10, Get("height"), Set("height"))
	p:Check("Lock position", Get("locked"), Set("locked"))
	p:Buttons({ { "Reset position", function() db.pos = nil; TC:PlaceWindow() end } })
	p:Note("Recipe colours: orange always gives a skill point, yellow usually, green sometimes, grey never. "
		.. "\"Craft next skill-up\" makes one of the best recipe you have materials for; click it again after each craft.")
end

UI:Register({
	name = "TitanCraft", global = "TitanCraft",
	summary = "Faster, movable crafting window with skill-up sorting and one-click skill-ups.",
	ready = function(ns) return ns.db ~= nil and ns.frame ~= nil end,
	pages = { { key = "main", label = "TitanCraft", build = Build } },
})
