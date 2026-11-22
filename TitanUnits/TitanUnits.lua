-- TitanUnits: party and raid frames built for tanking.
--
-- The frames themselves are Blizzard's secure group headers, so who is in which slot
-- updates by itself even in combat, and clicking works like Blizzard's frames
-- (left-click targets, right-click opens the unit menu).
--
-- Forever hides exact numbers from addons in combat ("secret values"). They can still be
-- drawn: health bars and the health % come straight from the game. Anything that needs a
-- yes/no (in range? has aggro? is my target?) goes through the game's own
-- "colour/alpha from a yes/no" calls, so it keeps working in combat. Plain Lua never
-- compares a value that might be secret.
local ADDON, TU = ...
_G.TitanUnits = TU

local DEFAULTS = {
	enabled = true,
	width = 120,
	height = 38,
	spacing = 3,
	scale = 1,
	grow = "down",        -- party: "down" or "right"
	showPlayer = true,
	showSolo = false,
	hideBlizzard = true,
	classColors = true,
	power = true,
	healthText = "percent", -- "percent" or "none"
	rangeAlpha = 0.4,
	aggro = true,
	locked = true,
	pos = nil,            -- { x, y } top-left in screen pixels
}

local TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local AGGRO = CreateColor(1, 0.15, 0.1, 1)
local buttons = {}
local anchor, party, raid, mover
local pendingLayout = false
local curve

local function Secret(v) return issecretvalue and issecretvalue(v) or false end

function TU:Print(msg)
	print("|cff33ccffTitanUnits|r: " .. msg)
end

local function Merge(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then dst[k] = v end
	end
end

-- Is this unit me? Never compares a hidden value.
local function IsMe(u)
	if u == "player" then return true end
	local ok, r = pcall(UnitIsUnit, u, "player")
	return ok and not Secret(r) and r or false
end

local function SameUnit(a, b)
	if a == b then return true end
	local ok, r = pcall(UnitIsUnit, a, b)
	return ok and not Secret(r) and r or false
end

local function AlphaFromBoolean(region, flag, yes, no)
	if region.SetAlphaFromBoolean then
		region:SetAlphaFromBoolean(flag, yes, no)
	elseif not Secret(flag) then
		region:SetAlpha(flag and yes or no)
	end
end

---------------------------------------------------------------------------
-- One button's look. Runs when the secure header creates the button (also in combat;
-- nothing here touches the secure parts).
local function Edge(parent, layer, size)
	local t = {}
	for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
		local l = parent:CreateTexture(nil, layer)
		l:SetPoint(p[1])
		l:SetPoint(p[2])
		if p[3] then l:SetHeight(size) else l:SetWidth(size) end
		l:SetColorTexture(1, 1, 1, 1)
		t[i] = l
	end
	return t
end

function TitanUnits_ButtonOnLoad(b)
	-- Everything visible sits on a plain child frame, so fading it for range never
	-- touches the secure button.
	local v = CreateFrame("Frame", nil, b)
	v:SetAllPoints()
	b.v = v
	local bg = v:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.06, 0.06, 0.08, 0.9)

	b.hp = CreateFrame("StatusBar", nil, v)
	b.hp:SetStatusBarTexture(TEX)
	b.hp:SetPoint("TOPLEFT", 1, -1)
	b.hp:SetPoint("RIGHT", -1, 0)
	b.power = CreateFrame("StatusBar", nil, v)
	b.power:SetStatusBarTexture(TEX)
	b.power:SetPoint("BOTTOMLEFT", 1, 1)
	b.power:SetPoint("BOTTOMRIGHT", -1, 1)
	b.power:SetHeight(4)

	local over = CreateFrame("Frame", nil, v)
	over:SetAllPoints()
	over:SetFrameLevel(b.hp:GetFrameLevel() + 3)
	b.name = over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.name:SetPoint("TOPLEFT", 5, -4)
	b.name:SetPoint("RIGHT", -34, 0)
	b.name:SetJustifyH("LEFT")
	b.name:SetWordWrap(false)
	b.hpText = over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.hpText:SetPoint("TOPRIGHT", -4, -4)
	b.status = over:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	b.status:SetPoint("BOTTOMLEFT", 5, 7)

	b.aggro = Edge(over, "OVERLAY", 2)
	for _, l in ipairs(b.aggro) do l:SetVertexColor(AGGRO:GetRGBA()); l:SetAlpha(0) end
	b.targetEdge = Edge(over, "ARTWORK", 1)
	for _, l in ipairs(b.targetEdge) do l:SetAlpha(0) end

	b:HookScript("OnAttributeChanged", function(self, name, value)
		if name == "unit" then
			self.unit = value
			TU:UpdateButton(self)
		end
	end)
	b:HookScript("OnShow", function(self) TU:UpdateButton(self) end)
	b:HookScript("OnEnter", function(self)
		if not self.unit then return end
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetUnit(self.unit)
		GameTooltip:Show()
	end)
	b:HookScript("OnLeave", GameTooltip_Hide)
	table.insert(buttons, b)
	TU:StyleButton(b)
