-- TitanUI page for TitanTools.
local ADDON, UI = ...

local function Build(p, TT)
	local db = TT.db
	p:Header("Buff reminder")
	p:Check("Show missing buffs (out of combat)",
		function() return db.reminder.enabled end, function(v) db.reminder.enabled = v; TT:UpdateReminders() end)
	p:Check("Also warn when a buff has under 1 min left",
		function() return db.reminder.lowTime end, function(v) db.reminder.lowTime = v; TT:UpdateReminders() end)
	p:Check("Warn in a group when not in tank form (Bear, Righteous Fury)",
		function() return db.reminder.bearWarning end, function(v) db.reminder.bearWarning = v; TT:UpdateReminders() end)

	p:Header("Target of target")
	p:Check("Show target-of-target frame",
		function() return db.tot.enabled end, function(v) db.tot.enabled = v; TT:UpdateToTEnabled() end)

	p:Header("Nameplate aggro colours")
	p:Check("Green = mob on you, red = on someone else",
		function() return db.aggro.enabled end, function(v) db.aggro.enabled = v; TT:UpdateAggro() end)
	p:Check("Only while in a group",
		function() return db.aggro.groupOnly end, function(v) db.aggro.groupOnly = v; TT:UpdateAggro() end)

	p:Header("Vendors")
	p:Check("Repair all gear automatically",
		function() return db.vendor.repair end, function(v) db.vendor.repair = v end)
	p:Check("Sell grey (junk) items automatically",
		function() return db.vendor.junk end, function(v) db.vendor.junk = v end)

	p:Header("Quests")
	p:Check("Accept and turn in quests (hold Shift to skip)",
		function() return db.quest.enabled end, function(v) db.quest.enabled = v end)

	p:Header("Move")
	p:Buttons({
		{ function() return TT.unlocked and "Lock frames" or "Unlock frames" end,
			function() TT:SetUnlocked(not TT.unlocked) end,
			"Unlocked: drag the green boxes (reminder, target of target), mouse wheel to resize, right-click to reset." },
	})
end

UI:Register({
	name = "TitanTools", global = "TitanTools",
	summary = "Buff and tank-form reminders, target of target, aggro colours, repair/junk, quest helper.",
	ready = function(ns) return ns.db ~= nil end,
	pages = { { key = "main", label = "TitanTools", build = Build } },
})
