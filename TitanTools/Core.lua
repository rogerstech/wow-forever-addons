-- TitanTools: saved settings, movers, the settings window and slash commands.
local ADDON, TT = ...
_G.TitanTools = TT

local DEFAULTS = {
	reminder = { enabled = true, bearWarning = true, lowTime = true, scale = 1 },
	tot = { enabled = true, scale = 1 },
	aggro = { enabled = true, groupOnly = false },
	vendor = { repair = true, junk = true },
	quest = { enabled = true },
}

local function Merge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = type(dst[k]) == "table" and dst[k] or {}
			Merge(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function TT:Print(msg)
	print("|cff33ccffTitanTools|r: " .. msg)
end

-- The client can hand addons "secret" values in combat (health, who is who).
-- Blizzard's widgets accept them directly; plain Lua can't test them.
local function IsSecret(v)
	return issecretvalue and issecretvalue(v)
end

function TT.ColorFromBoolean(tex, flag, yes, no)
	if tex.SetVertexColorFromBoolean then
		tex:SetVertexColorFromBoolean(flag, yes, no)
	elseif not IsSecret(flag) then
		tex:SetVertexColor((flag and yes or no):GetRGBA())
	end
end

function TT.AlphaFromBoolean(region, flag, ifTrue, ifFalse)
	if region.SetAlphaFromBoolean then
		region:SetAlphaFromBoolean(flag, ifTrue, ifFalse)
	elseif not IsSecret(flag) then
		region:SetAlpha(flag and ifTrue or ifFalse)
	end
end

-- Anything touching secure frames must wait until combat ends.
local pending = {}
function TT:RunOutOfCombat(key, fn)
	if InCombatLockdown() then
		pending[key] = fn
	else
		fn()
	end
end

---------------------------------------------------------------------------
-- Movers: /ttools unlock shows a box over each frame. Drag to move, wheel to resize.
-- Positions are the frame centre in UIParent units, so scale changes don't drift.
---------------------------------------------------------------------------
TT.movables = {}

function TT:ApplyPosition(m)
	local f, cfg = m.frame, self.db[m.key]
	local scale = cfg.scale or 1
	f:SetScale(scale)
	f:ClearAllPoints()
	if cfg.pos then
		f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cfg.pos.x / scale, cfg.pos.y / scale)
	else
		f:SetPoint(unpack(m.default))
	end
end

function TT:RegisterMovable(frame, key, label, default)
	local m = { frame = frame, key = key, label = label, default = default }
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	table.insert(self.movables, m)

	local box = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	box:SetAllPoints(frame)
	box:SetFrameStrata("DIALOG")
	box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	box:SetBackdropColor(0.2, 0.8, 0.3, 0.4)
	box:SetBackdropBorderColor(0.4, 1, 0.5, 1)
	box.label = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	box.label:SetPoint("CENTER")
	box.label:SetText(label)
	box:EnableMouse(true)
	box:EnableMouseWheel(true)
	box:RegisterForDrag("LeftButton")
	box:SetScript("OnDragStart", function()
		if not InCombatLockdown() then frame:StartMoving() end
	end)
	box:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		frame:SetUserPlaced(false)
		local x, y = frame:GetCenter()
		local s = frame:GetScale()
		TT.db[key].pos = { x = x * s, y = y * s }
		TT:RunOutOfCombat("pos" .. key, function() TT:ApplyPosition(m) end)
	end)
	box:SetScript("OnMouseWheel", function(_, delta)
		if InCombatLockdown() then return end
		local cfg = TT.db[key]
		if not cfg.pos then
			local x, y = frame:GetCenter()
			cfg.pos = { x = x * frame:GetScale(), y = y * frame:GetScale() }
		end
		local step = IsShiftKeyDown() and 0.01 or 0.05
		cfg.scale = math.max(0.3, math.min(3, math.floor(((cfg.scale or 1) + delta * step) * 100 + 0.5) / 100))
		TT:ApplyPosition(m)
		box.label:SetText(("%s  %d%%"):format(label, cfg.scale * 100 + 0.5))
	end)
	box:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" and not InCombatLockdown() then
			TT.db[key].pos, TT.db[key].scale = nil, 1
			TT:ApplyPosition(m)
		end
	end)
	box:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(label)
		GameTooltip:AddLine("Drag to move", 1, 1, 1)
		GameTooltip:AddLine("Mouse wheel to resize (Shift for fine steps)", 1, 1, 1)
		GameTooltip:AddLine("Right-click to reset", 1, 1, 1)
		GameTooltip:Show()
	end)
	box:SetScript("OnLeave", function() GameTooltip:Hide() end)
	box:Hide()
	m.box = box
	self:RunOutOfCombat("pos" .. key, function() TT:ApplyPosition(m) end)
	return m