end

function TU:StyleButton(b)
	local db = self.db
	if not db then return end
	b.power:SetShown(db.power)
	b.hp:SetPoint("BOTTOM", b, "BOTTOM", 0, db.power and 6 or 1)
	b.hpText:SetShown(db.healthText ~= "none")
end

---------------------------------------------------------------------------
-- Updates
local function ClassColor(unit)
	local ok, _, class = pcall(UnitClass, unit)
	if not ok or Secret(class) or not class then return nil end
	return RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
end

local function HealthPercentCurve()
	if curve == nil then
		curve = false
		if C_CurveUtil and C_CurveUtil.CreateCurve then
			local ok, c = pcall(C_CurveUtil.CreateCurve)
			if ok and c then
				c:AddPoint(0, 0)
				c:AddPoint(1, 100)
				curve = c
			end
		end
	end
	return curve or nil
end

function TU:UpdateHealth(b)
	local u = b.unit
	b.hp:SetMinMaxValues(0, UnitHealthMax(u))
	b.hp:SetValue(UnitHealth(u))
	local dead, offline = UnitIsDeadOrGhost(u), not UnitIsConnected(u)
	if offline then
		b.status:SetText("Offline")
	elseif dead then
		b.status:SetText("Dead")
	else
		b.status:SetText("")
	end
	if self.db.healthText == "percent" and not dead and not offline then
		local c = HealthPercentCurve()
		if c and UnitHealthPercent then
			local ok = pcall(function() b.hpText:SetFormattedText("%.0f%%", UnitHealthPercent(u, true, c)) end)
			if not ok then b.hpText:SetText("") end
		else
			local hp, max = UnitHealth(u), UnitHealthMax(u)
			if not Secret(hp) and not Secret(max) and max > 0 then
				b.hpText:SetFormattedText("%.0f%%", hp / max * 100)
			else
				b.hpText:SetText("")
			end
		end
	else
		b.hpText:SetText("")
	end
	local tex = b.hp:GetStatusBarTexture()
	if dead or offline then
		tex:SetVertexColor(0.35, 0.35, 0.38)
	elseif self.db.classColors then
		local cc = ClassColor(u)
		if cc then tex:SetVertexColor(cc.r, cc.g, cc.b) else tex:SetVertexColor(0.3, 0.75, 0.3) end
	else
		tex:SetVertexColor(0.25, 0.7, 0.25)
	end
end

function TU:UpdatePower(b)
	if not self.db.power then return end
	local u = b.unit
	b.power:SetMinMaxValues(0, UnitPowerMax(u))
	b.power:SetValue(UnitPower(u))
	local ok, ptype = pcall(UnitPowerType, u)
	local c = ok and not Secret(ptype) and PowerBarColor and PowerBarColor[ptype]
	if c then
		b.power:GetStatusBarTexture():SetVertexColor(c.r, c.g, c.b)
	else
		b.power:GetStatusBarTexture():SetVertexColor(0.2, 0.4, 1)
	end
