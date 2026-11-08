-- TitanBars: building the bars, laying them out, and the drag/resize movers.
local ADDON, TB = ...

TB.bars = {}

-- Bar 1 follows stance/form, manual paging (Shift+wheel, Shift+1-6) and vehicles,
-- like the default main bar. The other bars get a fixed page.
local MAIN_PAGE_DRIVER = table.concat({
	"[overridebar][possessbar][shapeshift] possess",
	"[vehicleui] possess",
	"[bar:2] 2", "[bar:3] 3", "[bar:4] 4", "[bar:5] 5", "[bar:6] 6",
	"[bonusbar:1] 7", "[bonusbar:2] 8", "[bonusbar:3] 9", "[bonusbar:4] 10", "[bonusbar:5] 11",
	"1",
}, "; ")

-- Runs in the secure environment, so paging still works in combat.
local PAGE_SNIPPET = [[
	local page = tonumber(newstate)
	if not page then
		if HasVehicleActionBar() then
			page = GetVehicleBarIndex()
		elseif HasOverrideActionBar() then
			page = GetOverrideBarIndex()
		elseif HasTempShapeshiftActionBar() then
			page = GetTempShapeshiftBarIndex()
		elseif HasBonusActionBar() then
			page = GetBonusBarIndex()
		else
			page = 12
		end
	end
	self:SetAttribute("actionpage", page)
	for i = 1, 12 do
		local slot = (page - 1) * 12 + i
		self:GetFrameRef("button" .. i):SetAttribute("action", slot)
		self:GetFrameRef("key" .. i):SetAttribute("action", slot)
	end
]]

local function CreateButton(bar, i)
	local name = bar:GetName() .. "Button" .. i
	-- Blizzard's own template draws the icon, cooldown, charges, range, procs etc.
	local btn = CreateFrame("CheckButton", name, bar, "ActionBarButtonTemplate")
	btn.titanBar, btn.titanIndex = bar.id, i

	-- Key bindings go to a hidden twin button. Blizzard's template only fires on key
	-- release when clicked by a binding; the plain secure template honours the
	-- "cast on key down" setting.
	local key = CreateFrame("Button", name .. "Key", btn, "SecureActionButtonTemplate")
	key:SetSize(1, 1)
	key:EnableMouse(false)
	key:SetAttribute("type", "action")
	key:SetAttribute("typerelease", "actionrelease")
	key:SetAttribute("checkselfcast", true)
	key:SetAttribute("checkfocuscast", true)
	key:SetAttribute("checkmouseovercast", true)
	key:RegisterForClicks("AnyDown", "AnyUp")
	key:HookScript("OnClick", function(_, _, down)
		btn:SetButtonState(down and "PUSHED" or "NORMAL")
	end)
	btn.titanKey = key

	hooksecurefunc(btn, "UpdateHotkeys", TB.UpdateHotkeyText)
	hooksecurefunc(btn, "UpdatePressAndHoldAction", function(self)
		if not InCombatLockdown() then
			key:SetAttribute("pressAndHoldAction", self:GetAttribute("pressAndHoldAction"))
		end
	end)
	btn:HookScript("OnEnter", function(self) TB:OnButtonEnter(self) end)

	bar:SetFrameRef("button" .. i, btn)
	bar:SetFrameRef("key" .. i, key)
	return btn
end

function TB:CreateBars()
	for id = 1, self.NUM_BARS do
		local bar = CreateFrame("Frame", "TitanBarsBar" .. id, UIParent, "SecureHandlerStateTemplate")
		bar.id = id
		bar:SetMovable(true)
		bar:SetClampedToScreen(true)
		bar.buttons = {}
		for i = 1, self.MAX_BUTTONS do
			bar.buttons[i] = CreateButton(bar, i)
		end
		bar:SetAttribute("_onstate-page", PAGE_SNIPPET)
		local driver = id == 1 and MAIN_PAGE_DRIVER or tostring(self.BAR_INFO[id].page)
		RegisterStateDriver(bar, "page", driver)
		self.bars[id] = bar
	end
end

local function ButtonSize(bar)
	local w = bar.buttons[1]:GetWidth()
	return (w and w > 0) and w or 45
end

-- Default spot for a bar the first time it is shown (UIParent units, bar centre).
function TB:DefaultPos(id, w, h)
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	if id == 4 or id == 5 then
		return { x = sw - 30 - (id - 4) * (w + 6), y = sh / 2 }
	end
	local row = id <= 3 and (id - 1) or (id - 3)
	return { x = sw / 2, y = 30 + h / 2 + row * (h + 6) }
end

