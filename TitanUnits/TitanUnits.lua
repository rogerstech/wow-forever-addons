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
	bossEnabled = true,   -- TitanUnits boss frames (boss1-boss5)
	hideBlizzardBoss = true,
}

local TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local AGGRO = CreateColor(1, 0.15, 0.1, 1)
local buttons = {}
local anchor, raidAnchor, bossAnchor, party, raid, mover, raidMover, bossMover
local bosses = {}
local MAX_BOSSES = 5
local ON_ME, OFF_ME = CreateColor(0.25, 0.9, 0.3, 1), CreateColor(0.95, 0.2, 0.15, 1)
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

-- Right-click needs RegisterForClicks, which Blizzard doesn't allow inside the secure
-- setup snippet, and which can't be called on a secure button in combat. Buttons made
-- mid-fight (someone joins) get it as soon as combat ends.
local needClicks = {}
local function RegisterClicks(b)
	if InCombatLockdown() then
		needClicks[b] = true
	else
		b:RegisterForClicks("AnyUp")
		needClicks[b] = nil
	end
end
function TU:FlushClicks()
	for b in pairs(needClicks) do RegisterClicks(b) end
end

function TitanUnits_ButtonOnLoad(b)
	b.isBoss = false
	RegisterClicks(b)
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
	elseif b.isBoss then
		tex:SetVertexColor(0.8, 0.15, 0.12)
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
	if b.isBoss then
		-- Boss frames: green border while the boss is attacking you, red while it isn't.
		local fighting = UnitAffectingCombat(u)
		if not self.db.aggro or (not Secret(fighting) and not fighting) then Set(false, 1, 0) return end
		local ok, isTanking = pcall(UnitDetailedThreatSituation, "player", u)
		if not ok or (not Secret(isTanking) and isTanking == nil) then Set(false, 1, 0) return end
		for _, l in ipairs(edges) do
			if l.SetVertexColorFromBoolean then
				l:SetVertexColorFromBoolean(isTanking, ON_ME, OFF_ME)
			elseif not Secret(isTanking) then
				l:SetVertexColor((isTanking and ON_ME or OFF_ME):GetRGB())
			end
			l:SetAlpha(1)
		end
		return
	end
	if not self.db.aggro or IsMe(u) then
		Set(false, 1, 0)
		return
	end
	local ok, status = pcall(UnitThreatSituation, u)
	if ok and not Secret(status) and status ~= nil then
		Set(status >= 2, 1, 0)
		return
	end
	-- The game hid the overall threat state: fall back to "is my target hitting them?".
	if UnitExists("target") and UnitCanAttack("player", "target") then
		local ok2, isTanking = pcall(UnitDetailedThreatSituation, u, "target")
		if ok2 and (Secret(isTanking) or isTanking ~= nil) then
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
	if IsMe(u) or b.isBoss then
		b.v:SetAlpha(1)
		return
	end
	local ok, inRange, checked = pcall(UnitInRange, u)
	if not ok or (not Secret(inRange) and inRange == nil) then
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

	-- Party and raid frames each have their own spot. Until the raid frames are moved,
	-- they start where the party frames are.
	for _, a in ipairs({ { anchor, db.pos }, { raidAnchor, db.raidPos or db.pos }, { bossAnchor, db.bossPos, true } }) do
		local fr, pos, isBoss = a[1], a[2], a[3]
		fr:SetScale(db.scale)
		fr:ClearAllPoints()
		if pos then
			local s = fr:GetEffectiveScale()
			fr:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x / s, pos.y / s)
		elseif isBoss then
			fr:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -300)
		else
			fr:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -260)
		end
	end
	bossAnchor:SetSize(w, 10)
	-- Boss frames: one column, boss 1 at the top.
	for i, b in ipairs(bosses) do
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", bossAnchor, "TOPLEFT", 0, -(i - 1) * (h + gap + 4))
		if db.bossEnabled then
			RegisterUnitWatch(b)
		else
			UnregisterUnitWatch(b)
			b:Hide()
		end
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
	self:ApplyBlizzardBoss()
	self:PlaceMover()
	if self.testMode then self:ShowTest(self.testMode) end
	self:UpdateAll()
end

-- Boss frames: five secure unit buttons for boss1-boss5, shown by the game only while
-- that boss exists (unit watch).
local function CreateBosses()
	for i = 1, MAX_BOSSES do
		local b = CreateFrame("Button", "TitanUnitsBoss" .. i, bossAnchor, "TitanUnitsButtonTemplate")
		b.isBoss = true
		b:SetAttribute("unit", "boss" .. i)
		b:SetAttribute("*type1", "target")
		b:SetAttribute("*type2", "togglemenu")
		b:Hide()
		bosses[i] = b
	end
