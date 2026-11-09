-- TitanFrames: move and resize the minimap, party frames, raid frames and XP bar,
-- and show map coordinates on the minimap.
-- Once you move or resize a frame here, TitanFrames owns its size and position and
-- re-applies them whenever Blizzard (Edit Mode, roster changes) puts it back.
local ADDON, TF = ...
_G.TitanFrames = TF

TF.FRAMES = {
	{ key = "minimap", name = "MinimapCluster",            label = "Minimap" },
	{ key = "party",   name = "PartyFrame",                label = "Party frames" },
	{ key = "raid",    name = "CompactRaidFrameContainer", label = "Raid frames" },
	-- The status bars only show when there's something to track (XP, rep, honor).
	{ key = "xp",      name = "MainStatusTrackingBarContainer",      label = "XP bar" },
	{ key = "xp2",     name = "SecondaryStatusTrackingBarContainer", label = "Second bar (rep/honor)" },
}

local MIN_SCALE, MAX_SCALE = 0.3, 3

function TF:Print(msg)
	print("|cff33ccffTitanFrames|r: " .. msg)
end

function TF:Cfg(key)
	TitanFramesDB[key] = TitanFramesDB[key] or {}
	return TitanFramesDB[key]
end

local function EditModeActive()
	return EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()
end

-- Positions are stored as the frame's top-left corner in UIParent units, so they
-- stay put when the scale changes (and raid/party frames grow downward).
local function RelScale(f)
	return f:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local applying = {}
local pending = false

-- Party and raid frames are locked in combat. Addons can't move them then, but a
-- secure handler can, so this one puts them back the moment a fight starts.
local guard = CreateFrame("Frame", "TitanFramesCombatGuard", UIParent, "SecureHandlerStateTemplate")
guard:SetAttribute("_onstate-combat", [[
	if newstate ~= "1" then return end
	for i = 1, 2 do
		local key = (i == 1) and "party" or "raid"
		local f = self:GetFrameRef(key)
		local x, y = self:GetAttribute(key .. "-x"), self:GetAttribute(key .. "-y")
		local scale = self:GetAttribute(key .. "-scale")
		if f and scale then f:SetScale(scale) end
		if f and x and y then
			f:ClearAllPoints()
			-- "$screen" is the screen corner, the same spot as UIParent's.
			f:SetPoint("TOPLEFT", "$screen", "BOTTOMLEFT", x, y)
		end
	end
]])

-- Hands the guard the current spot (in the frame's own units) out of combat.
local function UpdateGuard(info, f, cfg)
	if info.key ~= "party" and info.key ~= "raid" then return end
	if InCombatLockdown() or not f:IsProtected() then return end
	guard:SetFrameRef(info.key, f)
	guard:SetAttribute(info.key .. "-scale", cfg.scale)
	local x, y
	if cfg.pos then
		local rel = RelScale(f)
		x, y = cfg.pos.x / rel, cfg.pos.y / rel
	end
	guard:SetAttribute(info.key .. "-x", x)
	guard:SetAttribute(info.key .. "-y", y)
end

function TF:Apply(info)
	local f = _G[info.name]
	if not f then return end
	local cfg = self:Cfg(info.key)
	if not cfg.scale and not cfg.pos then
		UpdateGuard(info, f, cfg)
		return
	end
	-- Only party/raid frames are locked in combat; the XP bar and minimap can be
	-- put back straight away when Blizzard re-stacks them.
	if f:IsProtected() and InCombatLockdown() then
		pending = true
		return
	end
	applying[f] = true
	if cfg.scale then f:SetScale(cfg.scale) end
	if cfg.pos then
		local rel = RelScale(f)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cfg.pos.x / rel, cfg.pos.y / rel)
	end
	applying[f] = nil
	UpdateGuard(info, f, cfg)
	if info.mover then self:PlaceMover(info) end
end

function TF:ApplyAll()
	for _, info in ipairs(self.FRAMES) do self:Apply(info) end
end

