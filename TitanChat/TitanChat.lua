-- TitanChat: a cleaner, flatter look for Blizzard's chat windows.
--
-- This restyles the game's own chat frames instead of replacing them. Forever can hand
-- addons "secret" chat text in combat, which an addon can't read or rewrite, so TitanChat
-- never touches message text: it only changes art, fonts and layout. Everything chat does
-- (tabs, whispers, links, history, Edit Mode) keeps working as Blizzard wrote it.
local ADDON, TC = ...
_G.TitanChat = TC

local DEFAULTS = {
	bgAlpha = 0.55,     -- panel darkness
	font = 1,           -- index into FONTS
	outline = false,
	spacing = 2,        -- extra space between lines
	hideButtons = true, -- the column of buttons beside chat
}

local FONTS = {
	{ name = "Arial Narrow",  file = "Fonts\\ARIALN.TTF" },
	{ name = "Friz Quadrata", file = "Fonts\\FRIZQT__.TTF" },
	{ name = "Game default" },
}

-- Blizzard chat art we blank out (textures keep existing, so Blizzard's fade and
-- colour code still runs on them without error; there's just nothing to draw).
local FRAME_TEX = {
	"Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
	"LeftTexture", "RightTexture", "BottomTexture", "TopTexture",
}
local TAB_TEX = {
	"Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
	"HighlightLeft", "HighlightMiddle", "HighlightRight",
}
local EDIT_TEX = { "Left", "Right", "Mid", "FocusLeft", "FocusRight", "FocusMid" }
-- Buttons that sit beside chat in some layouts (not all exist on every client).
local SIDE_BUTTONS = { "ChatFrameChannelButton", "TextToSpeechButtonFrame", "QuickJoinToastButton", "ChatFrameMenuButton" }

local hidden = CreateFrame("Frame")
hidden:Hide()
local styled = {}       -- chat frame -> our bits
local origParent = {}   -- frame -> its parent before we hid it

function TC:Print(msg)
	print("|cff33ccffTitanChat|r: " .. msg)
end

local function Accent()
	local _, class = UnitClass("player")
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 0.2, 0.6, 1
end

local function Blank(tex)
	if type(tex) == "table" and tex.SetTexture then tex:SetTexture(nil) end
end

-- 1px border lines around a region (a texture or frame).
local function AddBorder(owner, region, layer)
	local lines = {}
	local spec = {
		{ "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
	}
	for i, s in ipairs(spec) do
		local l = owner:CreateTexture(nil, layer or "BORDER")
		l:SetPoint(s[1], region, s[1])
		l:SetPoint(s[2], region, s[2])
		if s[3] then l:SetHeight(1) else l:SetWidth(1) end
		lines[i] = l
	end
	function lines:SetColor(r, g, b, a)
		for _, l in ipairs(self) do l:SetColorTexture(r, g, b, a) end
	end
	return lines
end

---------------------------------------------------------------------------
-- One chat window
---------------------------------------------------------------------------
local function UpdateTab(cf)
	local s = styled[cf]
	if s and s.line then s.line:SetShown(cf:IsShown()) end
end

local function ApplyFont(cf)
	local s = styled[cf]
	local file, size = cf:GetFont()
	if not file or not size then return end
	s.origFace = s.origFace or file
	local face = FONTS[TC.db.font] and FONTS[TC.db.font].file or s.origFace
	cf:SetFont(face, size, TC.db.outline and "OUTLINE" or "")
	cf:SetShadowOffset(1, -1)
	cf:SetShadowColor(0, 0, 0, TC.db.outline and 0 or 0.9)
	if cf.SetSpacing then cf:SetSpacing(TC.db.spacing) end
	if s.tabText and s.tabText.GetFont then
		local _, tsize = s.tabText:GetFont()
		s.tabText:SetFont(face, tsize or 12, "")
		s.tabText:SetShadowOffset(1, -1)
	end
end

local function SetHidden(f, hide)
	if not f then return end
	if hide then
		if f:GetParent() ~= hidden then
			origParent[f] = f:GetParent()
			f:SetParent(hidden)
		end
	elseif origParent[f] then
		f:SetParent(origParent[f])
		origParent[f] = nil
	end
end

local function Style(cf)
	if not cf or styled[cf] then return end
	local name = cf:GetName()
	if not name then return end
	local s = {}
	styled[cf] = s
	local r, g, b = Accent()

	for _, key in ipairs(FRAME_TEX) do Blank(_G[name .. key]) end

	-- Dark panel behind the messages, a slightly darker strip behind the tabs.
	s.bg = cf:CreateTexture(nil, "BACKGROUND", nil, -8)
	s.bg:SetPoint("TOPLEFT", -6, 6)
	s.bg:SetPoint("BOTTOMRIGHT", 6, -6)
	s.head = cf:CreateTexture(nil, "BACKGROUND", nil, -8)
	s.head:SetPoint("BOTTOMLEFT", s.bg, "TOPLEFT")
	s.head:SetPoint("BOTTOMRIGHT", s.bg, "TOPRIGHT")
	s.head:SetHeight(24)
	s.border = AddBorder(cf, s.bg)

	-- Tabs: flat, with a class-coloured underline on the window you're looking at.
	local tab = _G[name .. "Tab"]
	if tab then
		for _, key in ipairs(TAB_TEX) do Blank(tab[key]) end
		local hl = tab:CreateTexture(nil, "HIGHLIGHT")
		hl:SetColorTexture(1, 1, 1, 0.08)
		hl:SetPoint("TOPLEFT", 2, -6)
		hl:SetPoint("BOTTOMRIGHT", -2, 2)
		s.tabText = tab.Text or _G[name .. "TabText"]
		s.line = tab:CreateTexture(nil, "OVERLAY")
		s.line:SetColorTexture(r, g, b, 0.9)
		s.line:SetHeight(2)
		s.line:SetPoint("BOTTOMLEFT", 6, 2)
		s.line:SetPoint("BOTTOMRIGHT", -6, 2)
	end
	cf:HookScript("OnShow", UpdateTab)
	cf:HookScript("OnHide", UpdateTab)

	-- Input box: flat dark bar, accent border while typing.
	local eb = cf.editBox or _G[name .. "EditBox"]
	if eb then
		for _, key in ipairs(EDIT_TEX) do Blank(_G[name .. "EditBox" .. key]) end
		Blank(eb.focusLeft); Blank(eb.focusRight); Blank(eb.focusMid)
		s.ebBg = eb:CreateTexture(nil, "BACKGROUND", nil, -8)
		s.ebBg:SetPoint("TOPLEFT", 6, -5)
		s.ebBg:SetPoint("BOTTOMRIGHT", -6, 5)
		s.ebBorder = AddBorder(eb, s.ebBg)
		s.ebBorder:SetColor(0, 0, 0, 0.8)
		eb:HookScript("OnEditFocusGained", function() s.ebBorder:SetColor(r, g, b, 0.9) end)
		eb:HookScript("OnEditFocusLost", function() s.ebBorder:SetColor(0, 0, 0, 0.8) end)
	end

	TC:Refresh(cf)
	UpdateTab(cf)
end

function TC:Refresh(cf)
	local s = styled[cf]
	if not s then return end
	local a = self.db.bgAlpha
	s.bg:SetColorTexture(0.04, 0.04, 0.06, a)
	s.head:SetColorTexture(0.02, 0.02, 0.03, math.min(1, a + 0.15))
	s.border:SetColor(0, 0, 0, math.min(1, a + 0.25))
	if s.ebBg then s.ebBg:SetColorTexture(0.04, 0.04, 0.06, math.min(1, a + 0.3)) end
	ApplyFont(cf)
	SetHidden(cf.buttonFrame, self.db.hideButtons)
end

function TC:RefreshAll()
	self:StyleAll()
	for cf in pairs(styled) do self:Refresh(cf) end
	for _, n in ipairs(SIDE_BUTTONS) do SetHidden(_G[n], self.db.hideButtons) end
end

function TC:StyleAll()
	for _, name in ipairs(CHAT_FRAMES or {}) do Style(_G[name]) end
end

---------------------------------------------------------------------------
-- Settings (/tchat)
---------------------------------------------------------------------------
local win

local function Slider(parent, y, label, lo, hi, step, get, set, fmt)
	local s = CreateFrame("Slider", nil, parent, "UISliderTemplateWithLabels")
	s:SetPoint("TOPLEFT", 24, y)
	s:SetSize(240, 17)
	s:SetMinMaxValues(lo, hi)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s.Low:SetText(fmt(lo))
	s.High:SetText(fmt(hi))
	s:SetScript("OnValueChanged", function(self, v)
		self.Text:SetText(label .. ": " .. fmt(v))
		if not win.refreshing then set(v); TC:RefreshAll() end
	end)
	s.get = get
	return s
end

local function Check(parent, y, label, get, set)
	local c = CreateFrame("CheckButton", nil, parent)
	c:SetSize(24, 24)
	c:SetPoint("TOPLEFT", 20, y)
	c:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	c:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	c:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	c:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	c.text:SetPoint("LEFT", c, "RIGHT", 4, 0)
	c.text:SetText(label)
	c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); TC:RefreshAll() end)
	c.get = get
	return c
