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

	bar:SetFrameRef("button" .. i, btn)
	bar:SetFrameRef("key" .. i, key)
	return btn
end

-- Runs in the secure environment whenever your form changes, in or out of combat:
-- the button for the form you're in becomes /cancelform, the rest cast their form.
-- (A two-line "/cancelform [form:N]" + "/cast [noform:N]" macro doesn't work: the
-- form drops before the second line is checked, so it shifts you straight back.)
local FORM_SNIPPET = [[
	local form = tonumber(newstate) or 0
	for i = 1, 12 do
		local text = (i == form) and "/cancelform" or self:GetAttribute("cast" .. i)
		self:GetFrameRef("button" .. i):SetAttribute("macrotext", text)
		self:GetFrameRef("key" .. i):SetAttribute("macrotext", text)
	end
]]

local function FormDriver()
	local parts = {}
	for i = 1, 12 do parts[i] = ("[form:%d] %d"):format(i, i) end
	parts[13] = "0"
	return table.concat(parts, "; ")
end

function TB:SetupStanceDriver(bar)
	bar:SetAttribute("_onstate-form", FORM_SNIPPET)
	RegisterStateDriver(bar, "form", FormDriver())
end

local warned = {}

-- The cast command for each button. Secure attributes, so out of combat only
-- (you can't learn a form in combat anyway). The form snippet above picks between
-- this and /cancelform.
function TB:UpdateStanceSpells()
	local bar = self.bars[self.STANCE_BAR]
	if not bar then return end
	self:RunOutOfCombat("stanceSpells", function()
		local n = TB.NumForms()
		for i, btn in ipairs(bar.buttons) do
			local cast
			if i <= n then
				local spellID = select(4, GetShapeshiftFormInfo(i))
				local spellName = spellID and C_Spell.GetSpellName(spellID)
				if spellName then
					-- Cast first, cancel second: the cancel line only matches if you were
					-- already in this form, so this toggles even without the form snippet.
					cast = ("/cast [noform:%d] %s\n/cancelform [form:%d]"):format(i, spellName, i)
				elseif not warned[i] then
					warned[i] = true
					TB:Print(("Couldn't read the spell for form %d, so its button won't work. Please report this."):format(i))
				end
			end
			bar:SetAttribute("cast" .. i, cast)
			local text = (i == GetShapeshiftForm()) and "/cancelform" or cast
			btn:SetAttribute("macrotext", text)
			btn.titanKey:SetAttribute("macrotext", text)
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