-- Blizzard re-anchors and re-scales these frames often; put ours back after it does.
local function Hook(info)
	local f = _G[info.name]
	if not f or info.hooked then return end
	info.hooked = true
	local function Reapply()
		if applying[f] or EditModeActive() then return end
		TF:Apply(info)
	end
	hooksecurefunc(f, "SetPoint", Reapply)
	hooksecurefunc(f, "SetAllPoints", Reapply)
	hooksecurefunc(f, "SetScale", Reapply)
end

local function ReapplyAll()
	if EditModeActive() then return end
	TF:ApplyAll()
end

function TF:Setup()
	for _, info in ipairs(self.FRAMES) do Hook(info) end
	-- Edit Mode re-stacks the XP bar (and others) above the bag bar whenever the
	-- bottom bars change, which happens on entering combat.
	if EditModeManagerFrame and EditModeManagerFrame.UpdateBottomActionBarPositions and not self.editModeHooked then
		self.editModeHooked = true
		hooksecurefunc(EditModeManagerFrame, "UpdateBottomActionBarPositions", ReapplyAll)
	end
	self:ApplyAll()
end

---------------------------------------------------------------------------
-- Movers
---------------------------------------------------------------------------
local function CurrentTopLeft(f)
	local left, top = f:GetLeft(), f:GetTop()
	if not left or not top then return nil end
	local rel = RelScale(f)
	return { x = left * rel, y = top * rel }
end

function TF:PlaceMover(info)
	local m, f = info.mover, _G[info.name]
	local cfg = self:Cfg(info.key)
	local pos = cfg.pos or (f and CurrentTopLeft(f)) or { x = UIParent:GetWidth() / 2, y = UIParent:GetHeight() / 2 }
	local w, h = 0, 0
	if f and f:GetWidth() then
		local rel = RelScale(f)
		w, h = f:GetWidth() * rel, f:GetHeight() * rel
	end
	-- Party/raid frames have no size when you're not grouped; keep the handle grabbable.
	m:SetSize(math.max(w, 140), math.max(h, 40))
	m:ClearAllPoints()
	m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
	local scale = cfg.scale or (f and f:GetScale()) or 1
	m.label:SetText(("%s  %d%%"):format(info.label, scale * 100 + 0.5))
end

local function CreateMover(info)
	local m = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	m:SetFrameStrata("DIALOG")
	m:SetClampedToScreen(true)
	m:SetMovable(true)
	m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	m:SetBackdropColor(0.9, 0.5, 0.1, 0.4)
	m:SetBackdropBorderColor(1, 0.7, 0.2, 1)
	m.label = m:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	m.label:SetPoint("CENTER")
	m:EnableMouse(true)
	m:EnableMouseWheel(true)
	m:RegisterForDrag("LeftButton")

	m:SetScript("OnDragStart", function(self) self:StartMoving() end)
	m:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		TF:Cfg(info.key).pos = { x = self:GetLeft(), y = self:GetTop() }
		TF:Apply(info)
	end)
	m:SetScript("OnMouseWheel", function(_, delta)
		local f = _G[info.name]
		local cfg = TF:Cfg(info.key)
		if not cfg.pos and f then cfg.pos = CurrentTopLeft(f) end
		local step = IsShiftKeyDown() and 0.01 or 0.05
		local s = (cfg.scale or (f and f:GetScale()) or 1) + delta * step
		cfg.scale = math.max(MIN_SCALE, math.min(MAX_SCALE, math.floor(s * 100 + 0.5) / 100))
		TF:Apply(info)
		TF:RefreshWindow()
	end)
	m:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then TF:ResetFrame(info) end
	end)
	m:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(info.label)
		GameTooltip:AddLine("Drag to move", 1, 1, 1)
		GameTooltip:AddLine("Mouse wheel to resize (Shift for fine steps)", 1, 1, 1)
		GameTooltip:AddLine("Right-click to give it back to Blizzard / Edit Mode", 1, 1, 1)
		GameTooltip:Show()
	end)
	m:SetScript("OnLeave", function() GameTooltip:Hide() end)
	m:Hide()
	info.mover = m
	return m
