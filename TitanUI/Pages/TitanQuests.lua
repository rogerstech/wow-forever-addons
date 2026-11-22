-- TitanUI page for TitanQuests.
local ADDON, UI = ...
local P = UI.Percent

local function Build(p, TQ)
	local db = TQ.db
	local function Refresh() TQ:Refresh() end
	local function Layout() TQ:ApplyLayout() end
	local function Get(k) return function() return db[k] end end
	local function Set(k, after) return function(v) db[k] = v; if after then after() end end end

	p:Header("Show")
	p:Check("Every quest in the log, not just tracked", Get("showAll"), function(v) db.showAll = v; TQ.offset = 0; Refresh() end)
	p:Check("Group quests under their zone", Get("zones"), Set("zones", Refresh))
	p:Check("Quest level before the name", Get("levels"), Set("levels", Refresh))
	p:Check("Hide objectives you've finished", Get("hideDone"), Set("hideDone", Refresh))
	p:Check("Quest item buttons", Get("items"), Set("items", Refresh))
	p:Check("Hide Blizzard's quest tracker", Get("hideBlizzard"), Set("hideBlizzard", function() TQ:UpdateBlizzard() end))

	p:Header("Minimize")
	p:Check("Minimized", Get("minimized"), function(v) TQ:SetMinimized(v) end)
	p:Check("Minimize in dungeons and raids", Get("dungeonMinimize"), Set("dungeonMinimize"))
	p:Check("Minimize during combat", Get("combatMinimize"), function(v)
		db.combatMinimize = v
		TQ:SyncItemHolder()
		TQ:ApplyMinimized()
	end)
	p:Check("Lock position and width", Get("locked"), Set("locked"))

	p:Header("Size")
	p:Slider("Width", 180, 500, 5, Get("width"), Set("width", Layout))
	p:Slider("Max height", 150, 900, 10, Get("maxHeight"), Set("maxHeight", Refresh))
	p:Slider("Scale", 0.5, 2, 0.05, Get("scale"), Set("scale", Layout), P)
	p:Slider("Text size", 9, 18, 1, Get("fontSize"), Set("fontSize", Layout))
	p:Slider("Background", 0, 1, 0.05, Get("alpha"), Set("alpha", Layout), P)

	p:Buttons({
		{ "Fold all", function() TQ:SetAllFolded(true) end },
		{ "Unfold all", function() TQ:SetAllFolded(false) end },
		{ "Reset position", function() SlashCmdList.TITANQUESTS("reset") end },
	})
end

UI:Register({
	name = "TitanQuests", global = "TitanQuests",
	summary = "Quest tracker that replaces Blizzard's, with one-click minimize.",
	ready = function(ns) return ns.db ~= nil end,
	pages = { { key = "main", label = "TitanQuests", build = Build } },
})