end

-- Blizzard's boss frames: made invisible and unclickable instead of hidden, because
-- Blizzard shows them in the middle of a fight, when addons may not hide them.
local bossHooked = false
function TU:ApplyBlizzardBoss()
	local c = _G.BossTargetFrameContainer
	if not c then return end
	local hide = self.db.bossEnabled and self.db.hideBlizzardBoss
	if not bossHooked then
		bossHooked = true
		hooksecurefunc(c, "SetAlpha", function(f, a)
			if TU.settingBossAlpha then return end
			if TU.db.bossEnabled and TU.db.hideBlizzardBoss and a ~= 0 then
				TU.settingBossAlpha = true
				f:SetAlpha(0)
				TU.settingBossAlpha = false
			end
		end)
	end
	self.settingBossAlpha = true
	c:SetAlpha(hide and 0 or 1)
	self.settingBossAlpha = false
	if not InCombatLockdown() then
		for i = 1, MAX_BOSSES do
			local bf = _G["Boss" .. i .. "TargetFrame"]
			if bf then bf:EnableMouse(not hide) end
		end
	end
end

local function Header(name, isRaid)
	local home = isRaid and raidAnchor or anchor
	local hdr = CreateFrame("Frame", name, home, "SecureGroupHeaderTemplate")
	hdr:SetPoint("TOPLEFT", home, "TOPLEFT")
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
-- While unlocked, each mover shows a preview of the frames it stands for: 5 party
-- slots, and the raid layout (8 groups of 5), so you can see the real size.
local function Preview(m, cols, rows, extraGap)
	local db = TU.db
	local w, h, gap, sc = db.width, db.height, db.spacing + (extraGap or 0), db.scale
	m:SetSize((cols * w + (cols - 1) * gap) * sc, (rows * h + (rows - 1) * gap) * sc)
	if type(m.cells) ~= "table" then m.cells = {} end
	local n = 0
	for c = 1, cols do
		for r = 1, rows do
			n = n + 1
			local t = m.cells[n] or m:CreateTexture(nil, "ARTWORK")
			m.cells[n] = t
			t:ClearAllPoints()
			t:SetSize(w * sc, h * sc)
			t:SetPoint("TOPLEFT", (c - 1) * (w + gap) * sc, -(r - 1) * (h + gap) * sc)
			t:SetColorTexture(1, 1, 1, 0.12)
			t:Show()
		end
	end
	for i = n + 1, #m.cells do m.cells[i]:Hide() end
end

local function SavePos(m)
	local s = m:GetEffectiveScale()
	local pos = { x = m:GetLeft() * s, y = m:GetTop() * s }
	if m == raidMover then TU.db.raidPos = pos
	elseif m == bossMover then TU.db.bossPos = pos
	else TU.db.pos = pos end
end

function TU:PlaceMover()
	if not mover then return end
	local db = self.db
	if db.grow == "right" then Preview(mover, 5, 1) else Preview(mover, 1, 5) end
	Preview(raidMover, 8, 5)
	Preview(bossMover, 1, MAX_BOSSES, 4)
	for _, a in ipairs({ { mover, anchor }, { raidMover, raidAnchor }, { bossMover, bossAnchor } }) do
		a[1]:ClearAllPoints()
		a[1]:SetPoint("TOPLEFT", a[2], "TOPLEFT")
		a[1]:SetShown(not db.locked and (a[1] ~= bossMover or db.bossEnabled))
	end
end

---------------------------------------------------------------------------
-- Test view: a fake full party or raid, drawn exactly like the real frames (same size,
-- spacing and layout), so you can place them without being in a group. These are plain
-- frames, not the real secure ones, so they can't target anyone.
local fakes = {}
local FAKE_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "HUNTER", "DRUID", "WARLOCK", "SHAMAN", "PALADIN" }
local FAKE_NAMES = { "Thrall", "Jaina", "Uther", "Valeera", "Rexxar", "Malfurion", "Gul'dan", "Drekthar",
	"Tirion", "Sylvanas", "Cairne", "Vol'jin", "Saurfang", "Garona", "Zul'jin", "Rokhan", "Nazgrel", "Eitrigg" }

local function FakeButton(i)
	local b = fakes[i]
	if b then return b end
	b = CreateFrame("Button", nil, UIParent)
	TitanUnits_ButtonOnLoad(b)
	table.remove(buttons)        -- not a real unit: keep it out of the live updates
	b:SetScript("OnEnter", nil)
	b:EnableMouse(false)
	b:SetFrameStrata("MEDIUM")
	fakes[i] = b
	return b
