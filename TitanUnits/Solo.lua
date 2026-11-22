-- TitanUnits: modern player and target frames.
--
--   [ animated 3D face ][ Name                       60 ]
--   [  class badge      ][ 15.2k / 18.0k          84%   ]   <- health
--   [                   ][ 3.1k / 4.0k                  ]   <- mana / rage / energy
--
-- The target frame is the mirror image, plus level / elite tag, your threat on it
-- (green border = it's attacking you, red = it isn't) and its buffs and debuffs.
-- Both are secure buttons: left-click targets, right-click opens the usual menu.
-- In combat Forever hides exact numbers from addons; the bars and texts are drawn from
-- them directly, so they stay right. Nothing here compares a value that might be hidden.
local ADDON, TU = ...

local TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local SOLO_DEFAULTS = {
	enabled = true,
	hideBlizzard = true,
	portrait = "3d",      -- "3d", "2d" or "class"
	width = 270,
	height = 64,
	scale = 1,
	locked = true,
	threat = true,
	auras = true,
	myDebuffsOnly = false,
	auraSize = 22,
	castbar = true,
	castHeight = 18,
	pos = {},             -- player / target: { x, y } top-left in screen pixels
}

local frames = {}
local curve
local pending = false

local function Secret(v) return issecretvalue and issecretvalue(v) or false end
local function Clean(v, d)
	if Secret(v) then return d end
	if v == nil then return d end
	return v
end

local function AlphaFromBoolean(region, flag, yes, no)
	if region.SetAlphaFromBoolean then
		region:SetAlphaFromBoolean(flag, yes, no)
	elseif not Secret(flag) then
		region:SetAlpha(flag and yes or no)
	end
end

function TU:SoloCfg()
	local db = self.db
	db.solo = type(db.solo) == "table" and db.solo or {}
	for k, v in pairs(SOLO_DEFAULTS) do
		if db.solo[k] == nil then db.solo[k] = type(v) == "table" and {} or v end
	end
	return db.solo
end

local function Percent(unit)
	if curve == nil then
		curve = false
		if C_CurveUtil and C_CurveUtil.CreateCurve then
			local ok, c = pcall(C_CurveUtil.CreateCurve)
			if ok and c then c:AddPoint(0, 0); c:AddPoint(1, 100); curve = c end
		end
	end
	if curve and UnitHealthPercent then return UnitHealthPercent(unit, true, curve) end
	local hp, max = UnitHealth(unit), UnitHealthMax(unit)
	if Secret(hp) or Secret(max) or not max or max == 0 then return nil end
	return hp / max * 100
end

local function Short(n)
	if AbbreviateNumbers then return AbbreviateNumbers(n) end
	if Secret(n) then return "" end
	return tostring(n)
end

---------------------------------------------------------------------------
-- Building a frame
local function Bar(parent, h)
	local b = CreateFrame("StatusBar", nil, parent)
	b:SetStatusBarTexture(TEX)
	b:SetHeight(h)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.55)
	b.left = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.left:SetPoint("LEFT", 6, 0)
	b.right = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.right:SetPoint("RIGHT", -6, 0)
	return b
end

local function Edges(parent, size)
	local t = {}
	for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
		local l = parent:CreateTexture(nil, "OVERLAY")
		l:SetPoint(p[1]); l:SetPoint(p[2])
		if p[3] then l:SetHeight(size) else l:SetWidth(size) end
		l:SetColorTexture(1, 1, 1, 1)
		t[i] = l
	end
	function t:Color(r, g, b, a) for _, l in ipairs(self) do l:SetVertexColor(r, g, b); l:SetAlpha(a or 1) end end
	return t
end

