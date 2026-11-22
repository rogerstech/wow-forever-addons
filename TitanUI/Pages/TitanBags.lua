-- TitanUI page for TitanBags.
local ADDON, UI = ...
local P = UI.Percent

local function Build(p, TB)
	local db = TB.db
	local function Get(k) return function() return db[k] end end

	p:Header("Window")
	p:Choice("Show items by", function()
		local list = {}
		for i, v in ipairs(TB.VIEWS) do list[i] = { v.key, v.label } end
		return list
	end, Get("view"), function(v) db.view = v; TB:Layout() end,
		"Only changes how the window draws your items; nothing moves in your bags.")
	p:Slider("Slots per row", 6, 30, 1, Get("columns"), function(v) db.columns = v; TB:Layout() end)
	p:Slider("Size", 0.5, 2, 0.05, Get("scale"), function(v) db.scale = v; TB:Layout() end, P)
	p:Check("Lock position", Get("locked"), function(v) db.locked = v end)
	if TB:KeyringID() then
		p:Check("Show the keyring", Get("showKeys"),
			function(v) db.showKeys = v; TB:ApplyBlizzard(); TB:Layout(); TB:Sync() end)
	end
	p:Check("Hide Blizzard's bag windows (use TitanBags)", Get("hideBlizzard"),
		function(v) db.hideBlizzard = v; TB:ApplyBlizzard(); TB:Sync() end,
		"Untick to go back to Blizzard's own bags.")

	p:Header("Sorting")
	if C_Container and C_Container.GetSortBagsRightToLeft then
		p:Check("Sort fills the last bag first",
			function() return C_Container.GetSortBagsRightToLeft() end,
			function(v) C_Container.SetSortBagsRightToLeft(v) end)
	end
	p:Buttons({
		{ "Sort bags now", function() TB:SortBags() end, "Tidies your bags for real (items move). Not in combat." },
		{ "Open bags", function() ToggleAllBags() end },
		{ "Reset position", function() db.pos = nil; TB:PlaceWindow() end },
	})
end

UI:Register({
	name = "TitanBags", global = "TitanBags",
	summary = "All your bags in one movable window, with sorting.",
	ready = function(ns) return ns.db ~= nil and ns.frame ~= nil end,
	pages = { { key = "main", label = "TitanBags", build = Build } },
})
