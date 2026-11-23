-- TitanFish: fishing helper.
--   * Double-right-click the water to cast (only while a fishing pole is equipped).
--   * Louder splash: while you fish, sound effects go up and music/ambience go down;
--     everything goes back when you stop.
--   * One-click lure button (picks the best lure you can use), with the time left.
--   * Pole / weapons swap button.
--   * Your skill, the zone's "no get-aways" number, your next step, and a catch log.
-- Casting and lures are secure buttons, so they're set up out of combat only.
local ADDON, TF = ...
_G.TitanFish = TF

BINDING_HEADER_TITANFISH = "TitanFish"
_G["BINDING_NAME_CLICK TitanFishCast:LeftButton"] = "Cast Fishing"
_G["BINDING_NAME_CLICK TitanFishLure:LeftButton"] = "Put the best lure on your pole"
BINDING_NAME_TITANFISH_TOGGLE = "Show / hide the TitanFish window"

local DEFAULTS = {
	doubleClick = true,
	loudSplash = true,
	autoLoot = true,
	window = "pole",     -- "pole" (while a pole is equipped), "always", "never"
	scale = 1,
	locked = false,
	pos = nil,
	saved = nil,         -- sound/loot settings to restore (kept across a crash)
	gear = {},           -- [character] = { main = link, off = link } to swap back to
	catches = {},        -- [character] = { [zone] = { [itemID] = count } }
}

local FISHING_SKILL_LINE = 356
local FALLBACK_SPELL = 7620
local POLE_CLASS, POLE_SUB = 2, 20 -- weapon / fishing pole

local win, castBtn, lureBtn
local pending = false
local fishingUntil = 0       -- GetTime() until which we count as "fishing" (sound boost)
local session = { total = 0 }

function TF:Print(msg) print("|cff33ccffTitanFish|r: " .. msg) end

local function Merge(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then dst[k] = type(v) == "table" and {} or v end
	end
end

local function CharKey() return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?") end

---------------------------------------------------------------------------
-- Skill, spell, pole
function TF:Profession()
	local list = { GetProfessions() }
	for i = 1, 8 do
		local idx = list[i]
		if idx then
			local name, icon, rank, max, _, offset, skillLine, mod = GetProfessionInfo(idx)
			if skillLine == FISHING_SKILL_LINE then
				return { name = name, icon = icon, rank = rank or 0, max = max or 0, mod = mod or 0, offset = offset }
			end
		end
	end
end

-- The spell that actually casts the line. On Forever the first spell under Fishing in the
-- spellbook opens the Fishing profession window instead, so look for a cast spell by ID:
-- best rank first (Artisan, Expert, Journeyman, Apprentice), then the modern single spell.
local CAST_IDS = { 18248, 7732, 7731, 7620, 131474 }
local CAST_SET = {}
for _, id in ipairs(CAST_IDS) do CAST_SET[id] = true end
TF.CAST_SET = CAST_SET

local function Known(id)
	if IsPlayerSpell and IsPlayerSpell(id) then return true end
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		local ok, k = pcall(C_SpellBook.IsSpellKnown, id)
		if ok and k then return true end
	end
	return IsSpellKnown and IsSpellKnown(id) or false
end

function TF:SpellName()
	for _, id in ipairs(CAST_IDS) do
		if Known(id) then
			return (C_Spell.GetSpellName(id) or "Fishing"), id
		end
	end
	return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(FALLBACK_SPELL) or "Fishing", FALLBACK_SPELL
end

function TF:PoleEquipped()
	local id = GetInventoryItemID("player", 16)
	if not id then return false end
	local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
	return classID == POLE_CLASS and subID == POLE_SUB
end

-- Best fishing pole in your bags (highest item level as a stand-in for bonus).
local function FindPole()
	local best, bestLevel
	for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4) do
		for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local id = info and info.itemID
			if id then
				local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
				if classID == POLE_CLASS and subID == POLE_SUB then
					local lvl = (C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(info.hyperlink)) or 1
					if not best or lvl > bestLevel then best, bestLevel = info.hyperlink, lvl end
				end
			end
		end
	end
	return best
