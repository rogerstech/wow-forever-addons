-- TitanUI pages for TitanMeter.
local ADDON, UI = ...
local P = UI.Percent

local function Window(key)
	return function(p, TM)
		local function C() return TM.db[key] end
		local function Get(k) return function() return C()[k] end end
		local function Set(k) return function(v) C()[k] = v; TM:RefreshAll() end end
		if key == "meter" then
			p:Check("Show the damage meter", Get("enabled"), Set("enabled"))
			p:Choice("Showing", function()
				local list = {}
				for i, m in ipairs(TM.MODES or {}) do
					list[i] = { i, type(m) == "table" and (m.label or m.name or tostring(i)) or tostring(m) }
				end
				return list
			end, Get("mode"), Set("mode"))
			p:Choice("Fight", { { false, "Current fight" }, { true, "Overall" } }, Get("overall"), Set("overall"))
		else
			p:Check("Show the threat meter", Get("enabled"), Set("enabled"))
			p:Choice("When", { { "combat", "Only in combat" }, { "always", "Always" } }, Get("show"), Set("show"))
		end
		p:Header("Size")
		p:Slider("Rows", 1, 40, 1, Get("rows"), Set("rows"))
		p:Slider("Width", 120, 600, 5, Get("width"), Set("width"))
		p:Slider("Row height", 10, 30, 1, Get("rowHeight"), Set("rowHeight"))
		p:Slider("Scale", 0.5, 2, 0.05, Get("scale"), Set("scale"), P)
		p:Slider("Background", 0, 1, 0.05, Get("alpha"), Set("alpha"), P)
	end
end

local function General(p, TM)
	p:Check("Lock both windows",
		function() return TM.db.locked end,
		function(v) TM.db.locked = v; TM:RefreshAll() end,
		"Unlocked: drag the window titles to move them, the bottom-right corner to resize.")
	p:Check("Hide Blizzard's own damage meter window",
		function() return TM.db.hideBlizzard end,
		function(v) TM.db.hideBlizzard = v; TM:ApplyBlizzard() end)
	p:Buttons({
		{ "Clear all fights", function() StaticPopup_Show("TITANMETER_RESET") end },
		{ "Re-centre windows", function() wipe(TM.db.pos); TM:RefreshAll(true) end },
	})
	p:Note("In combat the game hides exact numbers from addons. They can still be drawn, so the bars are right, "
		.. "but the threat list falls back to group order if the game won't let it be sorted.")
end

UI:Register({
	name = "TitanMeter", global = "TitanMeter",
	summary = "Damage meter on the game's own combat data, plus a threat meter.",
	ready = function(ns) return ns.db ~= nil end,
	pages = {
		{ key = "general", label = "General", build = General },
		{ key = "meter", label = "Damage meter", build = Window("meter") },
		{ key = "threat", label = "Threat meter", build = Window("threat") },
	},
})