end

local function FillFake(b, i, boss)
	local db = TU.db
	local class = FAKE_CLASSES[(i - 1) % #FAKE_CLASSES + 1]
	local c = RAID_CLASS_COLORS[class] or { r = 0.3, g = 0.75, b = 0.3 }
	local pct = (i * 37) % 70 + 30
	b.unit = nil
	b.name:SetText(i == 1 and (UnitName("player") or "You") or FAKE_NAMES[(i - 2) % #FAKE_NAMES + 1])
	b.name:SetTextColor(1, 1, 1)
	b.hp:SetMinMaxValues(0, 100)
	b.power:SetMinMaxValues(0, 100)
	b.power:SetValue((i * 53) % 100)
	b.power:GetStatusBarTexture():SetVertexColor(class == "WARRIOR" and 0.8 or 0.2, class == "WARRIOR" and 0.2 or 0.4, class == "WARRIOR" and 0.2 or 1)
	local tex = b.hp:GetStatusBarTexture()
	b.status:SetText("")
	if i == 4 then
		b.hp:SetValue(0); b.hpText:SetText(""); b.status:SetText("Dead"); tex:SetVertexColor(0.35, 0.35, 0.38)
	elseif i == 9 then
		b.hp:SetValue(100); b.hpText:SetText(""); b.status:SetText("Offline"); tex:SetVertexColor(0.35, 0.35, 0.38)
	else
		b.hp:SetValue(pct)
		b.hpText:SetText(db.healthText == "percent" and (pct .. "%") or "")
		if db.classColors then tex:SetVertexColor(c.r, c.g, c.b) else
			tex:SetVertexColor(0.25, 0.7, 0.25); b.name:SetTextColor(c.r, c.g, c.b) end
	end
	local aggro = db.aggro and (i == 2 or i == 7) and 1 or 0
	for _, l in ipairs(b.aggro) do l:SetVertexColor(1, 0.15, 0.1); l:SetAlpha(aggro) end
	if boss then
		-- Bosses: red bars; boss 1 is on you (green border), boss 2 is on someone else (red).
		b.name:SetText("Test Boss " .. i)
		b.name:SetTextColor(1, 1, 1)
		b.status:SetText("")
		b.hp:SetValue(pct)
		b.hpText:SetText(db.healthText == "percent" and (pct .. "%") or "")
		tex:SetVertexColor(0.8, 0.15, 0.12)
		b.power:SetValue(100)
		b.power:GetStatusBarTexture():SetVertexColor(0.2, 0.4, 1)
		for _, l in ipairs(b.aggro) do
			if i == 1 then l:SetVertexColor(0.25, 0.9, 0.3) else l:SetVertexColor(0.95, 0.2, 0.15) end
			l:SetAlpha(db.aggro and i <= 2 and 1 or 0)
		end
		for _, l in ipairs(b.targetEdge) do l:SetAlpha(i == 1 and 0.9 or 0) end
		b.v:SetAlpha(1)
		return
	end
	for _, l in ipairs(b.targetEdge) do l:SetAlpha(i == 3 and 0.9 or 0) end
	b.v:SetAlpha(i == 5 and db.rangeAlpha or 1)
end

function TU:ShowTest(mode)
	self.testMode = mode
	for _, b in ipairs(fakes) do b:Hide() end
	if not mode then return end
	local db = self.db
	local w, h, gap = math.floor(db.width), math.floor(db.height), math.floor(db.spacing)
	local home = (mode == "raid" and raidAnchor) or (mode == "boss" and bossAnchor) or anchor
	local count = mode == "raid" and 40 or 5
	for i = 1, count do
		local b = FakeButton(i)
		b:SetParent(home)
		b:SetSize(w, h)
		self:StyleButton(b)
		b:ClearAllPoints()
		if mode == "boss" then
			b:SetPoint("TOPLEFT", home, "TOPLEFT", 0, -(i - 1) * (h + gap + 4))
		elseif mode == "raid" then
			local col, row = math.floor((i - 1) / 5), (i - 1) % 5
			b:SetPoint("TOPLEFT", home, "TOPLEFT", col * (w + gap), -row * (h + gap))
		elseif db.grow == "right" then
			b:SetPoint("TOPLEFT", home, "TOPLEFT", (i - 1) * (w + gap), 0)
		else
			b:SetPoint("TOPLEFT", home, "TOPLEFT", 0, -(i - 1) * (h + gap))
		end
		FillFake(b, i, mode == "boss")
		b:Show()
	end
end

-- /tunits test party | raid | off. Turns on the move boxes too, so you can drag it into place.
function TU:SetTest(mode)
	if mode and InCombatLockdown() then return self:Print("not in combat.") end
	if mode == self.testMode then mode = nil end
	self:ShowTest(mode)
	if mode then
		if self.db.locked then self:SetLocked(false) end
		local what = mode == "boss" and "set of 5 boss frames" or ("full " .. mode)
		local box = mode == "raid" and "blue" or mode == "boss" and "orange" or "green"
		self:Print(("test view: a fake %s. Drag the %s box to place it; /tunits test off (or lock) when done.")
			:format(what, box))
	end
end

function TU:SetLocked(locked)
	if not locked and InCombatLockdown() then return self:Print("can't move frames in combat.") end
	self.db.locked = locked
	if locked and self.testMode then self:ShowTest(nil) end
	self:PlaceMover()
	if not locked then
		self:Print("drag the green box (party), blue box (raid, 8 groups) and orange box (boss frames) where you want them; lock them in /tui when done.")
	end
end

local function CreateMover(label, r, g, b)
	local m = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	m:SetFrameStrata("DIALOG")
	m:SetMovable(true)
	m:EnableMouse(true)
	m:RegisterForDrag("LeftButton")
	m:SetClampedToScreen(true)
	m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	m:SetBackdropColor(r, g, b, 0.25)
	m:SetBackdropBorderColor(r, g, b, 1)
	local t = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	t:SetPoint("BOTTOMLEFT", m, "TOPLEFT", 2, 3)
	t:SetText(label)
	m:SetScript("OnDragStart", function(self)
		if InCombatLockdown() then return end
		self:StartMoving()
	end)
	m:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePos(self)
		TU:ApplyLayout()
	end)
	m:Hide()
	return m
end

---------------------------------------------------------------------------
SLASH_TITANUNITS1 = "/tunits"
SLASH_TITANUNITS2 = "/titanunits"
SlashCmdList.TITANUNITS = function(msg)
	local cmd = strtrim(msg or ""):lower()
	if cmd == "unlock" then
		TU:SetLocked(false)
		TU:SetSoloLocked(false)
	elseif cmd == "lock" then
		TU:SetLocked(true)
		TU:SetSoloLocked(true)
	elseif cmd == "solo" then
		TU.db.showSolo = not TU.db.showSolo
		TU:ApplyLayout()
		TU:Print(TU.db.showSolo and "showing your own frame while solo (handy for setting up)." or "hidden while solo.")
	elseif cmd:match("^test") then
		local m = cmd:match("^test%s*(%a*)")
		if m == "off" then TU:SetTest(nil)
		elseif m == "raid" then TU:SetTest("raid")
		elseif m == "boss" or m == "bosses" then TU:SetTest("boss")
		else TU:SetTest("party") end
	elseif cmd == "reset" then
		TU.db.pos, TU.db.raidPos, TU.db.bossPos = nil, nil, nil
		TU:ApplyLayout()
	else
		TU:Print("/tunits unlock | lock - move the player, target and group frames")
		print("  /tunits solo - show your own frame while solo (to set them up)")
		print("  /tunits test party | raid | boss | off - fake frames to place and size them")
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
		raidAnchor = CreateFrame("Frame", "TitanUnitsRaidAnchor", UIParent)
		raidAnchor:SetSize(10, 10)
		bossAnchor = CreateFrame("Frame", "TitanUnitsBossAnchor", UIParent)
		bossAnchor:SetSize(TU.db.width, 10)
		mover = CreateMover("Party frames  |cffffffff(drag to move)|r", 0.2, 0.8, 0.3)
		raidMover = CreateMover("Raid frames: 8 groups  |cffffffff(drag to move)|r", 0.25, 0.55, 1)
		-- The party box is smaller: keep it on top so both can be grabbed when they overlap.
		mover:SetFrameLevel(raidMover:GetFrameLevel() + 20)
		bossMover = CreateMover("Boss frames  |cffffffff(drag to move)|r", 1, 0.55, 0.1)
		CreateBosses()
		party = Header("TitanUnitsParty", false)
		raid = Header("TitanUnitsRaid", true)
		TU.party, TU.raid = party, raid
		TU:ApplyLayout()
		TU:SetupSolo()
		for e in pairs(UNIT_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
		for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "UNIT_TARGETABLE_CHANGED" }) do
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
	elseif event == "PLAYER_REGEN_DISABLED" then
		if TU.testMode then TU:ShowTest(nil) end
	elseif event == "PLAYER_REGEN_ENABLED" then
		TU:FlushClicks()
		if pendingLayout then TU:ApplyLayout() end
	else
		C_Timer.After(0.2, function() TU:UpdateAll() end)
	end
end)