end

function TU:UpdateName(b)
	local u = b.unit
	b.name:SetText(UnitName(u))
	local cc = not self.db.classColors and ClassColor(u)
	if cc then b.name:SetTextColor(cc.r, cc.g, cc.b) else b.name:SetTextColor(1, 1, 1) end
end

-- Red border on a group member who has a mob on them (not you: you're the tank).
function TU:UpdateAggro(b)
	local u = b.unit
	local edges = b.aggro
	local function Set(flag, yes, no)
		for _, l in ipairs(edges) do AlphaFromBoolean(l, flag, yes, no) end
	end
	if not self.db.aggro or IsMe(u) then
		Set(false, 1, 0)
		return
	end
	local ok, status = pcall(UnitThreatSituation, u)
	if ok and status ~= nil and not Secret(status) then
		Set(status >= 2, 1, 0)
		return
	end
	-- The game hid the overall threat state: fall back to "is my target hitting them?".
	if UnitExists("target") and UnitCanAttack("player", "target") then
		local ok2, isTanking = pcall(UnitDetailedThreatSituation, u, "target")
		if ok2 and isTanking ~= nil then
			Set(isTanking, 1, 0)
			return
		end
	end
	Set(false, 1, 0)
end

function TU:UpdateTarget(b)
	local flag = UnitIsUnit(b.unit, "target")
	for _, l in ipairs(b.targetEdge) do AlphaFromBoolean(l, flag, 0.9, 0) end
end

function TU:UpdateRange(b)
	local u = b.unit
	if IsMe(u) then
		b.v:SetAlpha(1)
		return
	end
	local ok, inRange, checked = pcall(UnitInRange, u)
	if not ok or inRange == nil then
		b.v:SetAlpha(1)
		return
	end
	if not Secret(checked) and checked == false then
		b.v:SetAlpha(1)
		return
	end
	AlphaFromBoolean(b.v, inRange, 1, self.db.rangeAlpha)
end

function TU:UpdateButton(b)
	if not b.unit or not UnitExists(b.unit) or not self.db then return end
	for _, fn in ipairs({ self.UpdateHealth, self.UpdatePower, self.UpdateName, self.UpdateAggro, self.UpdateTarget, self.UpdateRange }) do
		local ok, err = pcall(fn, self, b)
		if not ok and not self.warned then
			self.warned = true
			self:Print("frame error (please send this): " .. tostring(err))
		end
	end
end

function TU:ForUnit(unit, fn)
	for _, b in ipairs(buttons) do
		if b.unit and b:IsVisible() and (unit == nil or SameUnit(b.unit, unit)) then
			pcall(fn, self, b)
		end
	end
end

function TU:UpdateAll()
	for _, b in ipairs(buttons) do
		if b:IsVisible() then self:UpdateButton(b) end
	end
end

---------------------------------------------------------------------------
-- Headers and layout (out of combat only: Blizzard locks secure frames in combat)
local function ConfigSnippet(w, h)
	return ([[
		self:SetWidth(%d)
		self:SetHeight(%d)
		self:SetAttribute("*type1", "target")
		self:SetAttribute("*type2", "togglemenu")
		self:RegisterForClicks("AnyUp")
	]]):format(w, h)
end

function TU:ApplyLayout()
	if not party then return end
	if InCombatLockdown() then
		pendingLayout = true
		return
	end
	pendingLayout = false
	local db = self.db
	local w, h, gap = math.floor(db.width), math.floor(db.height), math.floor(db.spacing)

	anchor:SetScale(db.scale)
	anchor:ClearAllPoints()
	if db.pos then
		local s = anchor:GetEffectiveScale()
		anchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.pos.x / s, db.pos.y / s)
	else
		anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -260)
	end

	for _, hdr in ipairs({ party, raid }) do
		hdr:SetAttribute("initialConfigFunction", ConfigSnippet(w, h))
	end
	for _, b in ipairs(buttons) do
		b:SetSize(w, h)
		self:StyleButton(b)
	end

	party:SetAttribute("showPlayer", db.showPlayer)
	party:SetAttribute("showSolo", db.showSolo)
	if db.grow == "right" then
		party:SetAttribute("point", "LEFT")
		party:SetAttribute("xOffset", gap)
		party:SetAttribute("yOffset", 0)
	else
		party:SetAttribute("point", "TOP")
		party:SetAttribute("xOffset", 0)
		party:SetAttribute("yOffset", -gap)
	end
	raid:SetAttribute("point", "TOP")
	raid:SetAttribute("yOffset", -gap)
	raid:SetAttribute("columnSpacing", gap)

	if db.enabled then
		RegisterStateDriver(party, "visibility", "[group:raid] hide; show")
		RegisterStateDriver(raid, "visibility", "[group:raid] show; hide")
	else
		UnregisterStateDriver(party, "visibility")
		UnregisterStateDriver(raid, "visibility")
		party:Hide()
		raid:Hide()
	end
	self:ApplyBlizzard()
	self:PlaceMover()
	self:UpdateAll()
