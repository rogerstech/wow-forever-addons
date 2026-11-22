-- TitanUI page for TitanMap.
local ADDON, UI = ...
local P = UI.Percent

local function Build(p, TM)
	local db = TM.db
	local function Vis() TM:UpdateVisibility() end
	local function Quests() TM:RefreshQuests() end
	local function Layout() TM:ApplyLayout() end
	local function Get(k) return function() return db[k] end end
	local function Set(k, after) return function(v) db[k] = v; after() end end

	p:Header("Map")
	p:Check("Show the map overlay", Get("shown"), Set("shown", Vis))
	p:Check("Hide it during combat", Get("hideInCombat"), Set("hideInCombat", Vis))
	p:Check("Hide it in dungeons and raids", Get("hideInInstance"), Set("hideInInstance", Vis))

	p:Header("Quests")
	p:Check("Only tracked quests", Get("trackedOnly"), Set("trackedOnly", Quests))
	p:Check("Quest names next to markers", Get("names"), Set("names", Quests))
	p:Check("Shade quest objective areas", Get("areas"), Set("areas", Quests))

	p:Header("Look")
	p:Slider("Width", 200, 1600, 10, Get("width"), Set("width", Layout))
	p:Slider("Map opacity", 0.05, 1, 0.05, Get("mapAlpha"), Set("mapAlpha", Layout), P)
	p:Slider("Arrow + marker opacity", 0.2, 1, 0.05, Get("pinAlpha"), Set("pinAlpha", Layout), P)

	p:Buttons({
		{ function() return TM.unlocked and "Lock" or "Unlock to move" end, function() TM:SetUnlocked(not TM.unlocked) end },
		{ "Reset position", function() SlashCmdList.TITANMAP("reset") end },
	})
	p:Note("You can also bind a key to show/hide the map: Esc > Options > Keybindings > AddOns > TitanMap.")
end

UI:Register({
	name = "TitanMap", global = "TitanMap",
	summary = "See-through map of your zone with your arrow and quest markers.",
	ready = function(ns) return ns.db ~= nil end,
	pages = { { key = "main", label = "TitanMap", build = Build } },
})