end

local function BuildWindow()
	win = CreateFrame("Frame", "TitanChatConfig", UIParent, "BasicFrameTemplateWithInset")
	win:SetSize(300, 300)
	win:SetPoint("CENTER")
	win:SetFrameStrata("HIGH")
	win:SetMovable(true)
	win:SetClampedToScreen(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop", win.StopMovingOrSizing)
	tinsert(UISpecialFrames, "TitanChatConfig")

	local title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -5)
	title:SetText("TitanChat")

	local db = TC.db
	win.controls = {
		Slider(win, -50, "Background", 0, 1, 0.05, function() return db.bgAlpha end,
			function(v) db.bgAlpha = v end, function(v) return ("%d%%"):format(v * 100 + 0.5) end),
		Slider(win, -100, "Line spacing", 0, 8, 1, function() return db.spacing end,
			function(v) db.spacing = v end, function(v) return tostring(math.floor(v + 0.5)) end),
		Check(win, -140, "Outlined text", function() return db.outline end, function(v) db.outline = v end),
		Check(win, -168, "Hide the buttons beside chat", function() return db.hideButtons end, function(v) db.hideButtons = v end),
	}

	win.fontBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	win.fontBtn:SetSize(200, 24)
	win.fontBtn:SetPoint("TOPLEFT", 24, -206)
	win.fontBtn:SetScript("OnClick", function()
		db.font = db.font % #FONTS + 1
		TC:RefreshAll()
		TC:RefreshWindow()
	end)

	local help = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	help:SetPoint("TOPLEFT", 24, -242)
	help:SetWidth(252)
	help:SetJustifyH("LEFT")
	help:SetText("Font size, colours and channels stay in Blizzard's chat settings (right-click a tab). Turning TitanChat off fully needs the AddOns list + /reload.")
