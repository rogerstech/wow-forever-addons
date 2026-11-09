-- TitanTools: a target-of-target frame for tanking. On a hostile target the bar is
-- green while the mob is on you and red (with a "!") when it's on someone else.
-- Click it to target that person.
local ADDON, TT = ...

local UNIT = "targettarget"
local ON_ME = CreateColor(0.2, 0.8, 0.2, 1)
local OFF_ME = CreateColor(0.9, 0.15, 0.15, 1)

local f

-- The client can hand addons "secret" values in combat (health, who is who).
-- Blizzard's widgets accept them directly; plain Lua can't test them.
local function IsSecret(v)
	return issecretvalue and issecretvalue(v)
end

local function ColorFromBoolean(tex, flag, yes, no)
	if tex.SetVertexColorFromBoolean then
		tex:SetVertexColorFromBoolean(flag, yes, no)
	elseif not IsSecret(flag) then
		tex:SetVertexColor((flag and yes or no):GetRGBA())
	end
end

local function AlphaFromBoolean(region, flag, ifTrue, ifFalse)
	if region.SetAlphaFromBoolean then
		region:SetAlphaFromBoolean(flag, ifTrue, ifFalse)
	elseif not IsSecret(flag) then
		region:SetAlpha(flag and ifTrue or ifFalse)
	end
end

local function Update()
	if TT.unlocked then return end
	if not UnitExists(UNIT) then return end
	f.name:SetText(UnitName(UNIT))
	f.hp:SetMinMaxValues(0, UnitHealthMax(UNIT))
	f.hp:SetValue(UnitHealth(UNIT))
	local tex = f.hp:GetStatusBarTexture()
	if UnitCanAttack("player", "target") then
		local onMe = UnitIsUnit(UNIT, "player")
		ColorFromBoolean(tex, onMe, ON_ME, OFF_ME)
		AlphaFromBoolean(f.warn, onMe, 0, 1)
	else
		-- Friendly target: just show who they're targeting, in class colour for players.
		local _, class = UnitClass(UNIT)
		local c = UnitIsPlayer(UNIT) and class and RAID_CLASS_COLORS[class]
		if c then tex:SetVertexColor(c.r, c.g, c.b) else tex:SetVertexColor(0.5, 0.5, 0.6) end
		f.warn:SetAlpha(0)
	end
end

function TT:UpdateToTEnabled()
	self:RunOutOfCombat("totEnabled", function()
		if TT.db.tot.enabled or TT.unlocked then
			if TT.unlocked then
				UnregisterUnitWatch(f)
				f:Show()
			else
				RegisterUnitWatch(f)
			end
		else
			UnregisterUnitWatch(f)
			f:Hide()
		end
	end)
end

function TT:UpdateToTUnlocked()
	if not f then return end
	if self.unlocked then
		f.name:SetText("Target of target")
		f.hp:SetMinMaxValues(0, 1)
		f.hp:SetValue(1)
		f.hp:GetStatusBarTexture():SetVertexColor(ON_ME:GetRGB())
		f.warn:SetAlpha(1)
	end
	self:UpdateToTEnabled()
end

function TT:SetupToT()
	f = CreateFrame("Button", "TitanToolsToT", UIParent, "SecureUnitButtonTemplate, BackdropTemplate")
	f:SetSize(150, 30)
	f:SetAttribute("unit", UNIT)
	f:SetAttribute("type1", "target")
	f:SetAttribute("type2", "togglemenu")
	f:RegisterForClicks("AnyUp")
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	f:SetBackdropColor(0, 0, 0, 0.6)
	f:SetBackdropBorderColor(0, 0, 0, 1)

	f.hp = CreateFrame("StatusBar", nil, f)
	f.hp:SetPoint("TOPLEFT", 1, -1)
	f.hp:SetPoint("BOTTOMRIGHT", -1, 1)
	f.hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

	f.name = f.hp:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.name:SetPoint("LEFT", 6, 0)
	f.name:SetPoint("RIGHT", -22, 0)
	f.name:SetJustifyH("LEFT")
	f.name:SetWordWrap(false)

	f.warn = f.hp:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	f.warn:SetPoint("RIGHT", -6, 0)
	f.warn:SetTextColor(1, 0.85, 0)
	f.warn:SetText("!")
	f.warn:SetAlpha(0)

	f:HookScript("OnEnter", function(self)
		if TT.unlocked then return end
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetUnit(UNIT)
		GameTooltip:Show()
	end)
	f:HookScript("OnLeave", function() GameTooltip:Hide() end)

	-- Target-of-target has no events of its own, so poll a few times a second.
	local elapsed = 0
	f:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 0.1 then return end
		elapsed = 0
		local ok = pcall(Update)
		if not ok then f.warn:SetAlpha(0) end
	end)

	self:RegisterMovable(f, "tot", "Target of target", { "CENTER", UIParent, "CENTER", 250, -120 })
	self:UpdateToTEnabled()
end
