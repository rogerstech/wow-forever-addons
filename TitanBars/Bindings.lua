-- TitanBars: key bindings and hover-to-bind mode.
-- Keys are applied as override bindings, so your normal Blizzard keybinds are left
-- untouched and come back if the addon is disabled.
local ADDON, TB = ...

local owner = CreateFrame("Frame", "TitanBarsBindingOwner")

function TB:GetButtonKeys(id, i)
	self.db.keys[id] = self.db.keys[id] or {}
	self.db.keys[id][i] = self.db.keys[id][i] or {}
	return self.db.keys[id][i]
end

-- Copies the keys bound to the Blizzard bars onto the matching TitanBars buttons.
-- Runs once per profile automatically; /tb importkeys forces it again.
-- Returns true if anything was imported.
function TB:ImportBlizzardKeys(force)
	if self.db.keysImported and not force then return false end
	if force then ClearOverrideBindings(owner) end
	local found, imported = false, {}
	for id, info in ipairs(self.BAR_INFO) do
		imported[id] = {}
		for i = 1, self.MAX_BUTTONS do
			local list = { GetBindingKey(info.binding .. i) }
			if #list > 0 then found = true end
			imported[id][i] = list
		end
	end
	-- Bindings can still be loading on the first event; try again on the next one.
	if not found and not force then return false end
	self.db.keys = imported
	self.db.keysImported = true
	if force then self:Print("Copied your Blizzard action bar keybinds onto the bars.") end
	return true
end

function TB:ApplyBindings()
	if not self.bars[1] then return end
	if InCombatLockdown() then
		self:RunOutOfCombat("bindings", function() TB:ApplyBindings() end)
		return
	end
	ClearOverrideBindings(owner)
	for id, bar in ipairs(self.bars) do
		local cfg = self.db.bars[id]
		if cfg.enabled then
			for i = 1, cfg.buttons do
				local target = bar.buttons[i].titanKey:GetName()
				for _, key in ipairs(self:GetButtonKeys(id, i)) do
					SetOverrideBindingClick(owner, false, key, target, "LeftButton")
				end
			end
		end
	end
	self:UpdateAllHotkeys()
end

function TB.UpdateHotkeyText(btn)
	if not TB.db or not btn.titanBar then return end
	local key = TB:GetButtonKeys(btn.titanBar, btn.titanIndex)[1]
	local hotkey = btn.HotKey
	if not hotkey then return end
	local text = key and GetBindingText(key, true) or ""
	if text == "" then
		hotkey:SetText(RANGE_INDICATOR)
		hotkey:Hide()
	else
		hotkey:SetSize(btn:GetWidth() - 8, 10)
		hotkey:SetText(text)
		hotkey:Show()
	end
end

function TB:UpdateAllHotkeys()
	for _, bar in ipairs(self.bars) do
		for _, btn in ipairs(bar.buttons) do TB.UpdateHotkeyText(btn) end
	end
end

---------------------------------------------------------------------------
-- Bind mode: hover a button, press a key / mouse button / wheel.
---------------------------------------------------------------------------
local IGNORED = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
	LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true,
}

local function WithModifiers(key)
	-- WoW expects modifiers in this order.
	return (IsAltKeyDown() and "ALT-" or "")
		.. (IsControlKeyDown() and "CTRL-" or "")
		.. (IsShiftKeyDown() and "SHIFT-" or "")
		.. (IsMetaKeyDown and IsMetaKeyDown() and "META-" or "")
		.. key
end

local binder = CreateFrame("Button", "TitanBarsBinder", UIParent, "BackdropTemplate")
binder:SetFrameStrata("TOOLTIP")
binder:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
binder:SetBackdropColor(0, 1, 0, 0.25)
binder:SetBackdropBorderColor(0, 1, 0, 1)
binder:EnableMouse(true)
binder:EnableMouseWheel(true)
binder:EnableKeyboard(true)
binder:RegisterForClicks("AnyUp")
binder:Hide()

