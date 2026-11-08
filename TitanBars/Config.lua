-- TitanBars: the settings window (/tb).
local ADDON, TB = ...

local frame
local selected = 1
local controls = {}
local refreshing = false

local function Cfg() return TB.db.bars[selected] end

local function Changed()
	TB:RefreshBar(selected)
end

local function Percent(v) return ("%d%%"):format(v * 100 + 0.5) end
local function Whole(v) return tostring(math.floor(v + 0.5)) end

-- source returns the settings table to edit (the selected bar by default);
-- fallback gives the value to show when the setting isn't set yet.
local function MakeSlider(parent, label, minV, maxV, step, fmt, y, field, source, onChange, fallback)
	source, onChange = source or Cfg, onChange or Changed
	local s = CreateFrame("Slider", nil, parent, "UISliderTemplateWithLabels")
	s:SetPoint("TOPLEFT", 24, y)
	s:SetSize(272, 17)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s.Low:SetText(fmt(minV))
	s.High:SetText(fmt(maxV))
	s:SetScript("OnValueChanged", function(self, v)
		self.Text:SetText(label .. ": " .. fmt(v))
		if refreshing then return end
		if step >= 1 then v = math.floor(v + 0.5) end
		source()[field] = v
		onChange()
	end)
	s.Refresh = function()
		local v = source()[field] or (fallback and fallback()) or 1
		s:SetValue(v)
		s.Text:SetText(label .. ": " .. fmt(v))
	end
	table.insert(controls, s)
	return s
end

local function MakeCheck(parent, label, x, y, get, set)
	local c = CreateFrame("CheckButton", nil, parent)
	c:SetSize(24, 24)
	c:SetPoint("TOPLEFT", x, y)
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

local function MakeButton(parent, text, w, point, x, y, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, 22)
	b:SetPoint(point, x, y)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function Build()
	frame = CreateFrame("Frame", "TitanBarsConfig", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(320, 660)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	tinsert(UISpecialFrames, "TitanBarsConfig")

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("TOP", 0, -5)
	frame.title:SetText("TitanBars")

	-- Bar selector
	frame.tabs = {}
	for id = 1, TB.NUM_BARS do
		local tab = MakeButton(frame, tostring(id), 34, "TOPLEFT", 14 + (id - 1) * 37, -32, function()
			selected = id
			TB:RefreshConfig()
		end)
		frame.tabs[id] = tab
	end

	frame.barName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.barName:SetPoint("TOPLEFT", 20, -64)

	MakeCheck(frame, "Enabled", 18, -88,
		function() return Cfg().enabled end,
		function(v) Cfg().enabled = v; Changed() end)

	MakeSlider(frame, "Buttons", 1, 12, 1, Whole, -135, "buttons")
	MakeSlider(frame, "Buttons per row", 1, 12, 1, Whole, -180, "perRow")
	MakeSlider(frame, "Size", 0.3, 3, 0.05, Percent, -225, "scale")
	MakeSlider(frame, "Button spacing", 0, 20, 1, Whole, -270, "padding")
	MakeSlider(frame, "Opacity", 0.1, 1, 0.05, Percent, -315, "alpha")

	local visLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	visLabel:SetPoint("TOPLEFT", 22, -345)
	visLabel:SetText("Show/hide rule (macro conditions, Enter to apply)")

	local vis = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
	vis:SetPoint("TOPLEFT", 20, -362)
	vis:SetSize(280, 22)
	vis:SetAutoFocus(false)
	vis:SetFontObject(ChatFontNormal)
	vis:SetTextInsets(6, 6, 0, 0)
	vis:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	vis:SetBackdropColor(0, 0, 0, 0.6)
	vis:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	vis:SetScript("OnEnterPressed", function(self)
		Cfg().visibility = self:GetText()
		self:ClearFocus()
		Changed()
	end)
	vis:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self.Refresh() end)
	vis.Refresh = function() vis:SetText(Cfg().visibility or "") end
	table.insert(controls, vis)

	local visHelp = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	visHelp:SetPoint("TOPLEFT", 22, -388)
	visHelp:SetWidth(280)
	visHelp:SetJustifyH("LEFT")
	visHelp:SetText("e.g.  [combat] show; hide   or   [mod:shift] show; hide")

	frame.lockBtn = MakeButton(frame, "Unlock", 90, "TOPLEFT", 18, -414, function()
		TB:SetUnlocked(not TB.unlocked)
	end)
	frame.bindBtn = MakeButton(frame, "Keybind mode", 110, "TOPLEFT", 112, -414, function()
		TB:SetBindMode(not TB.bindMode)
	end)
	MakeButton(frame, "Reset bar", 80, "TOPLEFT", 226, -414, function()
		if InCombatLockdown() then return end
		TB:ResetBar(selected)
		Changed()
		TB:RefreshConfig()
	end)

	MakeCheck(frame, "Hide Blizzard action bars + art (needs /reload)", 18, -448,
		function() return TB.db.hideBlizzard end,
		function(v)
			TB.db.hideBlizzard = v
			TB:Print("Type /reload to apply.")
		end)

	-- Bags and menu buttons
	local extrasLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	extrasLabel:SetPoint("TOPLEFT", 20, -484)
	extrasLabel:SetText("Bags and menu buttons")
	for n, info in ipairs(TB.EXTRAS) do
		MakeSlider(frame, info.label .. " size", 0.3, 3, 0.05, Percent, -500 - n * 45, "scale",
			function() return TB:ExtraCfg(info.key) end,
			function() TB:ApplyExtra(info) end,
			function() local f = _G[info.name]; return f and f:GetScale() end)
	end
	MakeCheck(frame, "Hide bag + menu button art (needs /reload)", 18, -584,
		function() return TB.db.hideExtraArt end,
		function(v)
			TB.db.hideExtraArt = v
			TB:Print("Type /reload to apply.")
		end)

	local help = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	help:SetPoint("TOPLEFT", 22, -614)
	help:SetWidth(280)
	help:SetJustifyH("LEFT")
	help:SetText("Unlock, then drag bars, bags and menu buttons to move them; mouse wheel to resize. Keybind mode: hover a button and press a key. Pet and stance bars stay Blizzard's: move them in Edit Mode.")
end

function TB:RefreshConfig()
	if not frame or not frame:IsShown() then return end
	refreshing = true
	for id, tab in ipairs(frame.tabs) do
		if id == selected then tab:LockHighlight() else tab:UnlockHighlight() end
	end
	frame.barName:SetText(("Bar %d: %s"):format(selected, TB.BAR_INFO[selected].label))
	for _, c in ipairs(controls) do c.Refresh() end
	frame.lockBtn:SetText(TB.unlocked and "Lock" or "Unlock")
	frame.bindBtn:SetText(TB.bindMode and "Stop binding" or "Keybind mode")
	refreshing = false
end

function TB:OpenConfig(id)
	if not frame then Build() end
	if id then selected = id end
	frame:Show()
	self:RefreshConfig()
end

function TB:ToggleConfig()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		self:OpenConfig()
	end
end

-- Entry in Esc > Options > AddOns that opens the window.
if Settings and Settings.RegisterCanvasLayoutCategory then
	local panel = CreateFrame("Frame")
	local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	open:SetSize(200, 26)
	open:SetPoint("TOPLEFT", 16, -16)
	open:SetText("Open TitanBars settings")
	open:SetScript("OnClick", function()
		if SettingsPanel then HideUIPanel(SettingsPanel) end
		TB:OpenConfig()
	end)
	local category = Settings.RegisterCanvasLayoutCategory(panel, "TitanBars")
	Settings.RegisterAddOnCategory(category)
end