end

function TT:SetUnlocked(on)
	if on and InCombatLockdown() then
		self:Print("Can't move frames in combat.")
		return
	end
	self.unlocked = on
	for _, m in ipairs(self.movables) do m.box:SetShown(on) end
	-- Modules show a placeholder while unlocked so there is something to drag.
	if self.UpdateReminders then self:UpdateReminders() end
	if self.UpdateToTUnlocked then self:UpdateToTUnlocked() end
	if self.RefreshConfig then self:RefreshConfig() end
	self:Print(on and "Unlocked. Drag the green boxes, mouse wheel to resize, /ttools lock when done." or "Locked.")
end

---------------------------------------------------------------------------
-- Settings window
---------------------------------------------------------------------------
local frame
local controls = {}

local function MakeCheck(parent, label, y, get, set)
	local c = CreateFrame("CheckButton", nil, parent)
	c:SetSize(24, 24)
	c:SetPoint("TOPLEFT", 18, y)
	c:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	c:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	c:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	c:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	c.text:SetPoint("LEFT", c, "RIGHT", 4, 0)
	c.text:SetText(label)
	c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	c.Refresh = function() c:SetChecked(get()) end
	table.insert(controls, c)
	return c
end

local function Heading(parent, text, y)
	local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	h:SetPoint("TOPLEFT", 20, y)
	h:SetText(text)
end

-- Settings window whose contents scroll when the screen is too short to fit them.
-- Controls go on window.content; call window:Fit() each time it opens.
local function MakeScrollWindow(name, width, contentHeight)
	local f = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
	f:SetWidth(width)
	f:SetPoint("CENTER")
	f:SetFrameStrata("HIGH")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, name)

	local scroll = CreateFrame("ScrollFrame", nil, f)
	scroll:SetPoint("TOPLEFT", 4, -26)
	scroll:SetPoint("BOTTOMRIGHT", -22, 6)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(width - 26, contentHeight)
	scroll:SetScrollChild(content)
	f.content = content

	local bar = CreateFrame("Slider", nil, f, "BackdropTemplate")
	bar:SetPoint("TOPRIGHT", -8, -30)
	bar:SetPoint("BOTTOMRIGHT", -8, 10)
	bar:SetWidth(10)
	bar:SetOrientation("VERTICAL")
	bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
	bar:SetBackdropColor(0, 0, 0, 0.5)
	bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
	bar:GetThumbTexture():SetVertexColor(0.7, 0.7, 0.7, 0.9)
	bar:GetThumbTexture():SetSize(10, 40)
	bar:SetValueStep(1)
	bar:SetScript("OnValueChanged", function(_, v) scroll:SetVerticalScroll(v) end)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(_, delta) bar:SetValue(bar:GetValue() - delta * 40) end)

	function f:Fit()
		local h = math.min(contentHeight + 32, math.floor(UIParent:GetHeight() - 60))
		self:SetHeight(h)
		local range = math.max(0, contentHeight - (h - 32))
		bar:SetMinMaxValues(0, range)
		bar:SetValue(math.min(bar:GetValue(), range))
		scroll:SetVerticalScroll(bar:GetValue())
		bar:SetShown(range > 0)
	end
	return f
end