end

function TF:SwapPole()
	if InCombatLockdown() then return self:Print("not in combat.") end
	local key = CharKey()
	local g = self.db.gear[key] or {}
	self.db.gear[key] = g
	if self:PoleEquipped() then
		if g.main then C_Item.EquipItemByName(g.main) end
		if g.off then C_Item.EquipItemByName(g.off, 17) end
		if not g.main then self:Print("no weapons remembered: put them on by hand once.") end
	else
		local pole = FindPole()
		if not pole then return self:Print("no fishing pole in your bags.") end
		g.main = GetInventoryItemLink("player", 16)
		g.off = GetInventoryItemLink("player", 17)
		C_Item.EquipItemByName(pole, 16)
	end
end

---------------------------------------------------------------------------
-- Lures
function TF:BestLure()
	local p = self:Profession()
	local skill = p and p.rank or 0
	for _, l in ipairs(self.LURES) do
		if skill >= l.min and (C_Item.GetItemCount(l.id) or 0) > 0 then return l end
	end
end

local function LureTimeLeft()
	local has, ms = GetWeaponEnchantInfo()
	if has and ms then return ms / 1000 end
end

---------------------------------------------------------------------------
-- Sound and auto-loot while fishing
local SOUND = { Sound_SFXVolume = "1.0", Sound_MusicVolume = "0", Sound_AmbienceVolume = "0", Sound_EnableSFX = "1" }

local function Boost()
	local db = TF.db
	if db.saved then return end
	db.saved = {}
	if db.loudSplash then
		for cvar, v in pairs(SOUND) do
			db.saved[cvar] = C_CVar.GetCVar(cvar)
			C_CVar.SetCVar(cvar, v)
		end
	end
	if db.autoLoot then
		db.saved.autoLootDefault = C_CVar.GetCVar("autoLootDefault")
		C_CVar.SetCVar("autoLootDefault", "1")
	end
end

local function Restore()
	local db = TF.db
	if not db.saved then return end
	for cvar, v in pairs(db.saved) do
		if v ~= nil then C_CVar.SetCVar(cvar, v) end
	end
	db.saved = nil
end

---------------------------------------------------------------------------
-- Double-right-click to cast. On the second right-press within 0.4 s, Right Mouse is
-- bound to the cast button for that one click, then given back.
local lastRight = 0
local armed = false

local function Disarm()
	if armed and not InCombatLockdown() then
		ClearOverrideBindings(castBtn)
		armed = false
	end
end

local function OnWorldMouseDown(_, button)
	if button ~= "RightButton" or not TF.db.doubleClick or InCombatLockdown() then return end
	if not TF:PoleEquipped() then return end
	local now = GetTime()
	if now - lastRight < 0.4 then
		lastRight = 0
		SetOverrideBindingClick(castBtn, true, "BUTTON2", "TitanFishCast")
		armed = true
		C_Timer.After(1, Disarm)  -- in case the click never lands
	else
		lastRight = now
	end
end

---------------------------------------------------------------------------
-- Catch log
local function OnLoot()
	if not (IsFishingLoot and IsFishingLoot()) then return end
	fishingUntil = GetTime() + 30
	local key = CharKey()
	local zone = GetRealZoneText() or "?"
	TF.db.catches[key] = TF.db.catches[key] or {}
	local z = TF.db.catches[key][zone] or {}
	TF.db.catches[key][zone] = z
	for i = 1, GetNumLootItems() do
		local link = GetLootSlotLink(i)
		local _, _, qty = GetLootSlotInfo(i)
		local id = link and C_Item.GetItemInfoInstant(link)
		if id then
			z[id] = (z[id] or 0) + (qty or 1)
			session[id] = (session[id] or 0) + (qty or 1)
			session.total = session.total + (qty or 1)
		end
	end
	TF:Update()
