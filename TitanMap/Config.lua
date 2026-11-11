-- TitanMap: the settings window (/tmap config).
local ADDON, TM = ...

local frame
local controls = {}
local refreshing

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

local function MakeSlider(parent, label, minV, maxV, step, fmt, y, field, onChange)
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
		TM.db[field] = v
		onChange()
	end)
	s.Refresh = function()
		s:SetValue(TM.db[field])
		s.Text:SetText(label .. ": " .. fmt(TM.db[field]))
	end
	table.insert(controls, s)
	return s
end

local function MakeButton(parent, text, w, x, y, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, 22)
	b:SetPoint("TOPLEFT", x, y)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
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
	frame = MakeScrollWindow("TitanMapConfig", 346, 560)
	local c = frame.content
	local db = TM.db
	local function Layout() TM:ApplyLayout() end
	local function Quests() TM:RefreshQuests() end

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("TOP", 0, -5)
	frame.title:SetText("TitanMap")

	Heading(c, "Map", -8)
	MakeCheck(c, "Show the map overlay", -30,
		function() return db.shown end, function(on) db.shown = on; TM:UpdateVisibility() end)
	MakeCheck(c, "Hide it during combat", -54,
		function() return db.hideInCombat end, function(on) db.hideInCombat = on; TM:UpdateVisibility() end)
	MakeCheck(c, "Hide it in dungeons and raids", -78,
		function() return db.hideInInstance end, function(on) db.hideInInstance = on; TM:UpdateVisibility() end)

	Heading(c, "Quests", -112)
	MakeCheck(c, "Only tracked quests", -134,
		function() return db.trackedOnly end, function(on) db.trackedOnly = on; Quests() end)
	MakeCheck(c, "Quest names next to markers", -158,
		function() return db.names end, function(on) db.names = on; Quests() end)
	MakeCheck(c, "Shade quest objective areas", -182,
		function() return db.areas end, function(on) db.areas = on; Quests() end)

	Heading(c, "Look", -216)
	local function Pct(v) return ("%d%%"):format(v * 100 + 0.5) end
	local function Px(v) return ("%d"):format(v) end
	MakeSlider(c, "Width", 200, 1600, 10, Px, -254, "width", Layout)
	MakeSlider(c, "Map opacity", 0.05, 1, 0.05, Pct, -304, "mapAlpha", Layout)
	MakeSlider(c, "Arrow + marker opacity", 0.2, 1, 0.05, Pct, -354, "pinAlpha", Layout)

	frame.lockBtn = MakeButton(c, "Unlock to move", 130, 18, -394, function() TM:SetUnlocked(not TM.unlocked) end)
	MakeButton(c, "Reset position", 120, 156, -394, function() SlashCmdList.TITANMAP("reset") end)

	local help = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	help:SetPoint("TOPLEFT", 22, -428)
	help:SetWidth(290)
	help:SetJustifyH("LEFT")
	help:SetText("Gold dot = quest in progress, green dot = ready to turn in. Clicks go through the map to the game. Set a toggle key in Options > Keybindings > AddOns > TitanMap, or type /tmap.")
end

function TM:RefreshConfig()
	if not frame or not frame:IsShown() then return end
	refreshing = true
	for _, c in ipairs(controls) do c.Refresh() end
	refreshing = false
	frame.lockBtn:SetText(self.unlocked and "Lock" or "Unlock to move")
end

function TM:ToggleConfig()
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
	open:SetText("Open TitanMap settings")
	open:SetScript("OnClick", function()
		if SettingsPanel then HideUIPanel(SettingsPanel) end
		TM:ToggleConfig()
	end)
	local category = Settings.RegisterCanvasLayoutCategory(panel, "TitanMap")
	Settings.RegisterAddOnCategory(category)
end
