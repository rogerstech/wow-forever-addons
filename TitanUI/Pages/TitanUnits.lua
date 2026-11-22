-- TitanUI page for TitanUnits. Group frames are secure: changes wait until combat ends.
local ADDON, UI = ...
local P = UI.Percent

local function Build(p, TU)
	local db = TU.db
	local function Get(k) return function() return db[k] end end
	local function Set(k) return function(v) db[k] = v; TU:ApplyLayout() end end

	p:Check("Use TitanUnits group frames", Get("enabled"), Set("enabled"))
	p:Check("Hide Blizzard's party and raid frames", Get("hideBlizzard"), function(v)
		db.hideBlizzard = v
		TU:ApplyLayout()
		if not v then UI:Print("if Blizzard's frames don't come back in the right spot, type /reload.") end
	end)
	p:Buttons({
		{ function() return db.locked and "Unlock to move" or "Lock" end, function() TU:SetLocked(not db.locked) end },
		{ "Reset position", function() db.pos = nil; TU:ApplyLayout() end },
	})

	p:Header("Who shows")
	p:Check("Show yourself in party frames", Get("showPlayer"), Set("showPlayer"))
	p:Check("Show your frame while solo (to set them up)", Get("showSolo"), Set("showSolo"))
	p:Choice("Party grows", { { "down", "Downward (column)" }, { "right", "To the right (row)" } }, Get("grow"), Set("grow"))

	p:Header("Size")
	p:Slider("Width", 60, 250, 2, Get("width"), Set("width"))
	p:Slider("Height", 20, 80, 1, Get("height"), Set("height"))
	p:Slider("Spacing", 0, 12, 1, Get("spacing"), Set("spacing"))
	p:Slider("Scale", 0.5, 2, 0.05, Get("scale"), Set("scale"), P)

	p:Header("Look")
	p:Check("Class-coloured health bars", Get("classColors"), Set("classColors"),
		"Off: green bars with class-coloured names.")
	p:Check("Mana / power bar", Get("power"), Set("power"))
	p:Choice("Health text", { { "percent", "Percent" }, { "none", "None" } }, Get("healthText"), Set("healthText"))
	p:Slider("Out-of-range fade", 0.1, 1, 0.05, Get("rangeAlpha"), Set("rangeAlpha"), P)

	p:Header("Tanking")
	p:Check("Red border on anyone who pulled a mob off you", Get("aggro"), Set("aggro"),
		"Uses the game's threat state. If the game hides that, it falls back to whether your current target is on them.")
	p:Note("White outline = your current target. Left-click a frame to target, right-click for the menu.")
end

UI:Register({
	name = "TitanUnits", global = "TitanUnits",
	summary = "Party and raid frames for tanking: health, mana, range, aggro warning.",
	ready = function(ns) return ns.db ~= nil and ns.party ~= nil end,
	pages = { { key = "main", label = "TitanUnits", build = Build, noCombat = true } },
})