end

---------------------------------------------------------------------------
-- Window
local function SavePos()
	local s = win:GetEffectiveScale()
	TF.db.pos = { x = win:GetLeft() * s, y = win:GetTop() * s }
end

function TF:PlaceWindow()
	if not win then return end
	win:SetScale(self.db.scale)
	win:ClearAllPoints()
	local p = self.db.pos
	if p then
		local s = win:GetEffectiveScale()
		win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x / s, p.y / s)
	else
		win:SetPoint("CENTER", UIParent, "CENTER", 320, 120)
	end
end

local function ZoneLine(effective)
	local zone = GetRealZoneText() or ""
	local need = TF.ZONE_SKILL[zone]
	if not need then return zone ~= "" and ("|cff8a8a96" .. zone .. "|r") or "" end
	local col = effective >= need and "|cff4fd15f" or (effective >= need - 50 and "|cffffd24a" or "|cffff5a4a")
	return ("%s: %sno get-aways at %d|r"):format(zone, col, need)
end

local function TopCatches()
	local zone = GetRealZoneText() or "?"
	local z = (TF.db.catches[CharKey()] or {})[zone] or {}
	local list = {}
	for id, n in pairs(z) do table.insert(list, { id = id, n = n }) end
	table.sort(list, function(a, b) return a.n > b.n end)
	local out = {}
	for i = 1, math.min(3, #list) do
		local name = C_Item.GetItemNameByID(list[i].id) or ("item " .. list[i].id)
		table.insert(out, ("%s x%d"):format(name, list[i].n))
	end
	return #out > 0 and table.concat(out, ", ") or "nothing yet"
end

function TF:Update()
	if not win then return end
	local p = self:Profession()
	if not p then
		win.skill:SetValue(0)
		win.skillText:SetText("No Fishing yet: see a fishing trainer")
		win.zone:SetText("")
		win.next:SetText("")
	else
		local eff = p.rank + p.mod
		win.skill:SetMinMaxValues(0, math.max(1, p.max))
		win.skill:SetValue(p.rank)
		win.skillText:SetText(("Fishing %d / %d%s"):format(p.rank, p.max, p.mod > 0 and ("  |cff4fd15f(+" .. p.mod .. ")|r") or ""))
		win.zone:SetText(ZoneLine(eff))
		win.next:SetText("|cff8a8a96Next:|r " .. self.NextStep(p.rank, p.max))
	end
	local left = LureTimeLeft()
	local lure = self:BestLure()
	if left then
		win.lureText:SetText(("Lure on: |cff4fd15f%d:%02d|r"):format(math.floor(left / 60), math.floor(left % 60)))
	elseif lure then
		win.lureText:SetText("|cffffd24aNo lure|r: click to add +" .. lure.bonus)
	else
		win.lureText:SetText("|cff8a8a96No lure in your bags|r")
	end
	lureBtn.icon:SetTexture(lure and C_Item.GetItemIconByID(lure.id) or 134400)
	lureBtn.icon:SetDesaturated(not lure)
	win.catch:SetText(("|cff8a8a96This trip:|r %d   |cff8a8a96Here:|r %s"):format(session.total, TopCatches()))
	win.poleBtn:SetText(self:PoleEquipped() and "Weapons" or "Fishing pole")
	win.soundBtn:SetText(self.db.loudSplash and "Loud splash: on" or "Loud splash: off")
	self:UpdateSecure()
end

-- Point the cast and lure buttons at the right spell / item (out of combat only).
function TF:UpdateSecure()
	if InCombatLockdown() then pending = true return end
	pending = false
	castBtn:SetAttribute("type", "spell")
	castBtn:SetAttribute("spell", select(2, self:SpellName()))
	local lure = self:BestLure()
	if lure then
		lureBtn:SetAttribute("type", "item")
		lureBtn:SetAttribute("item", "item:" .. lure.id)
		lureBtn:SetAttribute("target-slot", 16)
	else
		lureBtn:SetAttribute("type", nil)
	end
	local mode = self.db.window
	local show = mode == "always" or (mode == "pole" and self:PoleEquipped())
	if self.forceShow ~= nil then show = self.forceShow end
	win:SetShown(show)
end

function TF:ToggleWindow()
	if InCombatLockdown() then return self:Print("not in combat.") end
	self.forceShow = not win:IsShown()
	self:Update()
end

local function Button(parent, text, w)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, 20)
	b:SetText(text)
	return b