local function Create(unit)
	local mirror = unit == "target"
	local f = CreateFrame("Button", "TitanUnits_" .. unit, UIParent, "SecureUnitButtonTemplate")
	f.unit = unit
	f:SetAttribute("unit", unit)
	f:SetAttribute("*type1", "target")
	f:SetAttribute("*type2", "togglemenu")
	f:RegisterForClicks("AnyUp")
	f:SetMovable(true)
	f:SetClampedToScreen(true)

	local v = CreateFrame("Frame", nil, f, "BackdropTemplate")
	v:SetAllPoints()
	v:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	v:SetBackdropColor(0.05, 0.05, 0.07, 0.85)
	v:SetBackdropBorderColor(0, 0, 0, 1)
	f.v = v

	-- Portrait: a 3D model of the face (animated), with a 2D picture as fallback.
	local pf = CreateFrame("Frame", nil, v, "BackdropTemplate")
	pf:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
	pf:SetBackdropColor(0.1, 0.1, 0.13, 1)
	f.pf = pf
	f.model = CreateFrame("PlayerModel", nil, pf)
	f.model:SetAllPoints()
	f.pic = pf:CreateTexture(nil, "ARTWORK")
	f.pic:SetAllPoints()
	f.pic:SetTexCoord(0.12, 0.88, 0.12, 0.88)
	f.pEdge = Edges(pf, 1)
	f.pEdge:Color(0, 0, 0, 1)
	local over = CreateFrame("Frame", nil, pf)
	over:SetAllPoints()
	over:SetFrameLevel(f.model:GetFrameLevel() + 5)
	f.classIcon = over:CreateTexture(nil, "OVERLAY")
	f.classIcon:SetSize(18, 18)
	f.classIcon:SetPoint(mirror and "BOTTOMRIGHT" or "BOTTOMLEFT", mirror and -2 or 2, 2)
	f.status = over:CreateTexture(nil, "OVERLAY")   -- combat swords / resting
	f.status:SetSize(18, 18)
	f.status:SetPoint(mirror and "TOPRIGHT" or "TOPLEFT", mirror and -1 or 1, -1)
	f.status:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	f.status:Hide()
	f.leader = over:CreateTexture(nil, "OVERLAY")
	f.leader:SetSize(14, 14)
	f.leader:SetPoint("TOP", 0, 6)
	f.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	f.leader:Hide()

	f.name = v:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.name:SetWordWrap(false)
	f.level = v:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.tag = v:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.hp = Bar(v, 20)
	f.power = Bar(v, 12)
	f.power.left:SetFontObject("GameFontHighlightSmall")

	f.edge = Edges(v, 2)           -- threat colour on the target frame
	f.edge:Color(0, 0, 0, 0)
	f.cast = false
	if mirror then
		f.threat = v:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		f.auras = {}
		-- Cast bar under the target frame.
		local cb = CreateFrame("StatusBar", nil, f.v)
		cb:SetStatusBarTexture(TEX)
		local cbg = cb:CreateTexture(nil, "BACKGROUND")
		cbg:SetAllPoints()
		cbg:SetColorTexture(0.05, 0.05, 0.07, 0.85)
		cb.edge = Edges(cb, 1)
		cb.edge:Color(0, 0, 0, 1)
		cb.icon = cb:CreateTexture(nil, "ARTWORK")
		cb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		cb.text:SetPoint("LEFT", 6, 0)
		cb.text:SetPoint("RIGHT", -40, 0)
		cb.text:SetJustifyH("LEFT")
		cb.text:SetWordWrap(false)
		cb.time = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		cb.time:SetPoint("RIGHT", -5, 0)
		cb.shield = cb:CreateTexture(nil, "OVERLAY")
		cb.shield:SetSize(14, 14)
		cb.shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Small-Shield")
		cb.shield:SetAlpha(0)
		cb.token, cb.startT, cb.endT, cb.channel = 0, false, 0, false
		cb:Hide()
		f.cast = cb
	end

	f:HookScript("OnEnter", function(self)
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetUnit(self.unit)
		GameTooltip:Show()
	end)
	f:HookScript("OnLeave", GameTooltip_Hide)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self)
		if not TU:SoloCfg().locked and not InCombatLockdown() then self:StartMoving() end
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local s = self:GetEffectiveScale()
		TU:SoloCfg().pos[self.unit] = { x = self:GetLeft() * s, y = self:GetTop() * s }
		TU:ApplySolo()
	end)
	f.mover = v:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.mover:SetPoint("BOTTOM", f, "TOP", 0, 2)
	f.mover:SetText("|cff4fd15fdrag to move|r")
	f.mover:Hide()
	frames[unit] = f
	return f
end