end

function TF:SetUnlocked(on)
	if on and InCombatLockdown() then
		self:Print("Can't move frames in combat.")
		return
	end
	self.unlocked = on
	for _, info in ipairs(self.FRAMES) do
		local m = info.mover or CreateMover(info)
		if on then
			self:PlaceMover(info)
			m:Show()
		else
			m:Hide()
		end
	end
	self:RefreshWindow()
	self:Print(on and "Unlocked. Drag to move, mouse wheel to resize, /tf lock when done." or "Locked.")
end

function TF:ResetFrame(info)
	TitanFramesDB[info.key] = nil
	self:Apply(info) -- clears the combat guard's copy too
	if info.mover then self:PlaceMover(info) end
	self:RefreshWindow()
	self:Print(info.label .. " handed back to Blizzard. Type /reload to restore its Edit Mode spot.")
end

---------------------------------------------------------------------------
-- Map coordinates at the bottom of the minimap. Blank inside dungeons, where the
-- game doesn't give a position.
---------------------------------------------------------------------------
local coords

function TF:CoordsEnabled()
	local cfg = self:Cfg("coords")
	return cfg.enabled ~= false
end

local function UpdateCoords()
	local text = ""
	local mapID = C_Map.GetBestMapForUnit("player")
	local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	if pos then
		local x, y = pos:GetXY()
		if x and y and (x > 0 or y > 0) then
			text = ("%.1f, %.1f"):format(x * 100, y * 100)
		end
	end
	coords.text:SetText(text)
	coords:SetShown(text ~= "")
end

function TF:UpdateCoords()
	if not Minimap then return end
	if not coords then
		coords = CreateFrame("Frame", nil, Minimap)
		coords:SetSize(80, 16)
		coords:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 6)
		coords:SetFrameLevel(Minimap:GetFrameLevel() + 5)
		coords.bg = coords:CreateTexture(nil, "BACKGROUND")
		coords.bg:SetAllPoints()
		coords.bg:SetColorTexture(0, 0, 0, 0.5)
		coords.text = coords:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		coords.text:SetPoint("CENTER")
	end
	if self.coordsTicker then
		self.coordsTicker:Cancel()
		self.coordsTicker = nil
	end
	if self:CoordsEnabled() then
		self.coordsTicker = C_Timer.NewTicker(0.2, function() pcall(UpdateCoords) end)
		pcall(UpdateCoords)
	else
		coords:Hide()
	end
end

---------------------------------------------------------------------------
-- Settings window (/tf)
---------------------------------------------------------------------------
local win
local refreshing = false

