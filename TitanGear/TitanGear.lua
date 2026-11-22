-- TitanGear: one-click gear sets.
--
-- Uses the game's own equipment sets (C_EquipmentSet), so sets are saved by the server
-- and work on every computer. A small movable bar shows one button per set: click to put
-- it on, right-click to save your current gear into it or delete it, "+" to make a new
-- set from what you're wearing. Armour can't be changed in combat: a swap asked for in
-- combat happens the moment combat ends.
local ADDON, TG = ...
_G.TitanGear = TG

BINDING_HEADER_TITANGEAR = "TitanGear"
BINDING_NAME_TITANGEAR_SET1 = "Put on gear set 1"
BINDING_NAME_TITANGEAR_SET2 = "Put on gear set 2"
BINDING_NAME_TITANGEAR_SET3 = "Put on gear set 3"
BINDING_NAME_TITANGEAR_SET4 = "Put on gear set 4"
BINDING_NAME_TITANGEAR_NEXT = "Swap to the next gear set"

local DEFAULTS = {
	enabled = true,
	size = 34,
	names = true,      -- set names under the icons
	vertical = false,
	locked = false,
	alpha = 1,
	pos = nil,         -- { x, y } centre in screen pixels
}

local ES = C_EquipmentSet
local bar, plus
local buttons = {}
local queuedSet

function TG:Print(msg)
	print("|cff33ccffTitanGear|r: " .. msg)
end