-- Lay out one frame for the current size (out of combat).
local function Layout(f)
	local c = TU:SoloCfg()
	local mirror = f.unit == "target"
	local w, h = c.width, c.height
	f:SetSize(w, h)
	local ps = h - 6
	f.pf:ClearAllPoints()
	f.pf:SetSize(ps, ps)
	f.pf:SetPoint(mirror and "RIGHT" or "LEFT", mirror and -3 or 3, 0)
	local barH = math.floor((h - 26) * 0.62)
	f.hp:SetHeight(math.max(10, barH))
	f.power:SetHeight(math.max(6, h - 26 - barH - 2))

	local inner = 3 + ps + 6
	f.name:ClearAllPoints(); f.level:ClearAllPoints(); f.tag:ClearAllPoints()
	f.hp:ClearAllPoints(); f.power:ClearAllPoints()
	if mirror then
		f.name:SetPoint("TOPRIGHT", -inner, -5)
		f.name:SetPoint("LEFT", 60, 0)
		f.name:SetJustifyH("RIGHT")
		f.level:SetPoint("TOPLEFT", 8, -6)
		f.tag:SetPoint("LEFT", f.level, "RIGHT", 4, 0)
		f.hp:SetPoint("TOPLEFT", 6, -22)
		f.hp:SetPoint("RIGHT", -inner, 0)
		f.threat:ClearAllPoints()
		f.threat:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 2, 3)
	else
		f.name:SetPoint("TOPLEFT", inner, -5)
		f.name:SetPoint("RIGHT", -40, 0)
		f.name:SetJustifyH("LEFT")
		f.level:SetPoint("TOPRIGHT", -8, -6)
		f.tag:SetPoint("RIGHT", f.level, "LEFT", -4, 0)
		f.hp:SetPoint("TOPLEFT", inner, -22)
		f.hp:SetPoint("RIGHT", -6, 0)
	end
	f.power:SetPoint("TOPLEFT", f.hp, "BOTTOMLEFT", 0, -2)
	f.power:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", 0, -2)

	f:SetScale(c.scale)
	f:ClearAllPoints()
	local p = c.pos[f.unit]
	if p then
		local s = f:GetEffectiveScale()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x / s, p.y / s)
	elseif mirror then
		f:SetPoint("TOPLEFT", UIParent, "CENTER", 60, -170)
	else
		f:SetPoint("TOPRIGHT", UIParent, "CENTER", -60, -170)
	end
	f.mover:SetShown(not c.locked)
	if f.cast then
		local ch = c.castHeight
		f.cast:ClearAllPoints()
		f.cast:SetHeight(ch)
		f.cast:SetPoint("TOPLEFT", f, "BOTTOMLEFT", ch + 2, -3)
		f.cast:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -3)
		f.cast.icon:ClearAllPoints()
		f.cast.icon:SetSize(ch, ch)
		f.cast.icon:SetPoint("RIGHT", f.cast, "LEFT", -2, 0)
		f.cast.shield:ClearAllPoints()
		f.cast.shield:SetPoint("CENTER", f.cast.icon, "CENTER")
	end
end

---------------------------------------------------------------------------
-- Updates
local function ClassFile(unit)
	if not UnitIsPlayer(unit) then return nil end
	local ok, _, class = pcall(UnitClass, unit)
	if ok and not Secret(class) then return class end
end

local function SetClassIcon(tex, class)
	if not class then tex:Hide() return end
	local atlas = "classicon-" .. class:lower()
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
		tex:SetAtlas(atlas)
	elseif CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
		tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
		tex:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))
	else
		tex:Hide() return
	end
	tex:Show()
end

function TU:SoloPortrait(f)
	local c = self:SoloCfg()
	local u = f.unit
	local class = ClassFile(u)
	if c.portrait == "class" and class then
		f.model:Hide()
		f.pic:SetTexCoord(0, 1, 0, 1)
		SetClassIcon(f.pic, class)
		f.pic:Show()
		f.classIcon:Hide()
		return
	end
	f.pic:SetTexCoord(0.12, 0.88, 0.12, 0.88)
	SetClassIcon(f.classIcon, class)
	-- The 3D model needs the unit to be loaded nearby; otherwise use the 2D picture.
	local visible = Clean(UnitIsVisible(u), false)
	if c.portrait == "3d" and visible then
		f.pic:Hide()
		f.model:Show()
		f.model:ClearModel()
		f.model:SetUnit(u)
		f.model:SetPortraitZoom(1)
		f.model:SetCamDistanceScale(1)
		f.model:SetPosition(0, 0, 0)
	else
		f.model:Hide()
		SetPortraitTexture(f.pic, u)
		f.pic:Show()
	end
end

