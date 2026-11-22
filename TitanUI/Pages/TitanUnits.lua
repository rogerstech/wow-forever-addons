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
		{ function() return db.locked and "Unlock to move" or "Lock" end, function() TU:SetLocked(not db.locked) end,
			"Unlocked: green box = party, blue box = raid (8 groups), orange box = boss frames. Each moves on its own." },
		{ "Reset positions", function() db.pos, db.raidPos, db.bossPos = nil, nil, nil; TU:ApplyLayout() end },
	})
	p:Buttons({
		{ function() return TU.testMode == "party" and "Stop test" or "Test: full party" end,
			function() TU:SetTest("party") end, "Shows a fake full party so you can place and size the frames." },
		{ function() return TU.testMode == "raid" and "Stop test" or "Test: full raid" end,
			function() TU:SetTest("raid") end, "Shows a fake 40-person raid (8 groups) so you can place and size the frames." },
		{ function() return TU.testMode == "boss" and "Stop test" or "Test: bosses" end,
			function() TU:SetTest("boss") end, "Shows 5 fake boss frames so you can place them." },
	})

	p:Header("Boss frames")
	p:Check("Use TitanUnits boss frames (boss fights in dungeons and raids)", Get("bossEnabled"), Set("bossEnabled"),
		"Same size and look as the group frames. Border: green = the boss is attacking you, red = it isn't.")
	p:Check("Hide Blizzard's boss frames", Get("hideBlizzardBoss"), Set("hideBlizzardBoss"))

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

local function Solo(p, TU)
	local c = TU:SoloCfg()
	local function Get(k) return function() return c[k] end end
	local function Set(k) return function(v) c[k] = v; TU:ApplySolo() end end

	p:Check("Use TitanUnits player and target frames", Get("enabled"), Set("enabled"))
	p:Check("Hide Blizzard's player and target frames", Get("hideBlizzard"), function(v)
		c.hideBlizzard = v
		TU:ApplySolo()
		if not v then UI:Print("if Blizzard's frames don't come back in the right spot, type /reload.") end
	end)
	p:Buttons({
		{ function() return c.locked and "Unlock to move" or "Lock" end, function() TU:SetSoloLocked(not c.locked) end,
			"Unlocked: drag the player or target frame (target something to see its frame)." },
		{ "Reset positions", function() wipe(c.pos); TU:ApplySolo() end },
	})
	p:Header("Portrait")
	p:Choice("Portrait", { { "3d", "Animated 3D face" }, { "2d", "Flat picture" }, { "class", "Class icon" } },
		Get("portrait"), Set("portrait"),
		"The 3D face needs the unit to be loaded near you; further away it shows the flat picture.")
	p:Header("Size")
	p:Slider("Width", 200, 400, 2, Get("width"), Set("width"))
	p:Slider("Height", 44, 100, 1, Get("height"), Set("height"))
	p:Slider("Scale", 0.5, 2, 0.05, Get("scale"), Set("scale"), P)
	p:Header("Target")
	p:Check("Show your threat (green border = it's on you, red = it isn't)", Get("threat"), Set("threat"))
	p:Check("Show the target's buffs and debuffs", Get("auras"), Set("auras"))
	p:Check("Only my debuffs", Get("myDebuffsOnly"), Set("myDebuffsOnly"))
	p:Slider("Buff / debuff icon size", 14, 40, 1, Get("auraSize"), Set("auraSize"))
	p:Check("Target cast bar (orange = can be interrupted, grey + shield = can't)", Get("castbar"), Set("castbar"))
	p:Slider("Cast bar height", 10, 32, 1, Get("castHeight"), Set("castHeight"))
	p:Note("Left-click a frame to target, right-click for the usual menu. Size and position changes made in combat apply when it ends.")
end

UI:Register({
	name = "TitanUnits", global = "TitanUnits",
	summary = "Modern player/target frames with animated 3D faces, and tanking party/raid frames.",
	ready = function(ns) return ns.db ~= nil and ns.party ~= nil and ns.SoloCfg ~= nil end,
	pages = {
		{ key = "solo", label = "Player & target", build = Solo, noCombat = true },
		{ key = "group", label = "Group frames", build = Build, noCombat = true },
	},
})