end

function TC:RefreshWindow()
	if not win or not win:IsShown() then return end
	win.refreshing = true
	for _, c in ipairs(win.controls) do
		if c.SetValue then c:SetValue(c.get()) else c:SetChecked(c.get()) end
	end
	win.fontBtn:SetText("Font: " .. FONTS[self.db.font].name)
	win.refreshing = false
end

function TC:ToggleWindow()
	if not win then BuildWindow() end
	win:SetShown(not win:IsShown())
	self:RefreshWindow()
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
local function Later() C_Timer.After(0, function() TC:RefreshAll() end) end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("UPDATE_CHAT_WINDOWS")
ev:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
ev:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		TitanChatDB = TitanChatDB or {}
		for k, v in pairs(DEFAULTS) do
			if TitanChatDB[k] == nil then TitanChatDB[k] = v end
		end
		if not FONTS[TitanChatDB.font] then TitanChatDB.font = 1 end
		TC.db = TitanChatDB
	elseif event == "PLAYER_LOGIN" then
		TC.ready = true
		TC:RefreshAll()
		-- New windows (whispers popped out, "New Window") and Blizzard re-applying fonts.
		if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", Later) end
		if FCF_OpenNewWindow then hooksecurefunc("FCF_OpenNewWindow", Later) end
		if FCF_SetChatWindowFontSize then hooksecurefunc("FCF_SetChatWindowFontSize", Later) end
		Later()
	elseif TC.ready then
		Later()
	end
end)

SLASH_TITANCHAT1 = "/tchat"
SLASH_TITANCHAT2 = "/titanchat"
SlashCmdList.TITANCHAT = function()
	TC:ToggleWindow()
end
