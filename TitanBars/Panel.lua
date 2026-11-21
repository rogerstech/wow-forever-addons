-- TitanBars panel: a full-width strip at the top or bottom of the screen that holds
-- info readouts (coordinates, zone, clock, FPS/latency, gold, durability, bag space, XP),
-- the bag bar and the menu buttons, and can dock your buffs and
-- debuffs against its edge. The bag bar and menu buttons stay Blizzard's own frames;
-- the panel just takes over where they sit and how big they are.
local ADDON, TB = ...

local PANEL_DEFAULTS = {
	enabled = false,
	position = "bottom", -- "top" or "bottom"
	height = 30,
	alpha = 0.75,
	dockBuffs = true,
	-- readouts, left to right
	coords = true,
	zone = true,
	clock = true,
	perf = true,   -- FPS and latency
	gold = true,
	dura = true,   -- lowest durability on your gear
	bags = true,   -- free bag slots
	xp = true,     -- XP to next level and rested (hidden at max level)
}

-- Order and labels for the readouts (the settings window lists them in this order).
local READOUTS = {
	{ key = "coords", label = "Coordinates (x, y, and z when the game gives it)" },
	{ key = "zone",   label = "Zone and subzone" },
	{ key = "clock",  label = "Clock" },
	{ key = "perf",   label = "FPS and latency" },
	{ key = "gold",   label = "Gold" },
	{ key = "dura",   label = "Lowest gear durability" },
	{ key = "bags",   label = "Free bag slots" },
	{ key = "xp",     label = "XP and rested XP" },
}

local panel
local buffApplying = false

function TB:PanelCfg()
	self.db.panel = self.db.panel or {}
	local cfg = self.db.panel
	for k, v in pairs(PANEL_DEFAULTS) do
		if cfg[k] == nil then cfg[k] = v end
	end
	if cfg.position ~= "top" then cfg.position = "bottom" end
	cfg.height = math.max(20, math.min(48, tonumber(cfg.height) or 30))
	return cfg
end

-- Extras.lua asks this before placing the bag bar / menu buttons.
function TB:PanelOwns(info)
	return panel ~= nil and self:PanelCfg().enabled and (info.key == "bags" or info.key == "micro")
end

-- Place one of the extras on the panel: menu buttons at the right edge, bags left of them.
function TB:PanelPlace(info, f)
	local cfg = self:PanelCfg()
	local h = f:GetHeight()
	if not h or h <= 0 then return end
	local scale = (cfg.height - 4) / h
	f:SetScale(scale)
	f:ClearAllPoints()
	if info.key == "micro" then
		f:SetPoint("RIGHT", panel, "RIGHT", -6 / scale, 0)
	else
		local micro = _G.MicroMenuContainer
		if micro and micro:IsShown() then
			f:SetPoint("RIGHT", micro, "LEFT", -10 / scale, 0)
		else
			f:SetPoint("RIGHT", panel, "RIGHT", -6 / scale, 0)
		end
	end
end

---------------------------------------------------------------------------
-- Readouts. Each returns a short coloured string, or nil to leave itself out.
---------------------------------------------------------------------------
local GREY, DIM = "|cff8a8a96", "|r"

local function Coords()
	local mapID = C_Map.GetBestMapForUnit("player")
	local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then return GREY .. "no coords" .. DIM end -- instances don't give a position
	local x, y = pos:GetXY()
	if not x or not y or (x == 0 and y == 0) then return GREY .. "no coords" .. DIM end
	local text = ("%.1f, %.1f"):format(x * 100, y * 100)
	-- UnitPosition returns x, y, z (world units). z is often 0 or unavailable; show it only when real.
	local ok, _, _, z = pcall(UnitPosition, "player")
	if ok and type(z) == "number" and not (issecretvalue and issecretvalue(z)) and z ~= 0 then
		text = text .. (GREY .. "  z " .. DIM .. "%.1f"):format(z)
	end
	return text
end

local function Zone()
	local zone, sub = GetZoneText and GetZoneText() or "", GetSubZoneText and GetSubZoneText() or ""
	if sub ~= "" and sub ~= zone then return zone .. GREY .. " / " .. DIM .. sub end
	return zone ~= "" and zone or nil
end

