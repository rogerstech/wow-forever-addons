-- TitanTools: big icons for missing self-buffs, and a warning when you're
-- in a group without your tank form/buff (Bear Form, Righteous Fury).
local ADDON, TT = ...

-- Each entry: the spell to look for (any rank; the name covers all ranks) and other
-- buffs that count as having it. Only shown if you know the spell.
local BUFFS = {
	DRUID = {
		{ spell = 1126, also = { 21849 } }, -- Mark of the Wild (Gift of the Wild counts)
		{ spell = 467 },                    -- Thorns
		{ spell = 16864 },                  -- Omen of Clarity (talent)
	},
	PALADIN = {
		-- Any of your blessings counts. Salvation doesn't: a tank never wants it.
		{ spell = 19740, label = "Blessing", also = {
			19742, 20217, 20911, 19977,          -- Wisdom, Kings, Sanctuary, Light
			25782, 25894, 25898, 25899, 25890,   -- the Greater versions
		} },
	},
}

local BEAR_SPELLS = { [5487] = true, [9634] = true } -- Bear Form, Dire Bear Form
local BEAR_FORM_ID = 5
local RIGHTEOUS_FURY = 25780
local SALVATION = { 1038, 25895 } -- Blessing / Greater Blessing of Salvation
local DEVOTION_AURA = 465
local LOW_TIME = 60
local ICON_SIZE, GAP = 44, 8

local holder, icons = nil, {}

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end

local function SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
	return select(3, GetSpellInfo(id))
end

local function Known(id)
	if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) then return true end
	return IsPlayerSpell and IsPlayerSpell(id) or false
end

-- Returns the buff's seconds left (math.huge if it doesn't run out), or nil if missing.
local function BuffTimeLeft(name)
	local aura = C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")
	if not aura then return nil end
	local exp = aura.expirationTime
	if not exp or exp == 0 then return math.huge end
	return exp - GetTime()
end

-- BuffTimeLeft, but returns false instead of erroring when the client hides
-- your auras from addons (it can in combat).
local function SafeTimeLeft(name)
	local ok, left = pcall(BuffTimeLeft, name)
	if not ok or (issecretvalue and issecretvalue(left)) then return false end
	return left
end

-- Seconds of Righteous Fury left, or nil if it's off. If the client hides it in
-- combat, trust what we saw before the pull.
local rfUntil
local function RighteousFuryLeft()
	local name = SpellName(RIGHTEOUS_FURY)
	if not name then return nil end
	local left = SafeTimeLeft(name)
	if left == false then
		local now = GetTime()
		return rfUntil and rfUntil > now and rfUntil - now or nil
	end
	rfUntil = left and GetTime() + left or nil
	return left
end

local function HasAnyBuff(ids)
	for _, id in ipairs(ids) do
		local name = SpellName(id)
		if name and SafeTimeLeft(name) then return true end
	end
	return false
end

local function InBearForm()
	if GetShapeshiftFormID and GetShapeshiftFormID() == BEAR_FORM_ID then return true end
	for i = 1, GetNumShapeshiftForms() or 0 do
		local _, active, _, spellID = GetShapeshiftFormInfo(i)
		if active and BEAR_SPELLS[spellID] then return true end
	end
	return false
end

local function GetIcon(n)
	local b = icons[n]
	if b then return b end
	b = CreateFrame("Frame", nil, holder)
	b:SetSize(ICON_SIZE, ICON_SIZE)
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetAllPoints()
	b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.border = b:CreateTexture(nil, "OVERLAY")
	b.border:SetPoint("TOPLEFT", -2, 2)
	b.border:SetPoint("BOTTOMRIGHT", 2, -2)
	b.border:SetColorTexture(1, 0.2, 0.2, 0.9)
	b.border:SetDrawLayer("BACKGROUND")
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.text:SetPoint("TOP", b, "BOTTOM", 0, -2)
	b.text:SetWidth(ICON_SIZE + GAP + 20)
	b.pulse = b:CreateAnimationGroup()
	b.pulse:SetLooping("BOUNCE")
	local a = b.pulse:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.45)
	a:SetDuration(0.6)
	icons[n] = b
	return b
end

