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
	frame = MakeScrollWindow("TitanBarsConfig", 346, 700)
	local c = frame.content

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("TOP", 0, -5)
	frame.title:SetText("TitanBars")

	-- Bar selector
	frame.tabs = {}
	for id = 1, TB.NUM_BARS do
		local tab = MakeButton(c, tostring(id), 34, "TOPLEFT", 10 + (id - 1) * 37, -6, function()
			selected = id
			TB:RefreshConfig()
		end)
		frame.tabs[id] = tab
	end

	frame.barName = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.barName:SetPoint("TOPLEFT", 16, -38)

	MakeCheck(c, "Enabled", 14, -62,
		function() return Cfg().enabled end,
		function(v) Cfg().enabled = v; Changed() end)

	MakeSlider(c, "Buttons", 1, 12, 1, Whole, -109, "buttons")
	MakeSlider(c, "Buttons per row", 1, 12, 1, Whole, -154, "perRow")
	MakeSlider(c, "Size", 0.3, 3, 0.05, Percent, -199, "scale")
	MakeSlider(c, "Button spacing", 0, 20, 1, Whole, -244, "padding")
	MakeSlider(c, "Opacity", 0.1, 1, 0.05, Percent, -289, "alpha")

	local visLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	visLabel:SetPoint("TOPLEFT", 18, -322)
	visLabel:SetText("Show/hide rule (macro conditions, Enter to apply)")

	local vis = CreateFrame("EditBox", nil, c, "BackdropTemplate")
	vis:SetPoint("TOPLEFT", 16, -339)
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

	local visHelp = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	visHelp:SetPoint("TOPLEFT", 18, -365)
	visHelp:SetWidth(280)
	visHelp:SetJustifyH("LEFT")
	visHelp:SetText("e.g.  [combat] show; hide   or   [mod:shift] show; hide")

	frame.lockBtn = MakeButton(c, "Unlock", 90, "TOPLEFT", 14, -390, function()
		TB:SetUnlocked(not TB.unlocked)
	end)
	frame.bindBtn = MakeButton(c, "Keybind mode", 110, "TOPLEFT", 108, -390, function()
		TB:SetBindMode(not TB.bindMode)
	end)
	MakeButton(c, "Reset bar", 80, "TOPLEFT", 222, -390, function()
		if InCombatLockdown() then return end
		TB:ResetBar(selected)
		Changed()
		TB:RefreshConfig()
	end)

	MakeCheck(c, "Hide Blizzard action bars + art (needs /reload)", 14, -424,
		function() return TB.db.hideBlizzard end,
		function(v)
			TB.db.hideBlizzard = v
			TB:Print("Type /reload to apply.")
		end)

	-- Bags and menu buttons
	local extrasLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	extrasLabel:SetPoint("TOPLEFT", 16, -462)
	extrasLabel:SetText("Bags and menu buttons")
	for n, info in ipairs(TB.EXTRAS) do
		MakeSlider(c, info.label .. " size", 0.3, 3, 0.05, Percent, -460 - n * 48, "scale",
			function() return TB:ExtraCfg(info.key) end,
			function() TB:ApplyExtra(info) end,
			function() local f = _G[info.name]; return f and f:GetScale() end)
	end
	MakeCheck(c, "Hide bag + menu button art (needs /reload)", 14, -596,
		function() return TB.db.hideExtraArt end,
		function(v)
			TB.db.hideExtraArt = v
			TB:Print("Type /reload to apply.")
		end)

	MakeCheck(c, "Show cooldown numbers on buttons", 14, -622,
		function() return GetCVarBool("countdownForCooldowns") end,
		function(v) SetCVar("countdownForCooldowns", v and "1" or "0") end)

	local help = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	help:SetPoint("TOPLEFT", 18, -656)
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
	frame:Fit()
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