local function Build()
	frame = MakeScrollWindow("TitanToolsConfig", 346, 500)
	local c = frame.content

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("TOP", 0, -5)
	frame.title:SetText("TitanTools")

	local r, t, v = TT.db.reminder, TT.db.tot, TT.db.vendor
	Heading(c, "Buff reminder", -8)
	MakeCheck(c, "Show missing buffs (out of combat)", -30,
		function() return r.enabled end, function(on) r.enabled = on; TT:UpdateReminders() end)
	MakeCheck(c, "Also warn when a buff has under 1 min left", -54,
		function() return r.lowTime end, function(on) r.lowTime = on; TT:UpdateReminders() end)
	MakeCheck(c, "Warn in group combat when not in Bear Form", -78,
		function() return r.bearWarning end, function(on) r.bearWarning = on; TT:UpdateReminders() end)

	Heading(c, "Target of target", -112)
	MakeCheck(c, "Show target-of-target frame", -134,
		function() return t.enabled end, function(on) t.enabled = on; TT:UpdateToTEnabled() end)

	local a = TT.db.aggro
	Heading(c, "Nameplate aggro colours", -168)
	MakeCheck(c, "Green = mob on you, red = on someone else", -190,
		function() return a.enabled end, function(on) a.enabled = on; TT:UpdateAggro() end)
	MakeCheck(c, "Only while in a group", -214,
		function() return a.groupOnly end, function(on) a.groupOnly = on; TT:UpdateAggro() end)

	Heading(c, "Vendors", -248)
	MakeCheck(c, "Repair all gear automatically", -270,
		function() return v.repair end, function(on) v.repair = on end)
	MakeCheck(c, "Sell grey (junk) items automatically", -294,
		function() return v.junk end, function(on) v.junk = on end)

	local q = TT.db.quest
	Heading(c, "Quests", -328)
	MakeCheck(c, "Accept and turn in quests (hold Shift to skip)", -350,
		function() return q.enabled end, function(on) q.enabled = on end)

	frame.lockBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
	frame.lockBtn:SetSize(110, 22)
	frame.lockBtn:SetPoint("TOPLEFT", 18, -386)
	frame.lockBtn:SetScript("OnClick", function() TT:SetUnlocked(not TT.unlocked) end)

	local help = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	help:SetPoint("TOPLEFT", 22, -416)
	help:SetWidth(280)
	help:SetJustifyH("LEFT")
	help:SetText("Unlock, then drag the reminder and target-of-target frames; mouse wheel to resize, right-click to reset.")
end

function TT:RefreshConfig()
	if not frame or not frame:IsShown() then return end
	for _, c in ipairs(controls) do c.Refresh() end
	frame.lockBtn:SetText(self.unlocked and "Lock frames" or "Unlock frames")
end

function TT:ToggleConfig()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		if not frame then Build() end
		frame:Fit()
		frame:Show()
		self:RefreshConfig()
	end
end

if Settings and Settings.RegisterCanvasLayoutCategory then
	local panel = CreateFrame("Frame")
	local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	open:SetSize(200, 26)
	open:SetPoint("TOPLEFT", 16, -16)
	open:SetText("Open TitanTools settings")
	open:SetScript("OnClick", function()
		if SettingsPanel then HideUIPanel(SettingsPanel) end
		TT:ToggleConfig()
	end)
	local category = Settings.RegisterCanvasLayoutCategory(panel, "TitanTools")
	Settings.RegisterAddOnCategory(category)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		TitanToolsDB = TitanToolsDB or {}
		Merge(TitanToolsDB, DEFAULTS)
		TT.db = TitanToolsDB
	elseif event == "PLAYER_LOGIN" then
		TT:SetupReminders()
		TT:SetupToT()
		TT:SetupVendor()
		TT:SetupAggro()
		TT:SetupQuests()
		TT:SetupMail()
	elseif event == "PLAYER_REGEN_DISABLED" then
		if TT.unlocked then TT:SetUnlocked(false) end
	elseif event == "PLAYER_REGEN_ENABLED" then
		for key, fn in pairs(pending) do
			pending[key] = nil
			fn()
		end
	end
end)

SLASH_TITANTOOLS1 = "/ttools"
SLASH_TITANTOOLS2 = "/titantools"
SlashCmdList.TITANTOOLS = function(msg)
	local cmd = strtrim(msg or ""):lower()
	if cmd == "unlock" then
		TT:SetUnlocked(true)
	elseif cmd == "lock" then
		TT:SetUnlocked(false)
	elseif cmd == "" or cmd == "config" then
		TT:ToggleConfig()
	else
		TT:Print("/ttools  - settings window")
		TT:Print("/ttools unlock  - move and resize the reminder and target-of-target frames")
		TT:Print("/ttools lock  - lock them")
	end
end