local function ShowIcons(list)
	for n, item in ipairs(list) do
		local b = GetIcon(n)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", holder, "TOPLEFT", (n - 1) * (ICON_SIZE + GAP), 0)
		b.tex:SetTexture(item.icon)
		b.text:SetText(item.text)
		b.border:SetColorTexture(item.r or 1, item.g or 0.2, item.b or 0.2, 0.9)
		b:Show()
		if not b.pulse:IsPlaying() then b.pulse:Play() end
	end
	for n = #list + 1, #icons do
		icons[n].pulse:Stop()
		icons[n]:Hide()
	end
	holder:SetWidth(math.max(1, #list) * (ICON_SIZE + GAP) - GAP)
end

-- Builds the list of icons to show right now.
local function Collect()
	local cfg, list = TT.db.reminder, {}
	if not cfg.enabled then return list end
	if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") or (UnitInVehicle and UnitInVehicle("player")) then return list end
	local inCombat = InCombatLockdown()
	local _, class = UnitClass("player")

	-- Tank form/buff, in a group only. Bear Form is checked in combat (you pull in
	-- caster form). Righteous Fury is checked before the pull too, so you can fix it.
	if cfg.bearWarning and IsInGroup() then
		if class == "DRUID" and inCombat and Known(5487) and not InBearForm() then
			table.insert(list, { icon = SpellIcon(5487), text = "NOT IN BEAR", r = 1, g = 0.5, b = 0 })
		elseif class == "PALADIN" and Known(RIGHTEOUS_FURY) then
			local left = RighteousFuryLeft()
			if not left then
				table.insert(list, { icon = SpellIcon(RIGHTEOUS_FURY), text = "NO FURY", r = 1, g = 0.5, b = 0 })
			elseif not inCombat and cfg.lowTime and left < LOW_TIME then
				table.insert(list, { icon = SpellIcon(RIGHTEOUS_FURY), text = ("Fury %ds"):format(left), r = 1, g = 0.85, b = 0 })
			end
			if not inCombat and HasAnyBuff(SALVATION) then
				table.insert(list, { icon = SpellIcon(SALVATION[1]), text = "REMOVE SALV", r = 1, g = 0.5, b = 0 })
			end
		end
	end

	-- Buffs are only checked out of combat: you can't rebuff mid-pull anyway, and the
	-- client hides some aura details from addons during combat.
	if not inCombat then
		-- Paladin auras live on the stance bar: none active = no aura.
		if class == "PALADIN" and (GetNumShapeshiftForms() or 0) > 0 and (GetShapeshiftForm() or 0) == 0 then
			table.insert(list, { icon = SpellIcon(DEVOTION_AURA), text = "No aura" })
		end
		for _, buff in ipairs(BUFFS[class] or {}) do
			if Known(buff.spell) then
				local name = SpellName(buff.spell)
				local left = name and BuffTimeLeft(name)
				for _, other in ipairs(buff.also or {}) do
					local otherName = SpellName(other)
					local otherLeft = otherName and BuffTimeLeft(otherName)
					if otherLeft and (not left or otherLeft > left) then left = otherLeft end
				end
				local label = buff.label or name
				if not left then
					table.insert(list, { icon = SpellIcon(buff.spell), text = label })
				elseif cfg.lowTime and left < LOW_TIME then
					table.insert(list, { icon = SpellIcon(buff.spell), text = ("%s %ds"):format(label, left), r = 1, g = 0.85, b = 0 })
				end
			end
		end
	end
	return list
end

-- Shown while unlocked so you can see and drag the frame.
local function Placeholder()
	return {
		{ icon = SpellIcon(1126) or 136078, text = "Missing buff" },
		select(2, UnitClass("player")) == "PALADIN"
			and { icon = SpellIcon(RIGHTEOUS_FURY) or 135962, text = "NO FURY", r = 1, g = 0.5, b = 0 }
			or { icon = SpellIcon(5487) or 132276, text = "NOT IN BEAR", r = 1, g = 0.5, b = 0 },
	}
end

function TT:UpdateReminders()
	if not holder then return end
	if self.unlocked then
		ShowIcons(Placeholder())
		return
	end
	local ok, list = pcall(Collect)
	ShowIcons(ok and list or {})
end

function TT:SetupReminders()
	holder = CreateFrame("Frame", "TitanToolsReminders", UIParent)
	holder:SetSize(ICON_SIZE, ICON_SIZE + 14)
	self:RegisterMovable(holder, "reminder", "Buff reminder", { "CENTER", UIParent, "CENTER", 0, 160 })

	local events = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
		"UPDATE_SHAPESHIFT_FORM", "GROUP_ROSTER_UPDATE", "SPELLS_CHANGED", "PLAYER_ALIVE",
		"PLAYER_UNGHOST", "PLAYER_DEAD", "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST" }) do
		pcall(events.RegisterEvent, events, e)
	end
	events:RegisterUnitEvent("UNIT_AURA", "player")
	events:SetScript("OnEvent", function(_, event)
		-- REGEN_DISABLED fires just before combat starts; check again once it has.
		if event == "PLAYER_REGEN_DISABLED" then
			C_Timer.After(0, function() TT:UpdateReminders() end)
		end
		TT:UpdateReminders()
	end)
	-- Count down buffs that are running low.
	C_Timer.NewTicker(1, function() TT:UpdateReminders() end)
	self:UpdateReminders()
end
