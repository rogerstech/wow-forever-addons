-- TitanTools: blessing helper for paladins.
--
-- One button (and a key you can bind) that casts the right blessing on the next group
-- member who is missing it or whose blessing is about to run out. Which blessing goes on
-- which class is a setting (Might for melee, Wisdom for casters...).
--
-- Blizzard rule: what a secure button casts, and on whom, can only be changed out of
-- combat. So the button is prepared between fights; in combat it shows "In combat".
local ADDON, TT = ...

TT.BLESSINGS = {
	{ id = 19740, key = "might" },
	{ id = 19742, key = "wisdom" },
	{ id = 20217, key = "kings" },
	{ id = 19977, key = "light" },
	{ id = 20911, key = "sanctuary" },
	{ id = 1038,  key = "salvation" },
}

-- Starting suggestions, per class. 0 = don't bless. Only used if you know the spell;
-- otherwise the "everyone else" blessing is used.
TT.BLESS_CLASSES = {
	{ class = "WARRIOR", default = 19740 }, { class = "ROGUE", default = 19740 },
	{ class = "HUNTER", default = 19740 },  { class = "PALADIN", default = 20217 },
	{ class = "SHAMAN", default = 19742 },  { class = "DRUID", default = 20217 },
	{ class = "PRIEST", default = 19742 },  { class = "MAGE", default = 19742 },
	{ class = "WARLOCK", default = 19742 },
}

local SALVATION = 1038
local f
local queued = false

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end
TT.SpellName = TT.SpellName or SpellName

local function Known(id)
	if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) then return true end
	return IsPlayerSpell and IsPlayerSpell(id) or false
end
TT.BlessKnown = Known

local function Secret(v) return issecretvalue and issecretvalue(v) or false end

local function IsMe(u)
	if u == "player" then return true end
	local ok, r = pcall(UnitIsUnit, u, "player")
	return ok and not Secret(r) and r or false
end

function TT:BlessCfg()
	local b = self.db.bless
	b.perClass = b.perClass or {}
	return b
end

-- The blessing a class should get (spell ID), or nil for none.
function TT:BlessingFor(class)
	local cfg = self:BlessCfg()
	local id = cfg.perClass[class]
	if id == nil then
		for _, c in ipairs(self.BLESS_CLASSES) do
			if c.class == class then id = c.default end
		end
	end
	if id == 0 then return nil end
	if not id or not Known(id) then
		id = cfg.fallback
		if not id or id == 0 or not Known(id) then
			id = Known(19740) and 19740 or nil
		end
	end
	return id
end

-- Seconds left on a blessing (by name, any rank) on a unit: 0 = missing, nil = can't tell.
local function TimeLeft(unit, name)
	if not (C_UnitAuras and C_UnitAuras.GetBuffDataByIndex) then return nil end
	for i = 1, 40 do
		local ok, aura = pcall(C_UnitAuras.GetBuffDataByIndex, unit, i)
		if not ok or Secret(aura) then return nil end
		if not aura then return 0 end
		if Secret(aura.name) then return nil end
		if aura.name == name then
			local exp = aura.expirationTime
			if Secret(exp) then return nil end
			if not exp or exp == 0 then return math.huge end
			return exp - GetTime()
		end
	end
	return 0
end

local function Units()
	local list = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do table.insert(list, "raid" .. i) end
	else
		for i = 1, GetNumSubgroupMembers() do table.insert(list, "party" .. i) end
		table.insert(list, "player")
	end
	return list
end

local function InRange(unit)
	if IsMe(unit) then return true end
	local ok, inRange, checked = pcall(UnitInRange, unit)
	if not ok or Secret(inRange) or Secret(checked) then return true end
	return (not checked) or inRange
end

-- Who needs a blessing now. Returns unit, spellID, done, total.
function TT:NextBlessing()
	local cfg = self:BlessCfg()
	local total, done = 0, 0
	local pick, pickSpell
	for _, unit in ipairs(Units()) do
		if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
			local _, class = UnitClass(unit)
			local id = not Secret(class) and class and self:BlessingFor(class)
			if id and IsMe(unit) and id == SALVATION then id = nil end -- never Salvation on yourself
			if id then
				total = total + 1
				local left = TimeLeft(unit, SpellName(id))
				if left ~= nil and left <= (cfg.refresh or 60) then
					if not pick and InRange(unit) then pick, pickSpell = unit, id end
				else
					done = done + 1
				end
			end
		end
	end
	return pick, pickSpell, done, total
