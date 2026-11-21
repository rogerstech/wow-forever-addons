-- TitanFrames square minimap: square mask, no round border art, a thin dark border,
-- and a size you can set with a slider or by dragging the corner grip while unlocked.
-- Off by default; tick "Square minimap" in /tf.
local ADDON, TF = ...

local DEFAULT_SIZE = 198   -- Blizzard's Minimap size on Forever
local MIN_SIZE, MAX_SIZE = 120, 500
local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"

local border, grip

function TF:SquareCfg()
	local cfg = self:Cfg("square")
	if cfg.enabled == nil then cfg.enabled = false end
	cfg.size = math.max(MIN_SIZE, math.min(MAX_SIZE, tonumber(cfg.size) or DEFAULT_SIZE))
	return cfg
end

local function MakeBorder()
	border = CreateFrame("Frame", nil, Minimap)
	border:SetAllPoints()
	border:SetFrameLevel(Minimap:GetFrameLevel() + 2)
	local spec = {
		{ "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
	}
	for _, s in ipairs(spec) do
		local l = border:CreateTexture(nil, "OVERLAY")
		l:SetColorTexture(0, 0, 0, 1)
		l:SetPoint(s[1], border, s[1], (s[1]:find("LEFT") and -1 or 1), (s[1]:find("TOP") and 1 or -1))
		l:SetPoint(s[2], border, s[2], (s[2]:find("LEFT") and -1 or 1), (s[2]:find("TOP") and 1 or -1))
		if s[3] then l:SetHeight(1) else l:SetWidth(1) end
	end
end

local applying = false

function TF:ApplySquare()
	if not Minimap then return end
	local cfg = self:SquareCfg()
	applying = true
	if cfg.enabled then
		if not border then MakeBorder() end
		Minimap:SetMaskTexture(SQUARE_MASK)
		if MinimapCompassTexture then MinimapCompassTexture:SetAlpha(0) end
		if MinimapCompassTextureUnderlay then MinimapCompassTextureUnderlay:SetAlpha(0) end
		Minimap:SetSize(cfg.size, cfg.size)
		border:Show()
		self.squareTouched = true
	elseif self.squareTouched then
		-- Hand it back: Blizzard's own config call puts the round mask and art back.
		if MinimapCompassTexture then MinimapCompassTexture:SetAlpha(1) end
		if MinimapCompassTextureUnderlay then MinimapCompassTextureUnderlay:SetAlpha(1) end
		Minimap:SetSize(DEFAULT_SIZE, DEFAULT_SIZE)
		if border then border:Hide() end
		if MinimapCluster and MinimapCluster.UpdateMinimapConfig then
			MinimapCluster:UpdateMinimapConfig()
		end
		self.squareTouched = false
	end
	applying = false
	if grip then grip:SetShown(self.unlocked and cfg.enabled) end
end

-- Minimap-button addons ask this to know how to lay their icons around the edge.
if not GetMinimapShape then
	function GetMinimapShape()
		return (TitanFramesDB and TitanFramesDB.square and TitanFramesDB.square.enabled) and "SQUARE" or "ROUND"
	end
end

---------------------------------------------------------------------------
-- Corner grip (shown while /tf unlock is on). The minimap grows from its centre,
-- so the size is twice the cursor's distance from the centre.
---------------------------------------------------------------------------
local function GripUpdate()
	local s = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	cx, cy = cx / s, cy / s
	local mx, my = Minimap:GetCenter()
	if not mx then return end
	local size = 2 * math.max(math.abs(cx - mx), math.abs(cy - my))
	size = math.floor(math.max(MIN_SIZE, math.min(MAX_SIZE, size)) + 0.5)
	local cfg = TF:SquareCfg()
	if size ~= cfg.size then
		cfg.size = size
		TF:ApplySquare()
		TF:RefreshWindow()
	end
end

local function MakeGrip()
	grip = CreateFrame("Button", nil, Minimap)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", 0, 0)
	grip:SetFrameStrata("FULLSCREEN") -- above the blue drag box /tf unlock puts over the minimap
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then self:SetScript("OnUpdate", GripUpdate) end
	end)
	local function Stop(self) self:SetScript("OnUpdate", nil) end
	grip:SetScript("OnMouseUp", Stop)
	grip:SetScript("OnHide", Stop)
	grip:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Drag to resize the minimap")
		GameTooltip:Show()
	end)
	grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
	grip:Hide()
end

---------------------------------------------------------------------------
-- Settings controls, added to the /tf window by BuildWindow.
---------------------------------------------------------------------------
local check, slider
local refreshing = false

function TF:BuildSquareControls(c, y)
	local head = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	head:SetPoint("TOPLEFT", 20, y)
	head:SetText("Minimap shape")

	check = CreateFrame("CheckButton", nil, c)
	check:SetSize(24, 24)
	check:SetPoint("TOPLEFT", 16, y - 18)
	check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	check.text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	check.text:SetPoint("LEFT", check, "RIGHT", 4, 0)
	check.text:SetText("Square minimap")
	check:SetScript("OnClick", function(self)
		TF:SquareCfg().enabled = self:GetChecked() and true or false
		TF:ApplySquare()
	end)

	slider = CreateFrame("Slider", nil, c, "UISliderTemplateWithLabels")
	slider:SetPoint("TOPLEFT", 20, y - 66)
	slider:SetSize(274, 17)
	slider:SetMinMaxValues(MIN_SIZE, MAX_SIZE)
	slider:SetValueStep(2)
	slider:SetObeyStepOnDrag(true)
	slider.Low:SetText(tostring(MIN_SIZE))
	slider.High:SetText(tostring(MAX_SIZE))
	slider:SetScript("OnValueChanged", function(self, v)
		v = math.floor(v + 0.5)
		self.Text:SetText(("Square minimap size: %d"):format(v))
		if refreshing then return end
		TF:SquareCfg().size = v
		TF:ApplySquare()
	end)

	local note = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	note:SetPoint("TOPLEFT", 20, y - 96)
	note:SetWidth(280)
	note:SetJustifyH("LEFT")
	note:SetText("While unlocked, drag the grip in the minimap's bottom-right corner to resize it.")
end

function TF:RefreshSquareControls()
	if not check then return end
	local cfg = self:SquareCfg()
	refreshing = true
	check:SetChecked(cfg.enabled)
	slider:SetValue(cfg.size)
	slider.Text:SetText(("Square minimap size: %d"):format(cfg.size))
	refreshing = false
end

---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
	if not Minimap then return end
	MakeGrip()
	-- Blizzard re-applies the round mask when the rotate-minimap setting changes,
	-- and Edit Mode can reset the size; put ours back after either.
	if MinimapCluster and MinimapCluster.UpdateMinimapConfig then
		hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", function()
			if not applying and TF:SquareCfg().enabled then TF:ApplySquare() end
		end)
	end
	hooksecurefunc(Minimap, "SetSize", function()
		if not applying and TF:SquareCfg().enabled then
			C_Timer.After(0, function() TF:ApplySquare() end)
		end
	end)
	hooksecurefunc(TF, "SetUnlocked", function() TF:ApplySquare() end)
	TF:ApplySquare()
end)
