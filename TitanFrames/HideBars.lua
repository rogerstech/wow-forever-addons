-- TitanFrames: hide the XP bar and the second status bar (reputation / honor).
-- Forever's Edit Mode only offers a size for these, so TitanFrames moves them under a
-- hidden frame. Blizzard sometimes moves them back into its bottom-of-screen layout,
-- so they're hidden again whenever that happens.
local ADDON, TF = ...

local BARS = {
	{ key = "xp",  name = "MainStatusTrackingBarContainer",      label = "Hide the XP bar" },
	{ key = "xp2", name = "SecondaryStatusTrackingBarContainer", label = "Hide the reputation / honor bar" },
}

local hider = CreateFrame("Frame")
hider:Hide()
local origParent = {}
local setting = false
local waiting = false

function TF:BarHidden(key)
	return self:Cfg("hide")[key] == true
end

function TF:ApplyHiddenBars()
	for _, b in ipairs(BARS) do
		local f = _G[b.name]
		if f then
			if f:IsProtected() and InCombatLockdown() then
				waiting = true
			else
				setting = true
				if self:BarHidden(b.key) then
					if f:GetParent() ~= hider then
						origParent[f] = f:GetParent()
						f:SetParent(hider)
					end
				elseif f:GetParent() == hider then
					f:SetParent(origParent[f] or UIParent)
					origParent[f] = nil
				end
				setting = false
			end
		end
	end
end

---------------------------------------------------------------------------
-- Settings controls, added to the /tf window by BuildWindow.
---------------------------------------------------------------------------
local checks = {}

function TF:BuildHideControls(c, y)
	local head = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	head:SetPoint("TOPLEFT", 20, y)
	head:SetText("Status bars")
	for i, b in ipairs(BARS) do
		local check = CreateFrame("CheckButton", nil, c)
		check:SetSize(24, 24)
		check:SetPoint("TOPLEFT", 16, y - 18 - (i - 1) * 28)
		check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
		check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
		check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
		check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
		check.text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		check.text:SetPoint("LEFT", check, "RIGHT", 4, 0)
		check.text:SetText(b.label)
		check:SetScript("OnClick", function(self)
			local hide = self:GetChecked() and true or false
			TF:Cfg("hide")[b.key] = hide or nil
			TF:ApplyHiddenBars()
			if not hide then TF:Print("If the bar doesn't come back in the right spot, type /reload.") end
		end)
		check.key = b.key
		checks[i] = check
	end
end

function TF:RefreshHideControls()
	for _, check in ipairs(checks) do check:SetChecked(self:BarHidden(check.key)) end
end

---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		for _, b in ipairs(BARS) do
			local f = _G[b.name]
			if f then
				hooksecurefunc(f, "SetParent", function()
					if setting or not TF:BarHidden(b.key) then return end
					-- Wait a frame so Blizzard's own layout call finishes first.
					C_Timer.After(0, function() TF:ApplyHiddenBars() end)
				end)
			end
		end
		TF:ApplyHiddenBars()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if waiting then
			waiting = false
			TF:ApplyHiddenBars()
		end
	else
		TF:ApplyHiddenBars()
	end
end)
