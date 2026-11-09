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
	btn:SetAttribute("type", "macro")
	-- Mouse clicks only send the release. Without this, "cast on key down" makes the
	-- secure template wait for a press that never comes, and the click does nothing.
	btn:SetAttribute("useOnKeyDown", false)

	-- Same hidden key twin as the action bars, so the key casts on key down.
	local key = CreateFrame("Button", name .. "Key", btn, "SecureActionButtonTemplate")
	key:SetSize(1, 1)
	key:EnableMouse(false)
	key:SetAttribute("type", "macro")
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

local warned = {}

-- What each button does. Casting a form you're already in doesn't drop it on this
-- client, so each button is a small macro: leave the form if you're in it, else cast it.
-- [form:N] is checked when you press, so this works in combat. Secure attributes,
-- so they're set out of combat only (you can't learn a form in combat anyway).
function TB:UpdateStanceSpells()
	local bar = self.bars[self.STANCE_BAR]
	if not bar then return end
	self:RunOutOfCombat("stanceSpells", function()
		local n = TB.NumForms()
		for i, btn in ipairs(bar.buttons) do
			local macro
			if i <= n then
				local spellID = select(4, GetShapeshiftFormInfo(i))
				local spellName = spellID and C_Spell.GetSpellName(spellID)
				if spellName then
					macro = ("/cancelform [form:%d]\n/cast [noform:%d] %s"):format(i, i, spellName)
				elseif not warned[i] then
					warned[i] = true
					TB:Print(("Couldn't read the spell for form %d, so its button won't work. Please report this."):format(i))
				end
			end
			btn:SetAttribute("macrotext", macro)
			btn.titanKey:SetAttribute("macrotext", macro)
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
