-- TitanQuests: the settings window (/tquests or the gear on the tracker).
local ADDON, TQ = ...

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
		TQ.db[field] = v
		onChange()
	end)
	s.Refresh = function()
		s:SetValue(TQ.db[field])
		s.Text:SetText(label .. ": " .. fmt(TQ.db[field]))
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
	frame = MakeScrollWindow("TitanQuestsConfig", 346, 640)
	local c = frame.content
	local db = TQ.db
	local function Refresh() TQ:Refresh() end
	local function Layout() TQ:ApplyLayout() end

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("TOP", 0, -5)
	frame.title:SetText("TitanQuests")

	Heading(c, "Show", -8)
	MakeCheck(c, "Every quest in the log, not just tracked", -30,
		function() return db.showAll end, function(on) db.showAll = on; TQ.offset = 0; Refresh() end)
	MakeCheck(c, "Group quests under their zone", -54,
		function() return db.zones end, function(on) db.zones = on; Refresh() end)
	MakeCheck(c, "Quest level before the name", -78,
		function() return db.levels end, function(on) db.levels = on; Refresh() end)
	MakeCheck(c, "Hide objectives you've finished", -102,
		function() return db.hideDone end, function(on) db.hideDone = on; Refresh() end)
	MakeCheck(c, "Quest item buttons", -126,
		function() return db.items end, function(on) db.items = on; Refresh() end)
	MakeCheck(c, "Hide Blizzard's quest tracker", -150,
		function() return db.hideBlizzard end, function(on) db.hideBlizzard = on; TQ:UpdateBlizzard() end)

	Heading(c, "Minimize", -184)
	MakeCheck(c, "Minimized", -206,
		function() return db.minimized end, function(on) TQ:SetMinimized(on) end)
	MakeCheck(c, "Minimize in dungeons and raids", -230,
		function() return db.dungeonMinimize end, function(on) db.dungeonMinimize = on end)
	MakeCheck(c, "Minimize during combat", -254,
		function() return db.combatMinimize end, function(on)
			db.combatMinimize = on
			TQ:SyncItemHolder()
			TQ:ApplyMinimized()
		end)
	MakeCheck(c, "Lock position and width", -278,
		function() return db.locked end, function(on) db.locked = on end)

	Heading(c, "Size", -312)
	local function Pct(v) return ("%d%%"):format(v * 100 + 0.5) end
	local function Px(v) return ("%d"):format(v) end
	MakeSlider(c, "Width", 180, 500, 5, Px, -350, "width", Layout)
	MakeSlider(c, "Max height", 150, 900, 10, Px, -400, "maxHeight", Refresh)
	MakeSlider(c, "Scale", 0.5, 2, 0.05, Pct, -450, "scale", Layout)
	MakeSlider(c, "Text size", 9, 18, 1, Px, -500, "fontSize", Layout)
	MakeSlider(c, "Background", 0, 1, 0.05, Pct, -550, "alpha", Layout)

	MakeButton(c, "Fold all", 90, 18, -590, function() TQ:SetAllFolded(true) end)
	MakeButton(c, "Unfold all", 90, 112, -590, function() TQ:SetAllFolded(false) end)
	MakeButton(c, "Reset position", 110, 206, -590, function() SlashCmdList.TITANQUESTS("reset") end)
end

function TQ:RefreshConfig()
	if not frame or not frame:IsShown() then return end
	refreshing = true
	for _, c in ipairs(controls) do c.Refresh() end
	refreshing = false
end

function TQ:ToggleConfig()
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
	open:SetText("Open TitanQuests settings")
	open:SetScript("OnClick", function()
		if SettingsPanel then HideUIPanel(SettingsPanel) end
		TQ:ToggleConfig()
	end)
	local category = Settings.RegisterCanvasLayoutCategory(panel, "TitanQuests")
	Settings.RegisterAddOnCategory(category)
end
