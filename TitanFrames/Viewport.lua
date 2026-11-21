-- TitanFrames viewport: shrink the area the game world is drawn in, leaving black
-- strips at the edges for bars and meters. The world isn't stretched: the game
-- redraws it for the new shape. WorldFrame can only be moved out of combat, so a
-- change made in combat waits until combat ends.
local ADDON, TF = ...

local SIDES = {
	{ key = "top",    label = "Top" },
	{ key = "bottom", label = "Bottom" },
	{ key = "left",   label = "Left" },
	{ key = "right",  label = "Right" },
}
local MAX = 3000      -- slider limit, in screen units (big enough to blank a whole second monitor)
local MIN_KEEP = 0.25 -- the world always keeps at least a quarter of the screen each way

local pending = false
local touched = false -- true once we've moved WorldFrame this session

function TF:ViewportCfg()
	local cfg = self:Cfg("viewport")
	for _, s in ipairs(SIDES) do
		cfg[s.key] = tonumber(cfg[s.key]) or 0
	end
	return cfg
end

-- Screen size in WorldFrame's own units.
local function ScreenSize()
	local s = UIParent:GetEffectiveScale() / WorldFrame:GetEffectiveScale()
	return UIParent:GetWidth() * s, UIParent:GetHeight() * s
end

-- Shrink a pair of edges together so the world keeps MIN_KEEP of the screen.
local function Fit(a, b, total)
	local room = total * (1 - MIN_KEEP)
	if a + b <= room then return a, b end
	local k = room / (a + b)
	return math.floor(a * k), math.floor(b * k)
end

function TF:ApplyViewport()
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	local cfg = self:ViewportCfg()
	local any = cfg.top + cfg.bottom + cfg.left + cfg.right > 0
	-- Never touch WorldFrame for someone who hasn't used the viewport.
	if not any and not touched then return end
	local ok, err = pcall(function()
		local w, h = ScreenSize()
		local left, right = Fit(cfg.left, cfg.right, w)
		local top, bottom = Fit(cfg.top, cfg.bottom, h)
		WorldFrame:ClearAllPoints()
		WorldFrame:SetPoint("TOPLEFT", left, -top)
		WorldFrame:SetPoint("BOTTOMRIGHT", -right, bottom)
	end)
	touched = true
	if not ok then
		self:Print("viewport error (please send this to Adam): " .. tostring(err))
	end
end

function TF:ResetViewport()
	local cfg = self:ViewportCfg()
	for _, s in ipairs(SIDES) do cfg[s.key] = 0 end
	self:ApplyViewport()
	self:RefreshWindow()
	if InCombatLockdown() then self:Print("viewport resets when combat ends.") end
end

---------------------------------------------------------------------------
-- Settings controls, added to the /tf window by BuildWindow.
---------------------------------------------------------------------------
local sliders = {}
local refreshing = false

function TF:BuildViewportControls(c, y)
	local head = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	head:SetPoint("TOPLEFT", 20, y)
	head:SetText("Viewport (game world area)")

	local reset = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
	reset:SetSize(60, 22)
	reset:SetPoint("TOPLEFT", 234, y + 4)
	reset:SetText("Reset")
	reset:SetScript("OnClick", function() TF:ResetViewport() end)

	for n, side in ipairs(SIDES) do
		local s = CreateFrame("Slider", nil, c, "UISliderTemplateWithLabels")
		s:SetPoint("TOPLEFT", 20, y - 10 - n * 50)
		s:SetSize(274, 17)
		s:SetMinMaxValues(0, MAX)
		s:SetValueStep(5)
		s:SetObeyStepOnDrag(true)
		s.Low:SetText("0")
		s.High:SetText(tostring(MAX))
		s:SetScript("OnValueChanged", function(self, v)
			v = math.floor(v + 0.5)
			self.Text:SetText(("%s edge: %d"):format(side.label, v))
			if refreshing then return end
			TF:ViewportCfg()[side.key] = v
			TF:ApplyViewport()
		end)
		s.key = side.key
		sliders[n] = s
	end

	local note = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	note:SetPoint("TOPLEFT", 20, y - 248)
	note:SetWidth(280)
	note:SetJustifyH("LEFT")
	note:SetText("Leaves black space at that edge; the world is not stretched. Changes made in combat apply when combat ends.")
end

function TF:RefreshViewportControls()
	local cfg = self:ViewportCfg()
	refreshing = true
	for _, s in ipairs(sliders) do
		s:SetValue(cfg[s.key])
		s.Text:SetText(("%s edge: %d"):format(s.key:gsub("^%l", string.upper), cfg[s.key]))
	end
	refreshing = false
end

---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
ev:RegisterEvent("UI_SCALE_CHANGED")
ev:RegisterEvent("CINEMATIC_STOP")
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		if pending then TF:ApplyViewport() end
	elseif TitanFramesDB then
		TF:ApplyViewport()
	end
end)
