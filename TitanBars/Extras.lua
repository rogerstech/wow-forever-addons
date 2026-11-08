-- TitanBars: the bag bar and the menu buttons (character, spellbook, professions...).
-- These stay Blizzard's own frames; TitanBars just moves, resizes and strips their art.
local ADDON, TB = ...

TB.EXTRAS = {
	{ key = "bags",  name = "BagsBar",            label = "Bags" },
	{ key = "micro", name = "MicroMenuContainer", label = "Menu buttons" },
}

local applying = {}

function TB:ExtraCfg(key)
	self.db.extras[key] = self.db.extras[key] or {}
	return self.db.extras[key]
end

local function EditModeActive()
	return EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()
end

local function RelScale(f)
	return f:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function CurrentTopLeft(f)
	local left, top = f:GetLeft(), f:GetTop()
	if not left or not top then return nil end
	local rel = RelScale(f)
	return { x = left * rel, y = top * rel }
end

-- Positions are the frame's top-left corner in UIParent units.
function TB:ApplyExtra(info)
	local f = _G[info.name]
	if not f then return end
	local cfg = self:ExtraCfg(info.key)
	if not cfg.scale and not cfg.pos then return end
	if f:IsProtected() and InCombatLockdown() then
		self:RunOutOfCombat("extra" .. info.key, function() TB:ApplyExtra(info) end, true)
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
	if info.mover and info.mover:IsShown() then self:PlaceExtraMover(info) end
end

function TB:ApplyExtras()
	for _, info in ipairs(self.EXTRAS) do self:ApplyExtra(info) end
end

---------------------------------------------------------------------------
-- Art
---------------------------------------------------------------------------
local function HideDividers(bags)
	for _, pool in ipairs({ bags.HorizontalDividersPool, bags.VerticalDividersPool }) do
		if pool then
			for divider in pool:EnumerateActive() do divider:Hide() end
		end
	end
end

function TB:HideExtraArt()
	local textures = {
		BagsBar and BagsBar.BorderArt,
		MicroMenu and MicroMenu.BorderArt,
		MicroMenu and MicroMenu.BackgroundArt,
	}
	for n = 1, 3 do
		if textures[n] then textures[n]:SetAlpha(0) end
	end
	if BagsBar and BagsBar.UpdateDividers then
		hooksecurefunc(BagsBar, "UpdateDividers", HideDividers)
		HideDividers(BagsBar)
	end
end

---------------------------------------------------------------------------
-- Setup: Blizzard re-anchors these on layout changes, so put ours back after.
---------------------------------------------------------------------------
function TB:SetupExtras()
	for _, info in ipairs(self.EXTRAS) do
		local f = _G[info.name]
		if f and not info.hooked then
			info.hooked = true
			local function Reapply()
				if applying[f] or EditModeActive() then return end
				TB:ApplyExtra(info)
			end
			hooksecurefunc(f, "SetPoint", Reapply)
			hooksecurefunc(f, "SetScale", Reapply)
		end
	end
	if self.db.hideExtraArt then self:HideExtraArt() end
	self:ApplyExtras()
	if EventRegistry then
		EventRegistry:RegisterCallback("EditMode.Exit", function() TB:ApplyExtras() end, TB)
	end
end

---------------------------------------------------------------------------
-- Movers (shown with the bar movers by /tb unlock)
---------------------------------------------------------------------------
function TB:PlaceExtraMover(info)
	local m, f = info.mover, _G[info.name]
	local cfg = self:ExtraCfg(info.key)
	local pos = cfg.pos or (f and CurrentTopLeft(f)) or { x = UIParent:GetWidth() - 300, y = 120 }
	local w, h = 0, 0
	if f and f:GetWidth() then
		local rel = RelScale(f)
		w, h = f:GetWidth() * rel, f:GetHeight() * rel
	end
	m:SetSize(math.max(w, 80), math.max(h, 30))
	m:ClearAllPoints()
	m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
	local scale = cfg.scale or (f and f:GetScale()) or 1
	m.label:SetText(("%s  %d%%"):format(info.label, scale * 100 + 0.5))
end

local function CreateExtraMover(info)
	local m = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	m:SetFrameStrata("DIALOG")
	m:SetClampedToScreen(true)
	m:SetMovable(true)
	m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	m:SetBackdropColor(0.1, 0.5, 0.9, 0.45)
	m:SetBackdropBorderColor(0.3, 0.8, 1, 1)
	m.label = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	m.label:SetPoint("CENTER")
	m:EnableMouse(true)
	m:EnableMouseWheel(true)
	m:RegisterForDrag("LeftButton")

	m:SetScript("OnDragStart", function(self) self:StartMoving() end)
	m:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		TB:ExtraCfg(info.key).pos = { x = self:GetLeft(), y = self:GetTop() }
		TB:ApplyExtra(info)
	end)
	m:SetScript("OnMouseWheel", function(_, delta)
		local f = _G[info.name]
		local cfg = TB:ExtraCfg(info.key)
		if not cfg.pos and f then cfg.pos = CurrentTopLeft(f) end
		local step = IsShiftKeyDown() and 0.01 or 0.05
		local s = (cfg.scale or (f and f:GetScale()) or 1) + delta * step
		cfg.scale = math.max(0.3, math.min(3, math.floor(s * 100 + 0.5) / 100))
		TB:ApplyExtra(info)
		TB:PlaceExtraMover(info)
		if TB.RefreshConfig then TB:RefreshConfig() end
	end)
	m:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then TB:ResetExtra(info) end
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

function TB:SetExtrasUnlocked(on)
	for _, info in ipairs(self.EXTRAS) do
		local m = info.mover or CreateExtraMover(info)
		if on then
			self:PlaceExtraMover(info)
			m:Show()
		else
			m:Hide()
		end
	end
end

function TB:ResetExtra(info)
	self.db.extras[info.key] = nil
	if info.mover and info.mover:IsShown() then self:PlaceExtraMover(info) end
	if self.RefreshConfig then self:RefreshConfig() end
	self:Print(info.label .. " handed back to Blizzard. Type /reload to restore its Edit Mode spot.")
end
