-- TitanQuests: quest item buttons (the bomb / sample jar / totem some quests give you),
-- shown to the left of the quest's title. They are secure buttons, so they can only be
-- added, moved or removed out of combat; during a fight they stay where they were.
local ADDON, TQ = ...

local holder
local buttons = {}

local function ItemEnter(b)
	if not b.link then return end
	GameTooltip:SetOwner(b, "ANCHOR_LEFT")
	GameTooltip:SetHyperlink(b.link)
	GameTooltip:Show()
end

local function CreateItemButton(i)
	local b = CreateFrame("Button", "TitanQuestsItem" .. i, holder, "SecureActionButtonTemplate")
	b:SetSize(20, 20)
	b:RegisterForClicks("AnyUp")
	-- Mouse clicks only send a release, so don't wait for a key-down that never comes.
	b:SetAttribute("useOnKeyDown", false)
	b:SetAttribute("type", "item")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local border = b:CreateTexture(nil, "BACKGROUND")
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetColorTexture(0, 0, 0, 1)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cooldown:SetAllPoints()
	b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	b.count:SetPoint("BOTTOMRIGHT", 2, -1)
	b:SetScript("OnEnter", ItemEnter)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	buttons[i] = b
	return b
end

function TQ:HasItemButtons()
	for _, b in ipairs(buttons) do
		if b:IsShown() then return true end
	end
	return false
end

function TQ:LayoutItems()
	if not holder then return end
	self:RunOutOfCombat("items", function()
		local n = 0
		if self.db.items then
			for _, slot in ipairs(self.itemSlots) do
				local link, texture, charges, showWhenComplete = GetQuestLogSpecialItemInfo(slot.logIndex)
				local itemID = link and link:match("item:(%d+)")
				if itemID and (not slot.complete or showWhenComplete) then
					n = n + 1
					local b = buttons[n] or CreateItemButton(n)
					b:SetAttribute("item", "item:" .. itemID)
					b.link, b.logIndex = link, slot.logIndex
					b.icon:SetTexture(texture)
					b.count:SetText(charges and charges > 1 and charges or "")
					b:ClearAllPoints()
					b:SetPoint("TOPRIGHT", holder, "TOPLEFT", -4, -(TQ.HEADER_H + slot.y))
					b:Show()
				end
			end
		end
		for i = n + 1, #buttons do
			buttons[i]:Hide()
			buttons[i].link = nil
		end
		self:UpdateItemCooldowns()
	end)
end

function TQ:UpdateItemCooldowns()
	for _, b in ipairs(buttons) do
		if b:IsShown() and b.logIndex then
			local start, duration, enable = GetQuestLogSpecialItemCooldown(b.logIndex)
			if start then CooldownFrame_Set(b.cooldown, start, duration, enable) end
		end
	end
end

-- Keeps the secure side's idea of "minimized" in step with ours.
function TQ:SyncItemHolder()
	if not holder then return end
	self:RunOutOfCombat("holder", function()
		holder:SetAttribute("min", self.db.minimized)
		holder:SetAttribute("combatmin", self.db.combatMinimize)
		holder:SetShown(not self.db.minimized)
	end)
end

function TQ:SetupItems()
	holder = CreateFrame("Frame", "TitanQuestsItems", self.root, "SecureHandlerStateTemplate")
	holder:SetPoint("TOPLEFT", self.root, "TOPLEFT")
	holder:SetSize(1, 1)

	-- Combat minimize for the item buttons. The rest of the tracker hides in Lua.
	holder:SetAttribute("_onstate-tqcombat", [[
		self:SetAttribute("incombat", newstate == "combat")
		if self:GetAttribute("min") or (self:GetAttribute("combatmin") and newstate == "combat") then
			self:Hide()
		else
			self:Show()
		end
	]])
	RegisterStateDriver(holder, "tqcombat", "[combat] combat; normal")

	-- The minimize button (and its key binding) flips the secure state first, then
	-- the hook below updates everything else.
	local btn = self.minBtn
	btn:SetFrameRef("items", holder)
	btn:SetAttribute("_onclick", [[
		local h = self:GetFrameRef("items")
		local m = not h:GetAttribute("min")
		h:SetAttribute("min", m)
		if m or (h:GetAttribute("combatmin") and h:GetAttribute("incombat")) then
			h:Hide()
		else
			h:Show()
		end
	]])
	btn:HookScript("OnClick", function()
		TQ:SetMinimized(holder:GetAttribute("min"))
	end)

	self:SyncItemHolder()
end
