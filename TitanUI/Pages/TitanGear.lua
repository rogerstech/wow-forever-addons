-- TitanUI page for TitanGear.
local ADDON, UI = ...
local P = UI.Percent

local function Build(p, TG)
	local db = TG.db
	local function Get(k) return function() return db[k] end end
	local function Set(k) return function(v) db[k] = v; TG:Update() end end

	p:Check("Show the gear bar", Get("enabled"), Set("enabled"))
	p:Check("Lock position", Get("locked"), Set("locked"))
	p:Check("Set names under the icons", Get("names"), Set("names"))
	p:Check("Stack the buttons vertically", Get("vertical"), Set("vertical"))
	p:Slider("Button size", 20, 60, 1, Get("size"), Set("size"))
	p:Slider("Opacity", 0.2, 1, 0.05, Get("alpha"), Set("alpha"), P)
	p:Buttons({
		{ "New set from what I'm wearing", function() StaticPopup_Show("TITANGEAR_NEW") end },
		{ "Swap to next set", function() TG:EquipNext() end },
		{ "Reset position", function() db.pos = nil; TG:PlaceBar() end },
	})
	p:Header("Your sets")
	p:Note(function()
		local sets = TG:Sets()
		if #sets == 0 then return "None yet. Put on your tank gear, click \"New set\", call it Tank; then the same for Ret." end
		local lines = {}
		for i, s in ipairs(sets) do
			local key = i <= 4 and GetBindingKey("TITANGEAR_SET" .. i)
			table.insert(lines, ("%d. %s%s%s%s"):format(i, s.equipped and "|cff4fd15f" or "", s.name, s.equipped and "  (wearing)|r" or "",
				key and ("  |cff8a8a96key " .. key .. "|r") or ""))
		end
		return table.concat(lines, "\n")
	end)
	p:Note("Keys: Esc > Options > Keybindings > AddOns > TitanGear (set 1-4, or one key that swaps to the next set). "
		.. "Macros: /tgear Tank. Armour can't change in combat: a swap asked for then happens when combat ends.")
end

UI:Register({
	name = "TitanGear", global = "TitanGear",
	summary = "One-click gear sets (tank / ret) with keys and macros.",
	ready = function(ns) return ns.db ~= nil end,
	pages = { { key = "main", label = "TitanGear", build = Build } },
})