local function UnitColor(u)
	local class = ClassFile(u)
	if class and RAID_CLASS_COLORS[class] then
		local cc = RAID_CLASS_COLORS[class]
		return cc.r, cc.g, cc.b
	end
	if Clean(UnitIsTapDenied(u), false) then return 0.5, 0.5, 0.5 end
	local r = Clean(UnitReaction(u, "player"), nil)
	if r then
		if r <= 3 then return 0.85, 0.2, 0.15 end
		if r == 4 then return 0.95, 0.8, 0.2 end
		return 0.25, 0.75, 0.3
	end
	return 0.3, 0.75, 0.3
end

function TU:SoloHealth(f)
	local u = f.unit
	f.hp:SetMinMaxValues(0, UnitHealthMax(u))
	f.hp:SetValue(UnitHealth(u))
	local dead = Clean(UnitIsDeadOrGhost(u), false)
	if dead then
		f.hp.left:SetText("Dead")
		f.hp.right:SetText("")
		f.hp:GetStatusBarTexture():SetVertexColor(0.35, 0.35, 0.38)
		return
	end
	f.hp.left:SetFormattedText("%s / %s", Short(UnitHealth(u)), Short(UnitHealthMax(u)))
	if not pcall(f.hp.right.SetFormattedText, f.hp.right, "%.0f%%", Percent(u)) then f.hp.right:SetText("") end
	f.hp:GetStatusBarTexture():SetVertexColor(UnitColor(u))
end

function TU:SoloPower(f)
	local u = f.unit
	local max = UnitPowerMax(u)
	f.power:SetMinMaxValues(0, max)
	f.power:SetValue(UnitPower(u))
	local ok, ptype = pcall(UnitPowerType, u)
	local col = ok and not Secret(ptype) and PowerBarColor and PowerBarColor[ptype]
	if col then f.power:GetStatusBarTexture():SetVertexColor(col.r, col.g, col.b)
	else f.power:GetStatusBarTexture():SetVertexColor(0.2, 0.4, 1) end
	f.power.left:SetFormattedText("%s / %s", Short(UnitPower(u)), Short(max))
	local m = Clean(max, 1)
	f.power:SetShown(m ~= 0)
end

function TU:SoloInfo(f)
	local u = f.unit
	f.name:SetText(UnitName(u))
	local r, g, b = UnitColor(u)
	f.name:SetTextColor(r, g, b)
	local lvl = Clean(UnitLevel(u), nil)
	if lvl == -1 then
		f.level:SetText("|cffff3030??|r")
	elseif lvl then
		local c = GetCreatureDifficultyColor and f.unit == "target" and GetCreatureDifficultyColor(lvl)
		f.level:SetText(lvl)
		if c then f.level:SetTextColor(c.r, c.g, c.b) else f.level:SetTextColor(1, 1, 1) end
	else
		f.level:SetText("")
	end
	local tag = ""
	if f.unit == "target" then
		local cls = Clean(UnitClassification(u), "normal")
		tag = (cls == "worldboss" and "|cffff4040Boss|r") or (cls == "rareelite" and "|cffc0c0ffRare Elite|r")
			or (cls == "elite" and "|cffffd200Elite|r") or (cls == "rare" and "|cffc0c0ffRare|r") or ""
	else
		if Clean(UnitAffectingCombat("player"), false) then
			f.status:SetTexCoord(0.5, 1, 0, 0.5); f.status:Show()
		elseif IsResting() then
			f.status:SetTexCoord(0, 0.5, 0, 0.421875); f.status:Show()
		else
			f.status:Hide()
		end
		f.leader:SetShown(UnitIsGroupLeader("player") and IsInGroup())
	end
	f.tag:SetText(tag)
end

-- Target only: your threat on it. Green border while it's attacking you, red when it isn't.
function TU:SoloThreat(f)
	local c = self:SoloCfg()
	if f.unit ~= "target" then return end
	if not c.threat or not Clean(UnitCanAttack("player", "target"), false) then
		f.edge:Color(0, 0, 0, 0)
		f.threat:SetText("")
		return
	end
	local ok, isTanking, status, pct = pcall(UnitDetailedThreatSituation, "player", "target")
	if not ok or (not Secret(isTanking) and isTanking == nil) then
		f.edge:Color(0, 0, 0, 0)
		f.threat:SetText("")
		return
	end
	for _, l in ipairs(f.edge) do
		if l.SetVertexColorFromBoolean then
			l:SetVertexColorFromBoolean(isTanking, CreateColor(0.25, 0.9, 0.3, 1), CreateColor(0.95, 0.2, 0.15, 1))
		elseif not Secret(isTanking) then
			if isTanking then l:SetVertexColor(0.25, 0.9, 0.3) else l:SetVertexColor(0.95, 0.2, 0.15) end
		end
		l:SetAlpha(1)
	end
	if not pcall(f.threat.SetFormattedText, f.threat, "Threat %.0f%%", pct) then f.threat:SetText("") end
