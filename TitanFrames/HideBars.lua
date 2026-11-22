-- TitanFrames: hide the XP bar and the second status bar (reputation / honor).
-- Forever's Edit Mode only offers a size for these. TitanFrames leaves them where Blizzard
-- keeps them (moving them under another frame broke Blizzard's own code, which expects
-- their parent to be its status-bar manager) and simply hides them again every time
-- Blizzard shows them. Our code only ever runs after Blizzard's, never inside it.
local ADDON, TF = ...

local BARS = {
	{ key = "xp",  name = "MainStatusTrackingBarContainer",      label = "Hide the XP bar" },
	{ key = "xp2", name = "SecondaryStatusTrackingBarContainer", label = "Hide the reputation / honor bar" },
}

local hooked = {}
local hiddenByUs = {}
local waiting = false

function TF:BarHidden(key)
	return self:Cfg("hide")[key] == true
end

local function Enforce(f, key)
	if not TF:BarHidden(key) or not f:IsShown() then return end
	if f:IsProtected() and InCombatLockdown() then
		waiting = true
		return
	end
	f:Hide()
	hiddenByUs[f] = true
end

local function Hook(f, key)
	if hooked[f] then return end
	hooked[f] = true
	local function After() Enforce(f, key) end
	hooksecurefunc(f, "Show", After)
	hooksecurefunc(f, "SetShown", After)
	if f.UpdateShownState then hooksecurefunc(f, "UpdateShownState", After) end
end

function TF:ApplyHiddenBars()
	for _, b in ipairs(BARS) do
		local f = _G[b.name]
		if f then
			Hook(f, b.key)
			if self:BarHidden(b.key) then
				Enforce(f, b.key)
			elseif hiddenByUs[f] then
				hiddenByUs[f] = nil
				-- Let Blizzard decide whether it should show (it hides it when there's nothing to track).
				if f.UpdateShownState then pcall(f.UpdateShownState, f) else f:Show() end
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
	if event == "PLAYER_REGEN_ENABLED" then
		if waiting then
			waiting = false
			TF:ApplyHiddenBars()
		end
	else
		TF:ApplyHiddenBars()
	end
end)