local function Clock()
	if GetCVarBool and GetCVarBool("timeMgrUseMilitaryTime") then return date("%H:%M") end
	return (date("%I:%M %p"):gsub("^0", ""))
end

local function Perf()
	local fps = math.floor((GetFramerate() or 0) + 0.5)
	local _, _, home, world = GetNetStats()
	local ms = math.max(home or 0, world or 0)
	local c = ms < 100 and "|cff4fd15f" or ms < 200 and "|cffffd24a" or "|cffff5a4a"
	return ("%d" .. GREY .. " fps  " .. DIM .. c .. "%d|r" .. GREY .. " ms" .. DIM):format(fps, ms)
end

local function Gold()
	local m = GetMoney and GetMoney() or 0
	local g, sv, c = math.floor(m / 10000), math.floor(m / 100) % 100, m % 100
	return ("|cffffd24a%s|rg |cffc0c0c0%d|rs |cffd08a4a%d|rc"):format(BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g, sv, c)
end

local function Durability()
	local low
	for slot = 1, 18 do
		local cur, max = GetInventoryItemDurability(slot)
		if cur and max and max > 0 then
			local pct = cur / max
			if not low or pct < low then low = pct end
		end
	end
	if not low then return nil end
	local pct = math.floor(low * 100 + 0.5)
	local c = pct >= 50 and "" or pct >= 25 and "|cffffd24a" or "|cffff5a4a"
	return GREY .. "armor " .. DIM .. c .. pct .. "%" .. (c ~= "" and "|r" or "")
end

local function BagSlots()
	if not (C_Container and C_Container.GetContainerNumFreeSlots) then return nil end
	local free = 0
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
	end
	local c = free == 0 and "|cffff5a4a" or free <= 4 and "|cffffd24a" or ""
	return GREY .. "bags " .. DIM .. c .. free .. " free" .. (c ~= "" and "|r" or "")
end

local function XP()
	local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel()
	if maxLevel and UnitLevel("player") >= maxLevel then return nil end
	local cur, max = UnitXP("player"), UnitXPMax("player")
	if not cur or not max or max == 0 then return nil end
	local text = ("%s%s%d%%"):format(GREY, "xp " .. DIM, math.floor(cur / max * 100))
	local rested = GetXPExhaustion and GetXPExhaustion()
	if rested and rested > 0 then
		text = text .. ("|cff6fa8ff +%d%% rested|r"):format(math.floor(rested / max * 100))
	end
	return text
end

local READOUT_FN = {
	coords = Coords, zone = Zone, clock = Clock, perf = Perf,
	gold = Gold, dura = Durability, bags = BagSlots, xp = XP,
}

-- A plain "|" would start a colour code in WoW text, so the divider is a middle dot.
local SEP = "   " .. GREY .. "\194\183" .. DIM .. "   "

local function UpdateInfo()
	local cfg = TB:PanelCfg()
	local parts = {}
	for _, r in ipairs(READOUTS) do
		if cfg[r.key] then
			local ok, text = pcall(READOUT_FN[r.key])
			if ok and text and text ~= "" then parts[#parts + 1] = text end
		end
	end
	panel.info:SetText(table.concat(parts, SEP))
end

---------------------------------------------------------------------------
-- Buffs and debuffs docked against the panel's inner edge, right-aligned.
---------------------------------------------------------------------------
local function DockBuffs()
	local cfg = TB:PanelCfg()
	if not (cfg.enabled and cfg.dockBuffs and BuffFrame) then return end
	if (BuffFrame:IsProtected() or (DebuffFrame and DebuffFrame:IsProtected())) and InCombatLockdown() then
		TB:RunOutOfCombat("panelBuffs", DockBuffs, true)
		return
	end
	buffApplying = true
	BuffFrame:ClearAllPoints()
	if cfg.position == "top" then
		BuffFrame:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", -8, -6)
	else
		BuffFrame:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -8, 6)
	end
	if DebuffFrame then
		DebuffFrame:ClearAllPoints()
		if cfg.position == "top" then
			DebuffFrame:SetPoint("TOPRIGHT", BuffFrame, "BOTTOMRIGHT", 0, -6)
		else
			DebuffFrame:SetPoint("BOTTOMRIGHT", BuffFrame, "TOPRIGHT", 0, 6)
		end
	end
	buffApplying = false
