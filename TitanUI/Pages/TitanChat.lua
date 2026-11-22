-- TitanUI page for TitanChat.
local ADDON, UI = ...
local P = UI.Percent

-- Same order as TitanChat's own font list.
local FONTS = { { 1, "Arial Narrow" }, { 2, "Friz Quadrata" }, { 3, "Game default" } }

local function Build(p, TC)
	local db = TC.db
	local function Get(k) return function() return db[k] end end
	local function Set(k) return function(v) db[k] = v; TC:RefreshAll() end end
	p:Slider("Background", 0, 1, 0.05, Get("bgAlpha"), Set("bgAlpha"), P)
	p:Slider("Line spacing", 0, 8, 1, Get("spacing"), Set("spacing"))
	p:Choice("Font", FONTS, Get("font"), Set("font"))
	p:Check("Outlined text", Get("outline"), Set("outline"))
	p:Check("Hide the buttons beside chat", Get("hideButtons"), Set("hideButtons"))
	p:Note("Font size, colours and channels stay in Blizzard's chat settings (right-click a chat tab). "
		.. "Turning TitanChat off fully needs the AddOns list + /reload.")
end

UI:Register({
	name = "TitanChat", global = "TitanChat",
	summary = "Cleaner, flatter look for Blizzard's chat windows.",
	ready = function(ns) return ns.db ~= nil and ns.ready end,
	pages = { { key = "main", label = "TitanChat", build = Build } },
})
