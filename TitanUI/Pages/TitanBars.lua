-- TitanUI pages for TitanBars. Bars are secure frames, so these pages refuse changes in combat.
local ADDON, UI = ...
local P, W = UI.Percent, UI.Whole

local function General(p, TB)
	p:Header("Blizzard's bars")
	p:Check("Hide Blizzard action bars and art (needs /reload)",
		function() return TB.db.hideBlizzard end,
		function(v) TB.db.hideBlizzard = v; UI:Print("type /reload to apply.") end)
	p:Check("Hide bag + menu button art (needs /reload)",
		function() return TB.db.hideExtraArt end,
		function(v) TB.db.hideExtraArt = v; UI:Print("type /reload to apply.") end)
	p:Header("Buttons")
	p:Check("Show cooldown numbers on buttons",
		function() return GetCVarBool("countdownForCooldowns") end,
		function(v) SetCVar("countdownForCooldowns", v and "1" or "0") end)
	p:Check("Red icon when the target is out of range",
		function() return TB.db.colorRange end,
		function(v) TB.db.colorRange = v; TB:RefreshButtonColors() end,
		"Blizzard only turns the keybind text red. This tints the whole icon.")
	p:Check("Strong blue icon when you're short on mana",
		function() return TB.db.colorMana end,
		function(v) TB.db.colorMana = v; TB:RefreshButtonColors() end)
	p:Check("Move buttons to a new spell rank when you train it",
		function() return TB.db.autoRankUp end,
		function(v) TB.db.autoRankUp = v end,
		"Deliberate lower ranks you placed yourself are left alone.")
	p:Buttons({
		{ "Upgrade ranks now", function() TB:RankUpAll() end, "Puts the highest rank you know of every spell on your bars." },
		{ "Re-copy Blizzard keybinds", function() TB:ImportBlizzardKeys(true); TB:ApplyBindings() end },
	})
	p:Header("Move and bind")
	p:Buttons({
		{ function() return TB.unlocked and "Lock bars" or "Unlock bars" end,
			function() TB:SetUnlocked(not TB.unlocked) end,
			"Unlocked: drag bars, bags and menu buttons; mouse wheel to resize." },
		{ function() return TB.bindMode and "Stop binding" or "Keybind mode" end,
			function() TB:SetBindMode(not TB.bindMode) end,
			"Hover a button and press a key. Esc over a button clears it." },
	})
	p:Note("Pet and stance bars stay Blizzard's: move them in Edit Mode.")
end

local function Bar(id)
	return function(p, TB)
		local function C() return TB.db.bars[id] end
		local function Set(field) return function(v) C()[field] = v; TB:RefreshBar(id) end end
		local function Get(field) return function() return C()[field] end end
		p:Note(TB.BAR_INFO[id].label .. (id == 1 and " - swaps with stances, forms and stealth." or "."))
		p:Check("Enabled", Get("enabled"), Set("enabled"))
		p:Slider("Buttons", 1, 12, 1, Get("buttons"), Set("buttons"))
		p:Slider("Buttons per row", 1, 12, 1, Get("perRow"), Set("perRow"))
		p:Slider("Size", 0.3, 3, 0.05, Get("scale"), Set("scale"), P)
		p:Slider("Button spacing", 0, 20, 1, Get("padding"), Set("padding"))
		p:Slider("Opacity", 0.1, 1, 0.05, Get("alpha"), Set("alpha"), P)
		p:Edit("Show/hide rule (macro conditions, Enter to apply)", Get("visibility"), Set("visibility"),
			"Examples: [combat] show; hide   or   [mod:shift] show; hide")
		p:Buttons({
			{ "Reset this bar", function() TB:ResetBar(id); TB:RefreshBar(id) end },
		})
	end
end

local function Extras(p, TB)
	for _, info in ipairs(TB.EXTRAS) do
		p:Header(info.label)
		p:Slider("Size", 0.3, 3, 0.05,
			function() return TB:ExtraCfg(info.key).scale or (_G[info.name] and _G[info.name]:GetScale()) or 1 end,
			function(v) TB:ExtraCfg(info.key).scale = v; TB:ApplyExtra(info) end, P)
		p:Buttons({ { "Give back to Blizzard", function() TB:ResetExtra(info) end } })
	end
	p:Note("Unlock the bars (General page) to drag these around. While the info panel is on, it holds them instead.")
end

local READOUTS = {
	{ "coords", "Coordinates" }, { "zone", "Zone and subzone" }, { "clock", "Clock" },
	{ "perf", "FPS and latency" }, { "gold", "Gold" }, { "dura", "Lowest gear durability" },
	{ "bags", "Free bag slots" }, { "xp", "XP and rested XP" },
}

local function Panel(p, TB)
	local function Get(k) return function() return TB:PanelCfg()[k] end end
	local function Set(k) return function(v) TB:SetPanel(k, v) end end
	p:Check("Show the info panel", Get("enabled"), Set("enabled"))
	p:Choice("Position", { { "top", "Top of the screen" }, { "bottom", "Bottom of the screen" } }, Get("position"), Set("position"))
	p:Slider("Height", 20, 48, 1, Get("height"), Set("height"))
	p:Slider("Background", 0, 1, 0.05, Get("alpha"), Set("alpha"), P)
	p:Check("Dock buffs and debuffs to the panel", Get("dockBuffs"), Set("dockBuffs"))
	p:Header("Readouts")
	for _, r in ipairs(READOUTS) do
		p:Check(r[2], Get(r[1]), Set(r[1]))
	end
	p:Note("Turning the panel or buff docking off needs /reload to put things back in their usual spots.")
end

local function Profiles(p, TB)
	p:Note(function() return "This character uses: |cffffffff" .. TB:CharKey() .. "|r" end)
	local pick
	p:Choice("Copy layout from", function()
		local list = {}
		for name in pairs(TitanBarsDB.profiles) do
			if name ~= TB:CharKey() then table.insert(list, { name, name }) end
		end
		table.sort(list, function(a, b) return a[1] < b[1] end)
		if #list == 0 then list[1] = { nil, "(no other characters yet)" } end
		return list
	end, function() return pick end, function(v) pick = v end)
	p:Buttons({
		{ "Copy it to this character", function()
			if pick then TB:CopyProfileFrom(pick) else UI:Print("pick a character first.") end
		end, "Copies that character's bars, sizes, positions and keybinds over yours." },
	})
	p:Header("Start over")
	p:Buttons({
		{ "Reset every bar", function()
			for id = 1, TB.NUM_BARS do TB:ResetBar(id) end
			TB:RefreshAll()
		end },
	})
end

local pages = {
	{ key = "general", label = "General", build = General, noCombat = true },
}
for id = 1, 8 do
	table.insert(pages, { key = "bar" .. id, label = "Bar " .. id, build = Bar(id), noCombat = true })
end
table.insert(pages, { key = "extras", label = "Bags and menu", build = Extras, noCombat = true })
table.insert(pages, { key = "panel", label = "Info panel", build = Panel, noCombat = true })
table.insert(pages, { key = "profiles", label = "Profiles", build = Profiles, noCombat = true })

UI:Register({
	name = "TitanBars", global = "TitanBars",
	summary = "Action bars, keybinds, bag bar and menu buttons, info panel.",
	ready = function(ns) return ns.db ~= nil and ns.bars ~= nil end,
	pages = pages,
})