function TB:LayoutBar(id)
	local bar, cfg = self.bars[id], self.db.bars[id]
	local n = cfg.buttons
	local perRow = math.max(1, math.min(cfg.perRow, n))
	local rows = math.ceil(n / perRow)
	local size, pad = ButtonSize(bar), cfg.padding

	for i, btn in ipairs(bar.buttons) do
		btn:ClearAllPoints()
		if i <= n then
			local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
			btn:SetPoint("TOPLEFT", bar, "TOPLEFT", col * (size + pad), -row * (size + pad))
			btn:Show()
		else
			btn:Hide()
		end
	end
	bar:SetSize(perRow * (size + pad) - pad, rows * (size + pad) - pad)
	bar:SetScale(cfg.scale)
	bar:SetAlpha(cfg.alpha)

	if not cfg.pos then
		cfg.pos = self:DefaultPos(id, bar:GetWidth() * cfg.scale, bar:GetHeight() * cfg.scale)
	end
	bar:ClearAllPoints()
	bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cfg.pos.x / cfg.scale, cfg.pos.y / cfg.scale)

	if cfg.enabled then
		local vis = strtrim(cfg.visibility or "")
		RegisterStateDriver(bar, "visibility", vis ~= "" and vis or self.DEFAULT_VISIBILITY)
	else
		UnregisterStateDriver(bar, "visibility")
		bar:Hide()
	end
	if bar.mover then
		bar.mover:SetShown(self.unlocked and cfg.enabled)
	end
end

function TB:RefreshBar(id)
	self:RunOutOfCombat("bar" .. id, function()
		TB:LayoutBar(id)
		TB:ApplyBindings()
	end)
end

function TB:RefreshAll()
	self:RunOutOfCombat("refreshAll", function()
		for id = 1, TB.NUM_BARS do TB:LayoutBar(id) end
		TB:ApplyBindings()
		if TB.RefreshConfig then TB:RefreshConfig() end
	end)
end

-- Store the bar centre in UIParent units so it doesn't drift when the scale changes.
function TB:SavePosition(id)
	local bar = self.bars[id]
	local x, y = bar:GetCenter()
	local s = bar:GetScale()
	self.db.bars[id].pos = { x = x * s, y = y * s }
end

---------------------------------------------------------------------------
-- Movers (shown by /tb unlock)
---------------------------------------------------------------------------
local function CreateMover(bar)
	local id = bar.id
	local m = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	m:SetAllPoints(bar)
	m:SetFrameStrata("DIALOG")
	m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	m:SetBackdropColor(0.1, 0.5, 0.9, 0.45)
	m:SetBackdropBorderColor(0.3, 0.8, 1, 1)
	m.label = m:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	m.label:SetPoint("CENTER")
	m.label:SetText(id .. ": " .. TB.BAR_INFO[id].label)

	m:EnableMouse(true)
	m:EnableMouseWheel(true)
	m:RegisterForDrag("LeftButton")
	m:SetScript("OnDragStart", function()
		if not InCombatLockdown() then bar:StartMoving() end
	end)
	m:SetScript("OnDragStop", function()
		bar:StopMovingOrSizing()
		bar:SetUserPlaced(false)
		TB:SavePosition(id)
		TB:RefreshBar(id)
	end)
	m:SetScript("OnMouseWheel", function(_, delta)
		local cfg = TB.db.bars[id]
		local step = IsShiftKeyDown() and 0.01 or 0.05
		cfg.scale = math.max(0.3, math.min(3, math.floor((cfg.scale + delta * step) * 100 + 0.5) / 100))
		TB:RefreshBar(id)
		if TB.RefreshConfig then TB:RefreshConfig() end
		GameTooltip:SetOwner(m, "ANCHOR_TOP")
		GameTooltip:SetText(("Scale %d%%"):format(cfg.scale * 100))
		GameTooltip:Show()
	end)
	m:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then TB:OpenConfig(id) end
	end)
	m:SetScript("OnEnter", function()
		GameTooltip:SetOwner(m, "ANCHOR_TOP")
		GameTooltip:AddLine(m.label:GetText())
		GameTooltip:AddLine("Drag to move", 1, 1, 1)
		GameTooltip:AddLine("Mouse wheel to resize (Shift for fine steps)", 1, 1, 1)
		GameTooltip:AddLine("Right-click for this bar's settings", 1, 1, 1)
		GameTooltip:Show()
	end)
	m:SetScript("OnLeave", function() GameTooltip:Hide() end)
	m:Hide()
	bar.mover = m
	return m
end

function TB:SetUnlocked(on)
	if on and InCombatLockdown() then return end
	if on and self.bindMode then self:SetBindMode(false) end
	self.unlocked = on
	for id, bar in ipairs(self.bars) do
		local m = bar.mover or CreateMover(bar)
		m:SetShown(on and self.db.bars[id].enabled)
	end
	if self.RefreshConfig then self:RefreshConfig() end
	self:Print(on and "Bars unlocked. Drag to move, mouse wheel to resize, /tb lock when done." or "Bars locked.")
end
