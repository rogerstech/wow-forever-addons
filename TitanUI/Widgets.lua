-- TitanUI: the controls a settings page is built from.
--
-- A page is a column of controls laid out top to bottom. Every control reads its value
-- through a get() function and writes it through set(v), so the page never holds a copy
-- of a setting: what you see is always what the addon has saved. After any change the
-- whole page re-reads its values, so linked controls (a Lock button's label, a slider
-- that depends on a checkbox) stay in step.
local ADDON, UI = ...
_G.TitanUI = UI

UI.ACCENT = { 0.2, 0.6, 1 }
local WIDTH = 500      -- usable page width
local LEFT = 16

local Page = {}
Page.__index = Page

function UI:NewPage(parent)
	local content = CreateFrame("Frame", nil, parent)
	content:SetSize(WIDTH + LEFT * 2, 10)
	local p = setmetatable({ frame = content, y = -12, controls = {}, refreshing = false }, Page)
	return p
end

function Page:Space(h)
	self.y = self.y - (h or 8)
end

function Page:Finish()
	self.frame:SetHeight(-self.y + 16)
end

function Page:Refresh()
	self.refreshing = true
	for _, c in ipairs(self.controls) do
		local ok, err = pcall(c.Refresh)
		if not ok then UI:Error(err) end
	end
	self.refreshing = false
end

-- Run a setting change, then re-read the page. Errors are printed rather than
-- breaking the window.
function Page:Apply(fn, ...)
	if self.refreshing then return end
	if self.noCombat and InCombatLockdown() then
		UI:Print("can't change that in combat.")
		self:Refresh()
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then UI:Error(err) end
	self:Refresh()
end

local function Add(p, c)
	table.insert(p.controls, c)
	return c
end

local function Tooltip(region, title, text)
	if not text then return end
	region:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title)
		GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true)
		GameTooltip:Show()
	end)
	region:HookScript("OnLeave", GameTooltip_Hide)
end

---------------------------------------------------------------------------
function Page:Title(text, sub)
	local t = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	t:SetPoint("TOPLEFT", LEFT, self.y)
	t:SetText(text)
	self.y = self.y - 30
	if sub then
		local s = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		s:SetPoint("TOPLEFT", LEFT, self.y)
		s:SetWidth(WIDTH)
		s:SetJustifyH("LEFT")
		s:SetText(sub)
		s:SetTextColor(0.7, 0.7, 0.75)
		self.y = self.y - s:GetStringHeight() - 10
	end
end

function Page:Header(text)
	self.y = self.y - 8
	local t = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	t:SetPoint("TOPLEFT", LEFT, self.y)
	t:SetText(text)
	local line = self.frame:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.5)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", LEFT, self.y - 20)
	line:SetWidth(WIDTH)
	self.y = self.y - 30
end

function Page:Note(text)
	local t = self.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	t:SetPoint("TOPLEFT", LEFT + 4, self.y)
	t:SetWidth(WIDTH - 8)
	t:SetJustifyH("LEFT")
	if type(text) == "function" then
		Add(self, { Refresh = function() t:SetText(text()) end })
		t:SetText(text())
	else
		t:SetText(text)
	end
	self.y = self.y - math.max(14, t:GetStringHeight()) - 8
	return t
end

-- Checkbox. get() -> bool, set(bool).
function Page:Check(label, get, set, tip)
	local c = CreateFrame("CheckButton", nil, self.frame)
	c:SetSize(24, 24)
	c:SetPoint("TOPLEFT", LEFT, self.y)
	c:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	c:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	c:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	c:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	c.text:SetPoint("LEFT", c, "RIGHT", 4, 0)
	c.text:SetText(label)
	c:SetHitRectInsets(0, -math.min(WIDTH - 30, c.text:GetStringWidth() + 8), 0, 0)
	c:SetScript("OnClick", function(btn)
		self:Apply(set, btn:GetChecked() and true or false)
	end)
	Tooltip(c, label, tip)
	c.Refresh = function() c:SetChecked(get() and true or false) end
	self.y = self.y - 26
	return Add(self, c)
end

local function Percent(v) return ("%d%%"):format(v * 100 + 0.5) end
local function Whole(v) return tostring(math.floor(v + 0.5)) end
UI.Percent, UI.Whole = Percent, Whole