local function BuildWindow()
	win = CreateFrame("Frame", "TitanFramesConfig", UIParent, "BasicFrameTemplateWithInset")
	win:SetSize(320, 450)
	win:SetPoint("CENTER")
	win:SetFrameStrata("HIGH")
	win:SetMovable(true)
	win:SetClampedToScreen(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop", win.StopMovingOrSizing)
	tinsert(UISpecialFrames, "TitanFramesConfig")

	local title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -5)
	title:SetText("TitanFrames")

	win.sliders = {}
	for n, info in ipairs(TF.FRAMES) do
		local s = CreateFrame("Slider", nil, win, "UISliderTemplateWithLabels")
		s:SetPoint("TOPLEFT", 24, -30 - n * 50)
		s:SetSize(200, 17)
		s:SetMinMaxValues(MIN_SCALE, MAX_SCALE)
		s:SetValueStep(0.05)
		s:SetObeyStepOnDrag(true)
		s.Low:SetText(("%d%%"):format(MIN_SCALE * 100))
		s.High:SetText(("%d%%"):format(MAX_SCALE * 100))
		s:SetScript("OnValueChanged", function(self, v)
			self.Text:SetText(("%s: %d%%"):format(info.label, v * 100 + 0.5))
			if refreshing then return end
			local cfg = TF:Cfg(info.key)
			local f = _G[info.name]
			if not cfg.pos and f then cfg.pos = CurrentTopLeft(f) end
			cfg.scale = v
			TF:Apply(info)
		end)
		local reset = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
		reset:SetSize(60, 22)
		reset:SetPoint("LEFT", s, "RIGHT", 14, 0)
		reset:SetText("Reset")
		reset:SetScript("OnClick", function() TF:ResetFrame(info) end)
		s.info = info
		win.sliders[n] = s
	end

	local c = CreateFrame("CheckButton", nil, win)
	c:SetSize(24, 24)
	c:SetPoint("TOPLEFT", 20, -312)
	c:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	c:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	c:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	c:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	c.text:SetPoint("LEFT", c, "RIGHT", 4, 0)
	c.text:SetText("Show map coordinates on the minimap")
	c:SetScript("OnClick", function(self)
		TF:Cfg("coords").enabled = self:GetChecked() and true or false
		TF:UpdateCoords()
	end)
	win.coordsCheck = c

	win.lockBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	win.lockBtn:SetSize(120, 22)
	win.lockBtn:SetPoint("BOTTOM", 0, 50)
	win.lockBtn:SetScript("OnClick", function() TF:SetUnlocked(not TF.unlocked) end)

	local help = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	help:SetPoint("BOTTOM", 0, 14)
	help:SetWidth(280)
	help:SetText("Unlock to drag frames around. Frames you change here ignore Edit Mode until you Reset them.")
end

function TF:RefreshWindow()
	if not win or not win:IsShown() then return end
	refreshing = true
	for _, s in ipairs(win.sliders) do
		local f = _G[s.info.name]
		local scale = self:Cfg(s.info.key).scale or (f and f:GetScale()) or 1
		s:SetValue(scale)
		s.Text:SetText(("%s: %d%%"):format(s.info.label, scale * 100 + 0.5))
	end
	win.coordsCheck:SetChecked(self:CoordsEnabled())
	win.lockBtn:SetText(self.unlocked and "Lock frames" or "Unlock frames")
	refreshing = false
end

function TF:ToggleWindow()
	if not win then BuildWindow() end
	win:SetShown(not win:IsShown())
	self:RefreshWindow()
end

---------------------------------------------------------------------------
-- Events and slash commands
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON then
			TitanFramesDB = TitanFramesDB or {}
		elseif TF.ready then
			-- Raid frames can load after us.
			TF:Setup()
		end
	elseif event == "PLAYER_LOGIN" then
		TF.ready = true
		TF:Setup()
		TF:UpdateCoords()
		RegisterStateDriver(guard, "combat", "[combat] 1; 0")
		if EventRegistry then
			EventRegistry:RegisterCallback("EditMode.Exit", function() TF:ApplyAll() end, TF)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		TF:ApplyAll()
	elseif event == "PLAYER_REGEN_DISABLED" then
		if TF.unlocked then TF:SetUnlocked(false) end
		-- Catch anything Blizzard moves as combat starts, now and once it settles.
		ReapplyAll()
		C_Timer.After(0, ReapplyAll)
		C_Timer.After(0.5, ReapplyAll)
	elseif event == "PLAYER_REGEN_ENABLED" and pending then
		pending = false
		TF:ApplyAll()
	end
end)

SLASH_TITANFRAMES1 = "/tf"
SLASH_TITANFRAMES2 = "/titanframes"
SlashCmdList.TITANFRAMES = function(msg)
	local cmd = strtrim(msg or ""):lower()
	if cmd == "" then
		TF:ToggleWindow()
	elseif cmd == "unlock" then
		TF:SetUnlocked(true)
	elseif cmd == "lock" then
		TF:SetUnlocked(false)
	elseif cmd == "reset" then
		for _, info in ipairs(TF.FRAMES) do TF:ResetFrame(info) end
	else
		TF:Print("/tf - settings   /tf unlock   /tf lock   /tf reset")
	end
end