end

-- Target's debuffs (first row) and buffs (second row).
local function AuraButton(f, i)
	local a = f.auras[i]
	if a then return a end
	a = CreateFrame("Frame", nil, f.v)
	a.icon = a:CreateTexture(nil, "ARTWORK")
	a.icon:SetAllPoints()
	a.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	a.count = a:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	a.count:SetPoint("BOTTOMRIGHT", 2, -1)
	a.time = a:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	a.time:SetPoint("TOP", a, "BOTTOM", 0, -1)
	a.edge = Edges(a, 1)
	a:EnableMouse(true)
	a:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		if self.auraID and GameTooltip.SetUnitAuraByAuraInstanceID then
			pcall(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, "target", self.auraID)
		end
		GameTooltip:Show()
	end)
	a:SetScript("OnLeave", GameTooltip_Hide)
	a:SetScript("OnUpdate", function(self)
		if self.expires then
			local left = self.expires - GetTime()
			self.time:SetText(left > 0 and (left >= 60 and (math.floor(left / 60 + 0.5) .. "m") or math.floor(left + 0.5)) or "")
		end
	end)
	f.auras[i] = a
	return a
end

function TU:SoloAuras(f)
	if f.unit ~= "target" then return end
	local c = self:SoloCfg()
	local size, n = c.auraSize, 0
	local perRow = math.max(1, math.floor(c.width / (size + 3)))
	local function Row(filter, row, max, harmful)
		local col = 0
		if not c.auras or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
		for i = 1, 40 do
			if col >= max then break end
			local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "target", i, filter)
			if not ok or Secret(aura) or aura == nil then break end
			n = n + 1
			col = col + 1
			local a = AuraButton(f, n)
			a:SetSize(size, size)
			a:ClearAllPoints()
			local down = c.castbar and (c.castHeight + 6) or 0   -- leave room for the cast bar
			a:SetPoint("TOPLEFT", f, "BOTTOMLEFT", (col - 1) * (size + 3), -4 - down - row * (size + 14))
			a.icon:SetTexture(aura.icon)
			local stacks = aura.applications
			if not Secret(stacks) and stacks ~= nil and stacks > 1 then a.count:SetText(stacks) else a.count:SetText("") end
			local exp = aura.expirationTime
			a.expires = (not Secret(exp) and exp ~= nil and exp > 0) and exp or nil
			if not a.expires then a.time:SetText("") end
			a.auraID = not Secret(aura.auraInstanceID) and aura.auraInstanceID or nil
			if harmful then a.edge:Color(0.8, 0.1, 0.1, 1) else a.edge:Color(0, 0, 0, 1) end
			a:Show()
		end
	end
	Row(c.myDebuffsOnly and "HARMFUL|PLAYER" or "HARMFUL", 0, perRow, true)
	local debuffs = n
	Row("HELPFUL", debuffs > 0 and 1 or 0, perRow, false)
	for i = n + 1, #f.auras do f.auras[i]:Hide() end
end

---------------------------------------------------------------------------
-- Target cast bar.
-- Best case the cast's start/end times are readable and the bar fills smoothly. If the game
-- hides them, it tries the game's own timer; if that's refused too, the bar shows the spell
-- name and icon (full) so you still see what's coming.
local ORANGE, GREY = CreateColor(1, 0.7, 0.1, 1), CreateColor(0.6, 0.6, 0.65, 1)
local SHIELD_ON = 1

local function CastOnUpdate(cb)
	if not cb.startT then return end
	local now = GetTime()
	local total = cb.endT - cb.startT
	if total <= 0 then return end
	local p = (now - cb.startT) / total
	if p >= 1 then cb:Hide() return end
	cb:SetValue(cb.channel and (1 - p) or p)
	cb.time:SetFormattedText("%.1f", cb.endT - now)
end

