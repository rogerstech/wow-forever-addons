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

	p:Header("Blessing helper (paladin)")
	local b = TT.BlessCfg and TT:BlessCfg()
	if b then
		p:Check("Show the blessing button", function() return b.enabled end,
			function(v) b.enabled = v; TT:UpdateBlessEnabled() end,
			"One button (or key) that blesses the next group member missing their blessing. Prepared between fights.")
		p:Check("Show it while solo too", function() return b.solo end,
			function(v) b.solo = v; TT:UpdateBlessEnabled() end)
		p:Slider("Re-bless when less than (seconds left)", 0, 300, 10, function() return b.refresh end,
			function(v) b.refresh = v; TT:UpdateBless() end)
		local function Options()
			local list = { { 0, "No blessing" } }
			for _, bl in ipairs(TT.BLESSINGS) do
				local name = TT.SpellName(bl.id) or bl.key
				table.insert(list, { bl.id, name .. (TT.BlessKnown(bl.id) and "" or "  |cff8a8a96(not learned)|r") })
			end
			return list
		end
		p:Choice("Everyone else / fallback", Options, function() return b.fallback end,
			function(v) b.fallback = v; TT:UpdateBless() end,
			"Used when a class's blessing isn't learned yet.")
		for _, c in ipairs(TT.BLESS_CLASSES) do
			local label = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class]) or c.class
			local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
			if col then label = ("|cff%02x%02x%02x%s|r"):format(math.floor(col.r * 255), math.floor(col.g * 255), math.floor(col.b * 255), label) end
			p:Choice(label, Options, function()
				local v = b.perClass[c.class]
				if v == nil then v = c.default end
				return v
			end, function(v) b.perClass[c.class] = v; TT:UpdateBless() end)
		end
		p:Note("Salvation is never cast on you. Bind a key: Esc > Options > Keybindings > AddOns > TitanTools.")
	end

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
