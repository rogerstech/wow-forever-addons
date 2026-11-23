-- TitanUI page for TitanFish.
local ADDON, UI = ...
local P = UI.Percent

local function Build(p, TF)
	local db = TF.db
	local function Get(k) return function() return db[k] end end
	local function Set(k) return function(v) db[k] = v; TF:Update() end end
	p:Header("Casting")
	p:Check("Double-right-click the water to cast (while a fishing pole is equipped)", Get("doubleClick"), Set("doubleClick"),
		"Right-click the bobber once to loot as usual. You can also bind keys: Esc > Options > Keybindings > AddOns > TitanFish.")
	p:Check("Loud splash: sound effects up, music and ambience off while you fish", Get("loudSplash"), Set("loudSplash"),
		"Your sound settings go back as soon as you stop fishing or take the pole off.")
	p:Check("Auto-loot while fishing", Get("autoLoot"), Set("autoLoot"))
	p:Header("Window")
	p:Choice("Show the window", { { "pole", "While a fishing pole is equipped" }, { "always", "Always" }, { "never", "Never (use /tfish)" } },
		Get("window"), function(v) db.window = v; TF.forceShow = nil; TF:Update() end)
	p:Slider("Size", 0.6, 1.6, 0.05, Get("scale"), function(v) db.scale = v; TF:PlaceWindow() end, P)
	p:Check("Lock position", Get("locked"), Set("locked"))
	p:Buttons({
		{ "Swap pole / weapons", function() TF:SwapPole() end },
		{ "Clear catch log", function() SlashCmdList.TITANFISH("clear") end },
		{ "Reset position", function() db.pos = nil; TF:PlaceWindow() end },
	})
	p:Note("The window shows your fishing skill, whether this zone's fish can still get away at your skill, your next step "
		.. "(Journeyman, Expert book, Nat Pagle...), a one-click lure button with time left, and what you've caught here.")
end

UI:Register({
	name = "TitanFish", global = "TitanFish",
	summary = "Fishing helper: double-click cast, loud splash, lures, pole swap, catch log.",
	ready = function(ns) return ns.db ~= nil end,
	pages = { { key = "main", label = "TitanFish", build = Build, noCombat = true } },
})