function TU:SoloCast(f, event)
	local cb = f and f.cast
	if not cb then return end
	local c = self:SoloCfg()
	if not c.castbar then cb:Hide() return end
	if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
		cb:SetScript("OnUpdate", nil)
		cb.startT = false
		cb:SetMinMaxValues(0, 1)
		cb:SetValue(1)
		cb:GetStatusBarTexture():SetVertexColor(0.9, 0.15, 0.1)
		cb.text:SetText(event == "UNIT_SPELLCAST_INTERRUPTED" and "Interrupted" or "Failed")
		cb.time:SetText("")
		cb.token = cb.token + 1
		local token = cb.token
		C_Timer.After(0.6, function() if cb.token == token then cb:Hide() end end)
		return
	end
	local channel = false
	local name, text, tex, startMs, endMs, _, _, notInt = UnitCastingInfo("target")
	if not Secret(name) and name == nil then
		name, text, tex, startMs, endMs, _, notInt = UnitChannelInfo("target")
		channel = true
	end
	if not Secret(name) and name == nil then
		cb:SetScript("OnUpdate", nil)
		cb.startT = false
		cb:Hide()
		return
	end
	cb.token = cb.token + 1
	cb.channel = channel
	cb.text:SetText(text or name)
	cb.icon:SetTexture(tex)
	-- Orange = can be interrupted, grey with a shield = can't.
	local bar = cb:GetStatusBarTexture()
	if Secret(notInt) then
		if bar.SetVertexColorFromBoolean then bar:SetVertexColorFromBoolean(notInt, GREY, ORANGE) end
		AlphaFromBoolean(cb.shield, notInt, SHIELD_ON, 0)
	elseif notInt then
		bar:SetVertexColor(GREY:GetRGB()); cb.shield:SetAlpha(SHIELD_ON)
	else
		bar:SetVertexColor(ORANGE:GetRGB()); cb.shield:SetAlpha(0)
	end
	cb:SetMinMaxValues(0, 1)
	cb.time:SetText("")
	if not Secret(startMs) and not Secret(endMs) and startMs and endMs then
		cb.startT, cb.endT = startMs / 1000, endMs / 1000
		cb:SetScript("OnUpdate", CastOnUpdate)
		CastOnUpdate(cb)
	else
		cb.startT = false
		cb:SetScript("OnUpdate", nil)
		local ok = false
		local getDur = channel and UnitChannelDuration or UnitCastingDuration
		if getDur and cb.SetTimerDuration then
			local dir = Enum and Enum.StatusBarTimerDirection
			ok = pcall(function()
				cb:SetTimerDuration(getDur("target"), nil, dir and (channel and dir.RemainingTime or dir.ElapsedTime) or nil)
			end)
		end
		if not ok then cb:SetValue(1) end
	end
	cb:Show()
end

function TU:SoloUpdate(f, what)
	if not f or not UnitExists(f.unit) then return end
	local list = what and { what } or { "SoloPortrait", "SoloHealth", "SoloPower", "SoloInfo", "SoloThreat", "SoloAuras", "SoloCast" }
	for _, m in ipairs(list) do
		local ok, err = pcall(self[m], self, f)
		if not ok and not self.soloWarned then
			self.soloWarned = true
			self:Print("player/target frame error (please send this): " .. tostring(err))
		end
	end
end

---------------------------------------------------------------------------
-- Blizzard's frames, showing/hiding, layout
local hider = CreateFrame("Frame")
hider:Hide()
local origParent = {}

local function Blizzard(hide)
	for _, n in ipairs({ "PlayerFrame", "TargetFrame" }) do
		local f = _G[n]
		if f then
			if hide and f:GetParent() ~= hider then
				origParent[f] = f:GetParent()
				-- The pet frame hangs off the player frame: keep it visible.
				if n == "PlayerFrame" and PetFrame and PetFrame:GetParent() == f then PetFrame:SetParent(UIParent) end
				f:SetParent(hider)
			elseif not hide and f:GetParent() == hider then
				f:SetParent(origParent[f] or UIParent)
			end
		end
	end
end

function TU:ApplySolo()
	if not frames.player then return end
	if InCombatLockdown() then pending = true return end
	pending = false
	local c = self:SoloCfg()
	for _, f in pairs(frames) do Layout(f) end
	if c.enabled then
		frames.player:Show()
		RegisterUnitWatch(frames.target)
	else
		frames.player:Hide()
		UnregisterUnitWatch(frames.target)
		frames.target:Hide()
	end
	Blizzard(c.enabled and c.hideBlizzard)
	for _, f in pairs(frames) do self:SoloUpdate(f) end