-- Slider. fmt: UI.Percent, UI.Whole or your own. Mouse wheel nudges one step.
function Page:Slider(label, minV, maxV, step, get, set, fmt, tip)
	fmt = fmt or Whole
	local s = CreateFrame("Slider", nil, self.frame, "UISliderTemplateWithLabels")
	s:SetPoint("TOPLEFT", LEFT + 6, self.y - 16)
	s:SetSize(300, 17)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s.Low:SetText(fmt(minV))
	s.High:SetText(fmt(maxV))
	s:EnableMouseWheel(true)
	s:SetScript("OnMouseWheel", function(sl, delta)
		local lo, hi = sl:GetMinMaxValues()
		sl:SetValue(math.max(lo, math.min(hi, sl:GetValue() + delta * step)))
	end)
	s:SetScript("OnValueChanged", function(sl, v)
		if step >= 1 then v = math.floor(v + 0.5) end
		sl.Text:SetText(label .. ":  |cffffffff" .. fmt(v) .. "|r")
		if self.refreshing then return end
		self:Apply(set, v)
	end)
	Tooltip(s, label, tip)
	s.Refresh = function()
		local v = tonumber(get()) or minV
		s:SetValue(v)
		s.Text:SetText(label .. ":  |cffffffff" .. fmt(v) .. "|r")
	end
	self.y = self.y - 52
	return Add(self, s)
end

-- Pick one of several. options = { {value, label}, ... } or a function returning that.
function Page:Choice(label, options, get, set, tip)
	local function Opts() return type(options) == "function" and options() or options end
	local t = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	t:SetPoint("TOPLEFT", LEFT + 4, self.y - 5)
	t:SetText(label)
	local b = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
	b:SetSize(230, 22)
	b:SetPoint("TOPLEFT", LEFT + 200, self.y)
	b:SetScript("OnClick", function(btn)
		local list = Opts()
		if MenuUtil and MenuUtil.CreateContextMenu then
			MenuUtil.CreateContextMenu(btn, function(_, root)
				for _, o in ipairs(list) do
					root:CreateRadio(o[2], function() return get() == o[1] end,
						function() self:Apply(set, o[1]) end)
				end
			end)
		else
			-- No menu system: step to the next option.
			local cur, nextV = get(), list[1] and list[1][1]
			for i, o in ipairs(list) do
				if o[1] == cur then nextV = (list[i + 1] or list[1])[1] end
			end
			self:Apply(set, nextV)
		end
	end)
	Tooltip(b, label, tip)
	b.Refresh = function()
		local cur, text = get(), "-"
		for _, o in ipairs(Opts()) do
			if o[1] == cur then text = o[2] end
		end
		b:SetText(text .. "  |cff8a8a96v|r")
	end
	self.y = self.y - 30
	return Add(self, b)
end

-- A row of buttons: { {label or function() -> label, onClick, tip}, ... }
function Page:Buttons(list)
	local prev
	for _, def in ipairs(list) do
		local label, fn, tip = def[1], def[2], def[3]
		local b = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
		local function Text() return type(label) == "function" and label() or label end
		b:SetText(Text())
		b:SetSize(math.max(90, b:GetFontString():GetStringWidth() + 30), 22)
		if prev then
			b:SetPoint("LEFT", prev, "RIGHT", 8, 0)
		else
			b:SetPoint("TOPLEFT", LEFT, self.y)
		end
		prev = b
		b:SetScript("OnClick", function() self:Apply(fn) end)
		Tooltip(b, Text(), tip)
		b.Refresh = function()
			b:SetText(Text())
			b:SetWidth(math.max(90, b:GetFontString():GetStringWidth() + 30))
		end
		Add(self, b)
	end
	self.y = self.y - 30
end

-- One-line text setting, applied when you press Enter.
function Page:Edit(label, get, set, tip)
	local t = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	t:SetPoint("TOPLEFT", LEFT + 4, self.y)
	t:SetText(label)
	self.y = self.y - 18
	local e = CreateFrame("EditBox", nil, self.frame, "BackdropTemplate")
	e:SetPoint("TOPLEFT", LEFT, self.y)
	e:SetSize(WIDTH - 20, 22)
	e:SetAutoFocus(false)
	e:SetFontObject(ChatFontNormal)
	e:SetTextInsets(6, 6, 0, 0)
	e:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	e:SetBackdropColor(0, 0, 0, 0.6)
	e:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
	e:SetScript("OnEnterPressed", function(box)
		box:ClearFocus()
		self:Apply(set, box:GetText())
	end)
	e:SetScript("OnEscapePressed", function(box)
		box:ClearFocus()
		box.Refresh()
	end)
	e:SetScript("OnEditFocusGained", function(box) box:SetBackdropBorderColor(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 1) end)
	e:SetScript("OnEditFocusLost", function(box) box:SetBackdropBorderColor(0.35, 0.35, 0.4, 1) end)
	Tooltip(e, label, tip)
	e.Refresh = function()
		if not e:HasFocus() then e:SetText(get() or "") end
	end
	self.y = self.y - 30
	return Add(self, e)
end