end

local function HookBuffs()
	for _, f in ipairs({ BuffFrame, DebuffFrame }) do
		if f and not f.titanPanelHooked then
			f.titanPanelHooked = true
			hooksecurefunc(f, "SetPoint", function(self)
				if buffApplying or self.isDragging then return end
				local cfg = TB:PanelCfg()
				if cfg.enabled and cfg.dockBuffs then C_Timer.After(0, DockBuffs) end
			end)
			-- Dragging them in Edit Mode means you want them somewhere else: let go of them.
			if type(f.OnDragStop) == "function" then
				hooksecurefunc(f, "OnDragStop", function()
					local cfg = TB:PanelCfg()
					if cfg.enabled and cfg.dockBuffs then
						cfg.dockBuffs = false
						TB:Print("Buffs and debuffs are no longer docked to the panel, since you moved them. Turn docking back on in /tb panel.")
						TB:RefreshPanelWindow()
					end
				end)
			end
		end
	end
end

---------------------------------------------------------------------------
-- The panel itself
---------------------------------------------------------------------------
local function CreatePanel()
	panel = CreateFrame("Frame", "TitanBarsPanel", UIParent)
	panel:SetFrameStrata("BACKGROUND")
	panel:SetFrameLevel(1)
	panel.bg = panel:CreateTexture(nil, "BACKGROUND")
	panel.bg:SetAllPoints()
	panel.edge = panel:CreateTexture(nil, "BORDER")
	panel.edge:SetHeight(1)
	panel.info = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	panel.info:SetPoint("LEFT", 12, 0)
	panel.info:SetJustifyH("LEFT")
	panel.info:SetWordWrap(false)
	local font, size = panel.info:GetFont()
	if font then panel.info:SetFont("Fonts\\ARIALN.TTF", (size or 12) + 1, "") end
	panel.info:SetShadowOffset(1, -1)
	panel:Hide()
end

function TB:ApplyPanel()
	if not panel then return end
	local cfg = self:PanelCfg()
	panel:ClearAllPoints()
	panel.edge:ClearAllPoints()
	if cfg.position == "top" then
		panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
		panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT")
		panel.edge:SetPoint("BOTTOMLEFT")
		panel.edge:SetPoint("BOTTOMRIGHT")
	else
		panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT")
		panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")
		panel.edge:SetPoint("TOPLEFT")
		panel.edge:SetPoint("TOPRIGHT")
	end
	panel:SetHeight(cfg.height)
	panel.bg:SetColorTexture(0.04, 0.04, 0.06, cfg.alpha)
	local _, class = UnitClass("player")
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	panel.edge:SetColorTexture(c and c.r or 0.2, c and c.g or 0.6, c and c.b or 1, 0.8)
	panel:SetShown(cfg.enabled)
	-- Keep the readouts clear of the bag bar on the right.
	panel.info:SetPoint("RIGHT", panel, "CENTER", panel:GetWidth() * 0.25, 0)

	if self.infoTicker then self.infoTicker:Cancel(); self.infoTicker = nil end
	if cfg.enabled then
		self.infoTicker = C_Timer.NewTicker(0.25, function() pcall(UpdateInfo) end)
		pcall(UpdateInfo)
	end

	-- Bags and menu buttons: the panel places them when on, TitanBars/Blizzard when off.
	self:ApplyExtras()
	DockBuffs()
end

-- Turning the panel or docking off hands frames back; a reload puts Blizzard's spots back.
function TB:SetPanel(key, value)
	local cfg = self:PanelCfg()
	local wasOn, wasDocked = cfg.enabled, cfg.enabled and cfg.dockBuffs
	cfg[key] = value
	self:ApplyPanel()
	local nowOn = cfg.enabled
	if (wasOn and not nowOn) or (wasDocked and not (cfg.enabled and cfg.dockBuffs)) then
		self:Print("Type /reload to put the bags, menu buttons and buffs back in their usual spots.")
	end
	self:RefreshPanelWindow()
end

---------------------------------------------------------------------------
-- Settings window (/tb panel)
---------------------------------------------------------------------------
local win

