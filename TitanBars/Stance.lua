-- TitanBars: the stance / forms bar (bar 9). Bear, Cat, Travel and so on as a
-- normal TitanBars bar: move it, resize it, bind keys to it.
local ADDON, TB = ...

function TB.NumForms()
	return GetNumShapeshiftForms() or 0
end

local function CountdownHidden()
	return not GetCVarBool("countdownForCooldowns")
end

function TB:CreateStanceButton(bar, i)
	local name = bar:GetName() .. "Button" .. i
	-- Blizzard's small button art, like their own stance bar; the click casts the form.
	local btn = CreateFrame("CheckButton", name, bar, "SmallActionButtonTemplate, SecureActionButtonTemplate")
	btn:SetID(i)
	btn.titanBar, btn.titanIndex = bar.id, i
	btn:RegisterForClicks("AnyUp")
	btn:SetAttribute("type", "spell")

	-- Same hidden key twin as the action bars, so the key casts on key down.
	local key = CreateFrame("Button", name .. "Key", btn, "SecureActionButtonTemplate")
	key:SetSize(1, 1)
	key:EnableMouse(false)
	key:SetAttribute("type", "spell")
	key:RegisterForClicks("AnyDown", "AnyUp")
	key:HookScript("OnClick", function(_, _, down)
		btn:SetButtonState(down and "PUSHED" or "NORMAL")
	end)
	btn.titanKey = key

	-- A click flips the checked state; put it back to the real form.
	btn:HookScript("OnClick", function() TB:UpdateStanceState() end)
	btn:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetShapeshift(i)
		GameTooltip:Show()
		TB:OnButtonEnter(self)
	end)
	btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
	return btn
end

-- Which spell each button casts. Secure attributes, so out of combat only
-- (you can't learn a form in combat anyway).
function TB:UpdateStanceSpells()
	local bar = self.bars[self.STANCE_BAR]
	if not bar then return end
	self:RunOutOfCombat("stanceSpells", function()
		local n = TB.NumForms()
		for i, btn in ipairs(bar.buttons) do
			local spellID
			if i <= n then spellID = select(4, GetShapeshiftFormInfo(i)) end
			btn:SetAttribute("spell", spellID)
			btn.titanKey:SetAttribute("spell", spellID)
		end
		TB:LayoutBar(TB.STANCE_BAR)
	end, true)
	self:UpdateStanceState()
end

local function UpdateButton(btn, i, hideNumbers)
	local texture, isActive, isCastable = GetShapeshiftFormInfo(i)
	btn.icon:SetTexture(texture)
	btn:SetChecked(isActive and true or false)
	if isCastable then
		btn.icon:SetVertexColor(1, 1, 1)
	else
		btn.icon:SetVertexColor(0.4, 0.4, 0.4)
	end
	btn.cooldown:SetHideCountdownNumbers(hideNumbers)
	CooldownFrame_Set(btn.cooldown, GetShapeshiftFormCooldown(i))
end

-- Icons, the lit-up current form, greyed-out forms and cooldowns. Safe in combat.
function TB:UpdateStanceState()
	local bar = self.bars[self.STANCE_BAR]
	if not bar then return end
	local n, hideNumbers = self.NumForms(), CountdownHidden()
	for i, btn in ipairs(bar.buttons) do
		if i <= n then
			-- The client can hide some combat values from addons; skip a button rather than error.
			pcall(UpdateButton, btn, i, hideNumbers)
		end
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
events:RegisterEvent("UPDATE_SHAPESHIFT_USABLE")
events:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN")
events:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
events:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_SHAPESHIFT_FORMS" or event == "SPELLS_CHANGED" then
		TB:UpdateStanceSpells()
	else
		TB:UpdateStanceState()
	end
end)

if CVarCallbackRegistry then
	CVarCallbackRegistry:RegisterCallback("countdownForCooldowns", function() TB:UpdateStanceState() end, TB)
end