end

local function SetText(text)
	f.text:SetText(text)
end

function TT:UpdateBless()
	if not f then return end
	if InCombatLockdown() then
		SetText("|cff8a8a96In combat|r")
		return
	end
	if TT.unlocked then
		SetText("Blessing helper")
		return
	end
	local unit, id, done, total = self:NextBlessing()
	if unit then
		local name = UnitName(unit)
		f:SetAttribute("type", "spell")
		f:SetAttribute("spell", SpellName(id))
		f:SetAttribute("unit", unit)
		f.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id))
		f.icon:SetDesaturated(false)
		SetText(("%s |cffffd200%s|r  |cff8a8a96%d/%d|r"):format(
			((SpellName(id) or "Bless"):gsub("^Blessing of ", "")), Secret(name) and "?" or (name or "?"), done, total))
	else
		f:SetAttribute("type", nil)
		f:SetAttribute("spell", nil)
		f.icon:SetDesaturated(true)
		SetText(total > 0 and ("|cff4fd15fAll blessed|r  |cff8a8a96%d/%d|r"):format(done, total) or "|cff8a8a96Nobody to bless|r")
	end
end

local function Queue()
	if queued then return end
	queued = true
	C_Timer.After(0.3, function()
		queued = false
		TT:UpdateBless()
	end)
end

function TT:UpdateBlessEnabled()
	if not f then return end
	self:RunOutOfCombat("blessEnabled", function()
		local _, class = UnitClass("player")
		local on = self:BlessCfg().enabled and class == "PALADIN"
		if TT.unlocked and class == "PALADIN" then
			UnregisterStateDriver(f, "visibility")
			f:Show()
		elseif on then
			RegisterStateDriver(f, "visibility", self:BlessCfg().solo and "show" or "[group] show; hide")
		else
			UnregisterStateDriver(f, "visibility")
			f:Hide()
		end
		TT:UpdateBless()
	end)
end

function TT:SetupBlessings()
	local _, class = UnitClass("player")
	if class ~= "PALADIN" then return end
	f = CreateFrame("Button", "TitanToolsBless", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
	f:SetSize(200, 30)
	f:RegisterForClicks("AnyUp", "AnyDown")
	f:SetAttribute("useOnKeyDown", false)
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	f:SetBackdropColor(0.05, 0.05, 0.07, 0.85)
	f:SetBackdropBorderColor(0, 0, 0, 1)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(26, 26)
	f.icon:SetPoint("LEFT", 2, 0)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.text:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
	f.text:SetPoint("RIGHT", -4, 0)
	f.text:SetJustifyH("LEFT")
	f.text:SetWordWrap(false)
	f:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
	f:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
	f:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Blessing helper")
		GameTooltip:AddLine("Click (or your key) to bless the next person who needs it.", 0.85, 0.85, 0.85, true)
		GameTooltip:AddLine("Key: Esc > Options > Keybindings > AddOns > TitanTools.", 0.6, 0.6, 0.65, true)
		GameTooltip:AddLine("Which blessing each class gets: /tui > TitanTools.", 0.6, 0.6, 0.65, true)
		GameTooltip:Show()
	end)
	f:HookScript("OnLeave", GameTooltip_Hide)
	-- After a cast, look again (the target now has it).
	f:HookScript("PostClick", Queue)

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "UNIT_AURA", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
		"SPELLS_CHANGED", "UNIT_CONNECTION", "PLAYER_ENTERING_WORLD" }) do
		ev:RegisterEvent(e)
	end
	ev:SetScript("OnEvent", Queue)
	-- Blessings run out over time with no event, so look again every few seconds.
	C_Timer.NewTicker(3, function()
		if f:IsVisible() and not InCombatLockdown() then TT:UpdateBless() end
	end)

	self:RegisterMovable(f, "bless", "Blessing helper", { "CENTER", UIParent, "CENTER", 0, -180 })
	self:UpdateBlessEnabled()
end