local function Merge(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then dst[k] = v end
	end
end

function TG:Available()
	return ES and ES.GetEquipmentSetIDs and (not ES.CanUseEquipmentSets or ES.CanUseEquipmentSets())
end

-- Sets in the game's order: { {id, name, icon, equipped, missing}, ... }
function TG:Sets()
	local out = {}
	if not self:Available() then return out end
	for _, id in ipairs(ES.GetEquipmentSetIDs() or {}) do
		local name, icon, setID, isEquipped, numItems, numEquipped, numInInventory, numLost = ES.GetEquipmentSetInfo(id)
		if name then
			table.insert(out, { id = setID or id, name = name, icon = icon, equipped = isEquipped, missing = numLost or 0 })
		end
	end
	return out
end

function TG:Equip(id)
	if not self:Available() or not id then return end
	if InCombatLockdown() then
		queuedSet = id
		local name = ES.GetEquipmentSetInfo(id)
		self:Print("in combat: " .. (name or "set") .. " goes on when combat ends.")
		self:Update()
		return
	end
	queuedSet = nil
	ES.UseEquipmentSet(id)
end

function TG:EquipIndex(n)
	local s = self:Sets()[n]
	if s then self:Equip(s.id) else self:Print("there's no gear set " .. n .. " yet.") end
end

-- Next set after the one you're wearing (handy with one key for tank <-> ret).
function TG:EquipNext()
	local sets = self:Sets()
	if #sets == 0 then return self:Print("no gear sets yet: click + on the gear bar.") end
	local cur = 0
	for i, s in ipairs(sets) do if s.equipped then cur = i end end
	self:Equip(sets[cur % #sets + 1].id)
end

local function CurrentIcon()
	return GetInventoryItemTexture("player", 16) or GetInventoryItemTexture("player", 5) or 132627
end

function TG:NewSet(name)
	name = strtrim(name or "")
	if name == "" then return end
	if ES.GetEquipmentSetID and ES.GetEquipmentSetID(name) then
		return self:Print("there's already a set called " .. name .. ".")
	end
	ES.CreateEquipmentSet(name, CurrentIcon())
	self:Print("saved what you're wearing as " .. name .. ".")
end

function TG:SaveSet(id)
	ES.SaveEquipmentSet(id, CurrentIcon())
	self:Print("saved what you're wearing into " .. (ES.GetEquipmentSetInfo(id) or "the set") .. ".")
end

StaticPopupDialogs["TITANGEAR_NEW"] = {
	text = "Name for the new gear set (it saves what you're wearing now):",
	button1 = SAVE or "Save",
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 16,
	OnAccept = function(self)
		local box = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
		TG:NewSet(box and box:GetText())
	end,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent()
		TG:NewSet(self:GetText())
		parent:Hide()
	end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

StaticPopupDialogs["TITANGEAR_DELETE"] = {
	text = "Delete the gear set %s? (The gear itself stays in your bags.)",
	button1 = DELETE or "Delete",
	button2 = CANCEL,
	OnAccept = function(_, id) ES.DeleteEquipmentSet(id) end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

---------------------------------------------------------------------------
-- The bar
local function SavePos()
	local s = bar:GetEffectiveScale()
	local x, y = bar:GetCenter()
	TG.db.pos = { x = x * s, y = y * s }
end

function TG:PlaceBar()
	if not bar then return end
	bar:ClearAllPoints()
	local p = self.db.pos
	if p then
		local s = bar:GetEffectiveScale()
		bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x / s, p.y / s)
	else
		bar:SetPoint("CENTER", UIParent, "CENTER", -260, -200)
	end
end

local function SetMenu(btn)
	local s = btn.set
	if not s then return end
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(btn, function(_, root)
			root:CreateTitle(s.name)
			root:CreateButton("Put it on", function() TG:Equip(s.id) end)
			root:CreateButton("Save what I'm wearing into this set", function() TG:SaveSet(s.id) end)
			root:CreateButton("|cffff5555Delete this set|r", function()
				local d = StaticPopup_Show("TITANGEAR_DELETE", s.name)
				if d then d.data = s.id end
			end)
		end)
	else
		TG:SaveSet(s.id)
	end
end

local function MakeButton(i)
	local b = CreateFrame("Button", nil, bar, "BackdropTemplate")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 2, -2)
	b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
	b.key = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
	b.key:SetPoint("TOPRIGHT", -3, -3)
	b:SetScript("OnClick", function(self, button)
		if button == "RightButton" then SetMenu(self) else TG:Equip(self.set.id) end
	end)
	b:SetScript("OnEnter", function(self)
		local s = self.set
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if GameTooltip.SetEquipmentSet and pcall(GameTooltip.SetEquipmentSet, GameTooltip, s.id) then
			-- the game's own set tooltip
		else
			GameTooltip:SetText(s.name)
		end
		if s.equipped then GameTooltip:AddLine("Wearing it now", 0.3, 0.85, 0.3) end
		if s.missing > 0 then GameTooltip:AddLine(s.missing .. " item(s) not found in your bags", 1, 0.35, 0.35) end
		GameTooltip:AddLine("Click: put it on.  Right-click: save / delete.", 0.7, 0.7, 0.75)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	buttons[i] = b
	return b
end

function TG:Update()
	if not bar then return end
	local db = self.db
	bar:SetShown(db.enabled and self:Available())
	if not bar:IsShown() then return end
	bar:SetAlpha(db.alpha)
	local sets = self:Sets()
	local size, gap = db.size, 6
	local step = size + gap + ((db.names and not db.vertical) and 0 or 0)
	local labelH = db.names and 14 or 0
	for i, s in ipairs(sets) do
		local b = buttons[i] or MakeButton(i)
		b.set = s
		b:SetSize(size, size)
		b:ClearAllPoints()
		if db.vertical then
			b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * (size + gap + labelH))
		else
			b:SetPoint("TOPLEFT", 6 + (i - 1) * (math.max(size, db.names and 60 or 0) + gap), -6)
		end
		b.icon:SetTexture(s.icon or 132627)
		b.icon:SetDesaturated(s.missing > 0)
		if queuedSet == s.id then
			b:SetBackdropBorderColor(1, 0.8, 0.2, 1)
		elseif s.equipped then
			b:SetBackdropBorderColor(0.3, 0.9, 0.3, 1)
		else
			b:SetBackdropBorderColor(0, 0, 0, 1)
		end
		b.label:SetShown(db.names)
		b.label:SetText((s.equipped and "|cff4fd15f" or "") .. s.name)
		b.label:SetWidth(math.max(size, 60))
		b.key:SetText(i <= 4 and (GetBindingKey("TITANGEAR_SET" .. i) or "") or "")
		b:Show()
	end
	for i = #sets + 1, #buttons do buttons[i]:Hide() end

	local n = #sets
	plus:SetSize(math.floor(size * 0.6), math.floor(size * 0.6))
	plus:ClearAllPoints()
	local cell = math.max(size, db.names and 60 or 0) + gap
	if db.vertical then
		plus:SetPoint("TOP", bar, "TOPLEFT", 6 + size / 2, -6 - n * (size + gap + labelH))
		bar:SetSize(size + 12, n * (size + gap + labelH) + plus:GetHeight() + 12)
	else
		plus:SetPoint("LEFT", bar, "TOPLEFT", 6 + n * cell + (n == 0 and 0 or 0), -6 - size / 2)
		bar:SetSize(n * cell + plus:GetWidth() + 12, size + labelH + 12)
	end
	bar.title:SetShown(not db.locked)
end

function TG:CreateBar()
	bar = CreateFrame("Frame", "TitanGearBar", UIParent, "BackdropTemplate")
	bar:SetFrameStrata("MEDIUM")
	bar:SetMovable(true)
	bar:SetClampedToScreen(true)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	bar:SetBackdropColor(0.05, 0.05, 0.07, 0.6)
	bar:SetBackdropBorderColor(0, 0, 0, 0.8)
	bar:SetScript("OnDragStart", function() if not TG.db.locked then bar:StartMoving() end end)
	bar:SetScript("OnDragStop", function() bar:StopMovingOrSizing(); SavePos(); TG:PlaceBar() end)
	bar.title = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	bar.title:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 2, 2)
	bar.title:SetText("Gear (drag to move)")

	plus = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
	plus:SetText("+")
	plus:SetScript("OnClick", function()
		if InCombatLockdown() then return TG:Print("can't save a set in combat.") end
		StaticPopup_Show("TITANGEAR_NEW")
	end)
	plus:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("New gear set")
		GameTooltip:AddLine("Saves everything you're wearing now under a name (e.g. Tank, Ret).", 0.85, 0.85, 0.85, true)
		GameTooltip:Show()
	end)
	plus:SetScript("OnLeave", GameTooltip_Hide)

	self:PlaceBar()
	self:Update()
end

---------------------------------------------------------------------------
SLASH_TITANGEAR1 = "/tgear"
SLASH_TITANGEAR2 = "/titangear"
SlashCmdList.TITANGEAR = function(msg)
	local cmd, arg = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "new" and arg ~= "" then
		TG:NewSet(arg)
	elseif cmd == "next" then
		TG:EquipNext()
	elseif cmd == "show" or cmd == "hide" then
		TG.db.enabled = (cmd == "show"); TG:Update()
	elseif cmd == "reset" then
		TG.db.pos = nil; TG:PlaceBar()
	elseif cmd ~= "" then
		-- /tgear Tank: put on the set with that name
		for _, s in ipairs(TG:Sets()) do
			if s.name:lower() == strtrim(msg):lower() then return TG:Equip(s.id) end
		end
		TG:Print("no set called " .. msg .. ".")
	else
		TG:Print("/tgear <set name> - put on a set (works in macros)")
		print("  /tgear next - swap to the next set   /tgear new <name> - save what you're wearing")
		print("  /tgear show | hide - the gear bar   /tgear reset - bar back to its first spot")
		print("  Keys: Esc > Options > Keybindings > AddOns > TitanGear. Settings: /tui gear")
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
for _, e in ipairs({ "EQUIPMENT_SETS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED",
	"EQUIPMENT_SWAP_FINISHED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UPDATE_BINDINGS" }) do
	pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, a2)
	if event == "ADDON_LOADED" then
		if a1 == ADDON then
			TitanGearDB = TitanGearDB or {}
			Merge(TitanGearDB, DEFAULTS)
			TG.db = TitanGearDB
		end
		return
	elseif event == "PLAYER_LOGIN" then
		TG:CreateBar()
		if not TG:Available() then TG:Print("this game version has no equipment sets, so TitanGear is off.") end
		return
	end
	if not bar then return end
	if event == "PLAYER_REGEN_ENABLED" and queuedSet then
		TG:Equip(queuedSet)
	elseif event == "EQUIPMENT_SWAP_FINISHED" and a1 == false then
		TG:Print("couldn't put that whole set on (missing items, or something blocked it).")
	end
	TG:Update()
end)