end

function TU:SetupSolo()
	self:SoloCfg()
	Create("player")
	Create("target")
	-- Blizzard re-parents its frames now and then (e.g. vehicles); put them back.
	for _, n in ipairs({ "PlayerFrame", "TargetFrame" }) do
		local bf = _G[n]
		if bf then
			hooksecurefunc(bf, "SetParent", function(_, p)
				local c = TU:SoloCfg()
				if p ~= hider and c.enabled and c.hideBlizzard then
					C_Timer.After(0, function() if not InCombatLockdown() then Blizzard(true) end end)
				end
			end)
		end
	end
	self:ApplySolo()

	local ev = CreateFrame("Frame")
	local UNIT = {
		UNIT_HEALTH = "SoloHealth", UNIT_MAXHEALTH = "SoloHealth",
		UNIT_POWER_UPDATE = "SoloPower", UNIT_MAXPOWER = "SoloPower", UNIT_DISPLAYPOWER = "SoloPower",
		UNIT_NAME_UPDATE = "SoloInfo", UNIT_LEVEL = "SoloInfo", UNIT_FACTION = "SoloInfo", UNIT_CLASSIFICATION_CHANGED = "SoloInfo",
		UNIT_PORTRAIT_UPDATE = "SoloPortrait", UNIT_MODEL_CHANGED = "SoloPortrait",
		UNIT_THREAT_LIST_UPDATE = "SoloThreat", UNIT_THREAT_SITUATION_UPDATE = "SoloThreat",
		UNIT_AURA = "SoloAuras",
		UNIT_SPELLCAST_START = "SoloCast", UNIT_SPELLCAST_STOP = "SoloCast", UNIT_SPELLCAST_DELAYED = "SoloCast",
		UNIT_SPELLCAST_FAILED = "SoloCast", UNIT_SPELLCAST_INTERRUPTED = "SoloCast",
		UNIT_SPELLCAST_CHANNEL_START = "SoloCast", UNIT_SPELLCAST_CHANNEL_STOP = "SoloCast",
		UNIT_SPELLCAST_CHANNEL_UPDATE = "SoloCast",
		UNIT_SPELLCAST_INTERRUPTIBLE = "SoloCast", UNIT_SPELLCAST_NOT_INTERRUPTIBLE = "SoloCast",
	}
	for e in pairs(UNIT) do pcall(ev.RegisterUnitEvent or ev.RegisterEvent, ev, e, "player", "target") end
	for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
		"PLAYER_UPDATE_RESTING", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PARTY_LEADER_CHANGED" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function(_, event, unit)
		local m = UNIT[event]
		if m == "SoloCast" then
			if unit == "target" then
				local ok, err = pcall(TU.SoloCast, TU, frames.target, event)
				if not ok and not TU.soloWarned then
					TU.soloWarned = true
					TU:Print("cast bar error (please send this): " .. tostring(err))
				end
			end
		elseif m then
			if frames[unit] then TU:SoloUpdate(frames[unit], m) end
			if m == "SoloThreat" or (m == "SoloHealth" and unit ~= "target") then
				TU:SoloUpdate(frames.target, "SoloThreat")
			end
		elseif event == "PLAYER_TARGET_CHANGED" then
			TU:SoloUpdate(frames.target)
		elseif event == "PLAYER_REGEN_ENABLED" and pending then
			TU:ApplySolo()
		else
			TU:SoloUpdate(frames.player, "SoloInfo")
			if event == "PLAYER_ENTERING_WORLD" then
				TU:SoloUpdate(frames.player)
				TU:SoloUpdate(frames.target)
			end
		end
	end)
	-- A unit that comes into view gets its 3D face then; recheck now and then.
	C_Timer.NewTicker(2, function()
		for _, f in pairs(frames) do
			if f:IsVisible() and TU:SoloCfg().portrait == "3d" and not f.model:IsShown() then
				TU:SoloUpdate(f, "SoloPortrait")
			end
		end
	end)
end

function TU:SetSoloLocked(locked)
	if not locked and InCombatLockdown() then return self:Print("can't move frames in combat.") end
	self:SoloCfg().locked = locked
	self:ApplySolo()
end