end

local function Header(name, isRaid)
	local hdr = CreateFrame("Frame", name, anchor, "SecureGroupHeaderTemplate")
	hdr:SetPoint("TOPLEFT", anchor, "TOPLEFT")
	hdr:SetAttribute("template", "TitanUnitsButtonTemplate")
	hdr:SetAttribute("templateType", "Button")
	hdr:SetAttribute("sortMethod", "INDEX")
	if isRaid then
		hdr:SetAttribute("showRaid", true)
		hdr:SetAttribute("groupBy", "GROUP")
		hdr:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
		hdr:SetAttribute("maxColumns", 8)
		hdr:SetAttribute("unitsPerColumn", 5)
		hdr:SetAttribute("columnAnchorPoint", "LEFT")
	else
		hdr:SetAttribute("showParty", true)
	end
	return hdr
end

---------------------------------------------------------------------------
-- Blizzard's party and raid frames
local hider = CreateFrame("Frame")
hider:Hide()
local BLIZZARD = { "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer" }
local origParent, hookedBlizz = {}, {}

function TU:ApplyBlizzard()
	if InCombatLockdown() then
		pendingLayout = true
		return
	end
	local hide = self.db.enabled and self.db.hideBlizzard
	for _, n in ipairs(BLIZZARD) do
		local f = _G[n]
		if f then
			if not hookedBlizz[f] then
				hookedBlizz[f] = true
				hooksecurefunc(f, "SetParent", function(_, p)
					if p ~= hider and TU.db.enabled and TU.db.hideBlizzard then
						C_Timer.After(0, function() TU:ApplyBlizzard() end)
					end
				end)
			end
			if hide and f:GetParent() ~= hider then
				origParent[f] = f:GetParent()
				f:SetParent(hider)
			elseif not hide and f:GetParent() == hider then
				f:SetParent(origParent[f] or UIParent)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Moving
local function SavePos()
	local s = mover:GetEffectiveScale()
	TU.db.pos = { x = mover:GetLeft() * s, y = mover:GetTop() * s }
end

function TU:PlaceMover()
	if not mover then return end
	local db = self.db
	local n = db.grow == "right" and 5 or 1
	mover:SetSize((db.width * n + db.spacing * (n - 1)) * db.scale, (db.height * (6 - n) + db.spacing * (5 - n)) * db.scale)
	mover:ClearAllPoints()
	mover:SetPoint("TOPLEFT", anchor, "TOPLEFT")
	mover:SetShown(not db.locked)
end

function TU:SetLocked(locked)
	if not locked and InCombatLockdown() then return self:Print("can't move frames in combat.") end
	self.db.locked = locked
	self:PlaceMover()
	if not locked then self:Print("drag the green box to move the group frames; lock them in /tui when done.") end