local function ShowBinderTooltip()
	local btn = binder.target
	if not btn then return end
	GameTooltip:SetOwner(binder, "ANCHOR_TOP")
	GameTooltip:AddLine(("Bar %d, button %d"):format(btn.titanBar, btn.titanIndex))
	local keys = TB:GetButtonKeys(btn.titanBar, btn.titanIndex)
	if #keys == 0 then
		GameTooltip:AddLine("No key bound", 0.6, 0.6, 0.6)
	else
		for _, key in ipairs(keys) do GameTooltip:AddLine(GetBindingText(key), 1, 1, 1) end
	end
	GameTooltip:AddLine("Press a key to bind it. Esc clears.", 0, 1, 0)
	GameTooltip:Show()
end

function TB:BindKey(btn, key)
	local id, index = btn.titanBar, btn.titanIndex
	-- A key can only drive one button.
	for _, perBar in pairs(self.db.keys) do
		for _, list in pairs(perBar) do
			for n = #list, 1, -1 do
				if list[n] == key then table.remove(list, n) end
			end
		end
	end
	local was = GetBindingAction(key)
	table.insert(self:GetButtonKeys(id, index), key)
	self:ApplyBindings()
	local note = ""
	if was and was ~= "" and not was:find("^CLICK TitanBars") then
		note = " (overrides " .. (GetBindingName(was) or was) .. ")"
	end
	self:Print(("%s -> bar %d button %d%s"):format(GetBindingText(key), id, index, note))
	ShowBinderTooltip()
end

function TB:ClearKeys(btn)
	wipe(self:GetButtonKeys(btn.titanBar, btn.titanIndex))
	self:ApplyBindings()
	self:Print(("Cleared keys for bar %d button %d"):format(btn.titanBar, btn.titanIndex))
	ShowBinderTooltip()
end

binder:SetScript("OnKeyDown", function(self, key)
	if not self.target or IGNORED[key] then return end
	if key == "ESCAPE" then
		TB:ClearKeys(self.target)
	else
		TB:BindKey(self.target, WithModifiers(key))
	end
end)

binder:SetScript("OnMouseDown", function(self, button)
	if not self.target or button == "LeftButton" or button == "RightButton" then return end
	local key = button == "MiddleButton" and "BUTTON3" or button:upper()
	TB:BindKey(self.target, WithModifiers(key))
end)

binder:SetScript("OnMouseWheel", function(self, delta)
	if not self.target then return end
	TB:BindKey(self.target, WithModifiers(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
end)

binder:SetScript("OnLeave", function(self)
	self.target = nil
	self:Hide()
	GameTooltip:Hide()
end)

function TB:OnButtonEnter(btn)
	if not self.bindMode or InCombatLockdown() then return end
	binder.target = btn
	binder:ClearAllPoints()
	binder:SetAllPoints(btn)
	binder:Show()
	ShowBinderTooltip()
end

-- Small banner while bind mode is on. Esc (with nothing hovered) or Done closes it.
local banner = CreateFrame("Frame", "TitanBarsBindBanner", UIParent, "BackdropTemplate")
banner:SetSize(360, 64)
banner:SetPoint("TOP", 0, -120)
banner:SetFrameStrata("DIALOG")
banner:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
banner:SetBackdropColor(0, 0, 0, 0.8)
banner:SetBackdropBorderColor(0, 1, 0, 1)
banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
banner.text:SetPoint("TOP", 0, -10)
banner.text:SetText("Keybind mode: hover a button and press a key.\nEsc over a button clears it.")
local done = CreateFrame("Button", nil, banner, "UIPanelButtonTemplate")
done:SetSize(80, 20)
done:SetPoint("BOTTOM", 0, 6)
done:SetText("Done")
done:SetScript("OnClick", function() TB:SetBindMode(false) end)
banner:SetScript("OnHide", function() if TB.bindMode then TB:SetBindMode(false) end end)
banner:Hide()
tinsert(UISpecialFrames, "TitanBarsBindBanner")

function TB:SetBindMode(on)
	if on and InCombatLockdown() then
		self:Print("Can't bind keys in combat.")
		return
	end
	if on and self.unlocked then self:SetUnlocked(false) end
	self.bindMode = on
	if on then
		banner:Show()
	else
		binder.target = nil
		binder:Hide()
		banner:Hide()
	end
	if self.RefreshConfig then self:RefreshConfig() end
end