local function Check(y, label, key)
	local c = CreateFrame("CheckButton", nil, win)
	c:SetSize(24, 24)
	c:SetPoint("TOPLEFT", 16, y)
	c:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	c:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	c:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	c:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	c.text:SetPoint("LEFT", c, "RIGHT", 4, 0)
	c.text:SetText(label)
	c:SetScript("OnClick", function(self) TB:SetPanel(key, self:GetChecked() and true or false) end)
	c.key = key
	return c
end

local function Slider(y, label, key, lo, hi, step, fmt)
	local s = CreateFrame("Slider", nil, win, "UISliderTemplateWithLabels")
	s:SetPoint("TOPLEFT", 22, y)
	s:SetSize(250, 17)
	s:SetMinMaxValues(lo, hi)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s.Low:SetText(fmt(lo))
	s.High:SetText(fmt(hi))
	s:SetScript("OnValueChanged", function(self, v)
		self.Text:SetText(label .. ": " .. fmt(v))
		if win.refreshing then return end
		TB:PanelCfg()[key] = v
		TB:ApplyPanel()
	end)
	s.key = key
	s.fmt = fmt
	s.label = label
	return s
end

local function BuildWindow()
	win = CreateFrame("Frame", "TitanBarsPanelConfig", UIParent, "BasicFrameTemplateWithInset")
	win:SetSize(320, 560)
	win:SetPoint("CENTER")
	win:SetFrameStrata("HIGH")
	win:SetMovable(true)
	win:SetClampedToScreen(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop", win.StopMovingOrSizing)
	tinsert(UISpecialFrames, "TitanBarsPanelConfig")

	local title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -5)
	title:SetText("TitanBars panel")

	win.checks = {
		Check(-34, "Show the panel", "enabled"),
		Check(-62, "Dock buffs and debuffs to the panel", "dockBuffs"),
	}
	local head = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	head:SetPoint("TOPLEFT", 22, -300)
	head:SetText("Show on the panel")
	for i, r in ipairs(READOUTS) do
		win.checks[#win.checks + 1] = Check(-316 - (i - 1) * 26, r.label, r.key)
	end

	win.posBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	win.posBtn:SetSize(180, 24)
	win.posBtn:SetPoint("TOPLEFT", 22, -100)
	win.posBtn:SetScript("OnClick", function()
		TB:SetPanel("position", TB:PanelCfg().position == "top" and "bottom" or "top")
	end)

	win.sliders = {
		Slider(-152, "Height", "height", 20, 48, 1, function(v) return tostring(math.floor(v + 0.5)) end),
		Slider(-202, "Background", "alpha", 0, 1, 0.05, function(v) return ("%d%%"):format(v * 100 + 0.5) end),
	}

	local help = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	help:SetPoint("TOPLEFT", 22, -238)
	help:SetWidth(256)
	help:SetJustifyH("LEFT")
	help:SetText("The bag bar and menu buttons sit on the right of the panel. To keep the game world off it, use TitanFrames' viewport (/tf).")
end

function TB:RefreshPanelWindow()
	if not win or not win:IsShown() then return end
	local cfg = self:PanelCfg()
	win.refreshing = true
	for _, c in ipairs(win.checks) do c:SetChecked(cfg[c.key]) end
	for _, s in ipairs(win.sliders) do
		s:SetValue(cfg[s.key])
		s.Text:SetText(s.label .. ": " .. s.fmt(cfg[s.key]))
	end
	win.posBtn:SetText("Position: " .. (cfg.position == "top" and "Top" or "Bottom"))
	win.refreshing = false
end

function TB:TogglePanelWindow()
	if not win then BuildWindow() end
	win:SetShown(not win:IsShown())
	self:RefreshPanelWindow()
end

-- /tb panel [on|off|top|bottom]
function TB:PanelCommand(arg)
	arg = (arg or ""):lower()
	if arg == "on" or arg == "off" then
		self:SetPanel("enabled", arg == "on")
	elseif arg == "top" or arg == "bottom" then
		self:SetPanel("position", arg)
		if not self:PanelCfg().enabled then self:SetPanel("enabled", true) end
	else
		self:TogglePanelWindow()
	end
end

function TB:SetupPanel()
	if panel then return end
	CreatePanel()
	HookBuffs()
	self:ApplyPanel()
	-- The bag bar and menu buttons finish their own layout after login; place them again then.
	C_Timer.After(1, function() TB:ApplyPanel() end)
end