end

local function CreateMover()
	mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	mover:SetFrameStrata("DIALOG")
	mover:SetMovable(true)
	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")
	mover:SetClampedToScreen(true)
	mover:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	mover:SetBackdropColor(0.2, 0.8, 0.3, 0.35)
	mover:SetBackdropBorderColor(0.4, 1, 0.5, 1)
	local t = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	t:SetPoint("CENTER")
	t:SetText("Group frames\n|cffffffffdrag to move|r")
	mover:SetScript("OnDragStart", function(self)
		if InCombatLockdown() then return end
		self:StartMoving()
	end)
	mover:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePos()
		TU:ApplyLayout()
	end)
	mover:Hide()
end

---------------------------------------------------------------------------
SLASH_TITANUNITS1 = "/tunits"
SLASH_TITANUNITS2 = "/titanunits"
SlashCmdList.TITANUNITS = function(msg)
	local cmd = strtrim(msg or ""):lower()
	if cmd == "unlock" then
		TU:SetLocked(false)
	elseif cmd == "lock" then
		TU:SetLocked(true)
	elseif cmd == "solo" then
		TU.db.showSolo = not TU.db.showSolo
		TU:ApplyLayout()
		TU:Print(TU.db.showSolo and "showing your own frame while solo (handy for setting up)." or "hidden while solo.")
	elseif cmd == "reset" then
		TU.db.pos = nil
		TU:ApplyLayout()
	else
		TU:Print("/tunits unlock | lock - move the group frames")
		print("  /tunits solo - show your own frame while solo (to set them up)")
		print("  /tunits reset - back to the default spot.  All settings: /tui units")
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
local UNIT_EVENTS = {
	UNIT_HEALTH = "UpdateHealth", UNIT_MAXHEALTH = "UpdateHealth", UNIT_CONNECTION = "UpdateHealth",
	UNIT_FLAGS = "UpdateHealth",
	UNIT_POWER_UPDATE = "UpdatePower", UNIT_MAXPOWER = "UpdatePower", UNIT_DISPLAYPOWER = "UpdatePower",
	UNIT_NAME_UPDATE = "UpdateName",
	UNIT_THREAT_SITUATION_UPDATE = "UpdateAggro", UNIT_THREAT_LIST_UPDATE = "UpdateAggro",
}
ev:SetScript("OnEvent", function(_, event, a1)
	if event == "ADDON_LOADED" then
		if a1 == ADDON then
			TitanUnitsDB = TitanUnitsDB or {}
			Merge(TitanUnitsDB, DEFAULTS)
			TU.db = TitanUnitsDB
		end
	elseif event == "PLAYER_LOGIN" then
		anchor = CreateFrame("Frame", "TitanUnitsAnchor", UIParent)
		anchor:SetSize(10, 10)
		CreateMover()
		party = Header("TitanUnitsParty", false)
		raid = Header("TitanUnitsRaid", true)
		TU.party, TU.raid = party, raid
		TU:ApplyLayout()
		for e in pairs(UNIT_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
		for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
			ev:RegisterEvent(e)
		end
		-- Range and "is my target hitting them" have no events: check a few times a second.
		C_Timer.NewTicker(0.25, function()
			for _, b in ipairs(buttons) do
				if b.unit and b:IsVisible() then
					pcall(TU.UpdateRange, TU, b)
					pcall(TU.UpdateAggro, TU, b)
				end
			end
		end)
	elseif UNIT_EVENTS[event] then
		TU:ForUnit(a1, TU[UNIT_EVENTS[event]])
	elseif event == "PLAYER_TARGET_CHANGED" then
		TU:ForUnit(nil, TU.UpdateTarget)
		TU:ForUnit(nil, TU.UpdateAggro)
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingLayout then TU:ApplyLayout() end
	else
		C_Timer.After(0.2, function() TU:UpdateAll() end)
	end
end)
