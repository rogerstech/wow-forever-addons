-- TitanTools: saved settings, movers, the settings window and slash commands.
local ADDON, TT = ...
_G.TitanTools = TT

local DEFAULTS = {
	reminder = { enabled = true, bearWarning = true, lowTime = true, scale = 1 },
	tot = { enabled = true, scale = 1 },
	vendor = { repair = true, junk = true },
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

local function Build()
	frame = CreateFrame("Frame", "TitanToolsConfig", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(320, 360)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	tinsert(UISpecialFrames, "TitanToolsConfig")

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("TOP", 0, -5)
	frame.title:SetText("TitanTools")

	local r, t, v = TT.db.reminder, TT.db.tot, TT.db.vendor
	Heading(frame, "Buff reminder", -34)
	MakeCheck(frame, "Show missing buffs (out of combat)", -56,
		function() return r.enabled end, function(on) r.enabled = on; TT:UpdateReminders() end)
	MakeCheck(frame, "Also warn when a buff has under 1 min left", -80,
		function() return r.lowTime end, function(on) r.lowTime = on; TT:UpdateReminders() end)
	MakeCheck(frame, "Warn in group combat when not in Bear Form", -104,
		function() return r.bearWarning end, function(on) r.bearWarning = on; TT:UpdateReminders() end)

	Heading(frame, "Target of target", -138)
	MakeCheck(frame, "Show target-of-target frame", -160,
		function() return t.enabled end, function(on) t.enabled = on; TT:UpdateToTEnabled() end)

	Heading(frame, "Vendors", -194)
	MakeCheck(frame, "Repair all gear automatically", -216,
		function() return v.repair end, function(on) v.repair = on end)
	MakeCheck(frame, "Sell grey (junk) items automatically", -240,
		function() return v.junk end, function(on) v.junk = on end)

	frame.lockBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.lockBtn:SetSize(110, 22)
	frame.lockBtn:SetPoint("TOPLEFT", 18, -276)
	frame.lockBtn:SetScript("OnClick", function() TT:SetUnlocked(not TT.unlocked) end)

	local help = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	help:SetPoint("TOPLEFT", 22, -306)
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