end

function TF:CreateWindow()
	win = CreateFrame("Frame", "TitanFishFrame", UIParent, "BackdropTemplate")
	win:SetSize(270, 132)
	win:SetFrameStrata("MEDIUM")
	win:SetMovable(true)
	win:SetClampedToScreen(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	win:SetBackdropColor(0.05, 0.05, 0.07, 0.88)
	win:SetBackdropBorderColor(0, 0, 0, 1)
	win:SetScript("OnDragStart", function() if not TF.db.locked then win:StartMoving() end end)
	win:SetScript("OnDragStop", function() win:StopMovingOrSizing(); SavePos() end)

	local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 8, -6)
	title:SetText("TitanFish")
	local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
	close:SetSize(20, 20)
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function()
		if InCombatLockdown() then return end
		TF.forceShow = false
		TF:Update()
	end)

	win.skill = CreateFrame("StatusBar", nil, win)
	win.skill:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	win.skill:SetStatusBarColor(0.2, 0.55, 0.95)
	win.skill:SetPoint("TOPLEFT", 8, -26)
	win.skill:SetPoint("TOPRIGHT", -8, -26)
	win.skill:SetHeight(16)
	local bg = win.skill:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.6)
	win.skillText = win.skill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.skillText:SetPoint("CENTER")

	win.zone = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.zone:SetPoint("TOPLEFT", win.skill, "BOTTOMLEFT", 0, -4)
	win.next = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.next:SetPoint("TOPLEFT", win.zone, "BOTTOMLEFT", 0, -3)

	-- Lure button (secure: using an item on your pole is a protected action).
	lureBtn = CreateFrame("Button", "TitanFishLure", win, "SecureActionButtonTemplate")
	lureBtn:SetSize(26, 26)
	-- Protected frames may only anchor to frames, never to font strings or
	-- textures, so this sits on the window itself (just under win.next).
	lureBtn:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -79)
	lureBtn:RegisterForClicks("AnyUp", "AnyDown")
	lureBtn:SetAttribute("useOnKeyDown", false)
	lureBtn.icon = lureBtn:CreateTexture(nil, "ARTWORK")
	lureBtn.icon:SetAllPoints()
	lureBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	lureBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	lureBtn:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		local l = TF:BestLure()
		if l then GameTooltip:SetItemByID(l.id) else GameTooltip:SetText("No lure you can use in your bags") end
		GameTooltip:AddLine("Click to put it on your fishing pole.", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	lureBtn:HookScript("OnLeave", GameTooltip_Hide)
	win.lureText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.lureText:SetPoint("LEFT", lureBtn, "RIGHT", 6, 0)

	win.catch = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.catch:SetPoint("TOPLEFT", lureBtn, "BOTTOMLEFT", 0, -6)
	win.catch:SetPoint("RIGHT", -8, 0)
	win.catch:SetJustifyH("LEFT")
	win.catch:SetWordWrap(false)

	win.poleBtn = Button(win, "Fishing pole", 110)
	win.poleBtn:SetPoint("BOTTOMLEFT", 8, 6)
	win.poleBtn:SetScript("OnClick", function() TF:SwapPole() end)
	win.soundBtn = Button(win, "Loud splash: on", 130)
	win.soundBtn:SetPoint("BOTTOMRIGHT", -8, 6)
	win.soundBtn:SetScript("OnClick", function()
		Restore()
		TF.db.loudSplash = not TF.db.loudSplash
		TF:Update()
	end)

	-- Invisible cast button that Right Mouse is bound to on a double-click.
	castBtn = CreateFrame("Button", "TitanFishCast", UIParent, "SecureActionButtonTemplate")
	castBtn:SetSize(1, 1)
	castBtn:SetPoint("TOPLEFT")
	castBtn:RegisterForClicks("AnyUp", "AnyDown")
	castBtn:SetAttribute("useOnKeyDown", false)
	castBtn:HookScript("PostClick", function()
		fishingUntil = GetTime() + 30
		Boost()
		C_Timer.After(0.1, Disarm)
	end)

	win:Hide()
	self:PlaceWindow()
end

---------------------------------------------------------------------------
SLASH_TITANFISH1 = "/tfish"
SLASH_TITANFISH2 = "/titanfish"
SlashCmdList.TITANFISH = function(msg)
	local cmd = strtrim(msg or ""):lower()
	if cmd == "" then
		TF:ToggleWindow()
	elseif cmd == "spell" then
		local n, id = TF:SpellName()
		TF:Print(("casting with %s (spell %s)"):format(tostring(n), tostring(id)))
		for _, cid in ipairs(CAST_IDS) do print(("   %d %s known=%s"):format(cid, tostring(C_Spell.GetSpellName(cid)), tostring(Known(cid)))) end
	elseif cmd == "pole" then
		TF:SwapPole()
	elseif cmd == "reset" then
		TF.db.pos = nil
		TF:PlaceWindow()
	elseif cmd == "clear" then
		TF.db.catches[CharKey()] = {}
		session = { total = 0 }
		TF:Update()
		TF:Print("catch log cleared.")
	else
		TF:Print("/tfish - show/hide the window   /tfish pole - swap pole and weapons")
		print("  /tfish clear - clear this character's catch log   /tfish reset - window position   /tfish spell - which cast spell is used")
		print("  Double-right-click the water to cast while a pole is equipped. Settings: /tui fish")
	end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_EQUIPMENT_CHANGED", "SKILL_LINES_CHANGED",
	"ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "BAG_UPDATE_DELAYED", "LOOT_OPENED", "PLAYER_REGEN_ENABLED",
	"PLAYER_REGEN_DISABLED", "UNIT_INVENTORY_CHANGED", "UNIT_SPELLCAST_CHANNEL_START" }) do
	pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, a1, _, a3)
	if event == "ADDON_LOADED" then
		if a1 == ADDON then
			TitanFishDB = TitanFishDB or {}
			Merge(TitanFishDB, DEFAULTS)
			TF.db = TitanFishDB
		end
		return
	end
	if not TF.db then return end
	if event == "PLAYER_LOGIN" then
		-- Settings left boosted by a crash or disconnect go back first.
		Restore()
		TF:CreateWindow()
		WorldFrame:HookScript("OnMouseDown", OnWorldMouseDown)
		-- Lure timer, and "stopped fishing" check for the sound.
		C_Timer.NewTicker(1, function()
			if TF.db.saved and (GetTime() > fishingUntil or not TF:PoleEquipped()) then Restore() end
			if win:IsShown() then TF:Update() end
		end)
		TF:Update()
	elseif event == "PLAYER_LOGOUT" then
		Restore()
	elseif event == "LOOT_OPENED" then
		OnLoot()
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		if a1 == "player" and CAST_SET[a3] then
			fishingUntil = GetTime() + 30
			Boost()
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		Disarm()
	elseif event == "PLAYER_REGEN_ENABLED" then
		Disarm()
		if pending then TF:Update() end
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		if not TF:PoleEquipped() then
			Restore()
			TF.forceShow = nil
		end
		TF:Update()
	else
		TF:Update()
	end
end)
