-- TitanCraft: the crafting window.
--   Top:    profession tabs, skill bar, "Craft next skill-up" button.
--   Left:   search, sort, filters, the recipe list (colour = chance of a skill point).
--   Right:  the chosen recipe: reagents (have / need), requirements, Create / Create all.
local ADDON, TC = ...

local W, MIN_H, MAX_H = 760, 380, 1000
local TITLE_H, TOP_H, ROW_H, LIST_W = 28, 54, 20, 330
local ACCENT = { 0.2, 0.6, 1 }

local main, rowsFrame, detail, scrollBar
local rows, pool = {}, {}
local all, list = {}, {}
local selectedID
local offset = 0
local refreshQueued = false

local function Backdrop(f, r, g, b, a, br, bg, bb, ba)
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	f:SetBackdropColor(r, g, b, a)
	f:SetBackdropBorderColor(br or 0, bg or 0, bb or 0, ba or 1)
end

local function Tip(region, title, ...)
	local lines = { ... }
	region:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(type(title) == "function" and title() or title)
		for _, l in ipairs(lines) do GameTooltip:AddLine(l, 0.85, 0.85, 0.85, true) end
		GameTooltip:Show()
	end)
	region:HookScript("OnLeave", GameTooltip_Hide)
end

local function Button(parent, text, w)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, 22)
	b:SetText(text)
	return b
end

local function Hex(c) return ("|cff%02x%02x%02x"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) end

local function LinkRecipe(id, info)
	local link = (C_TradeSkillUI.GetRecipeLink and C_TradeSkillUI.GetRecipeLink(id)) or (info and info.hyperlink)
	if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
end

---------------------------------------------------------------------------
-- Data refresh (batched: many events arrive at once while crafting)
function TC:RequestRefresh()
	if refreshQueued then return end
	refreshQueued = true
	C_Timer.After(0.1, function()
		refreshQueued = false
		TC:Refresh()
	end)
end

function TC:Refresh()
	if not main or not main:IsShown() then return end
	if not (C_TradeSkillUI.IsTradeSkillReady and C_TradeSkillUI.IsTradeSkillReady()) then
		main.status:SetText("Loading recipes...")
		return
	end
	main.status:SetText("")
	local ok, res = pcall(self.Gather, self)
	all = ok and res or {}
	if not ok then self:Print("error reading recipes: " .. tostring(res)) end
	self:UpdateHeader()
	self:UpdateList()
	self:UpdateDetail()
	pcall(self.IndexReagents, self, all)
end

function TC:UpdateList()
	list = self:Filtered(all, main.search:GetText())
	-- Category view gets a header line before each category.
	if self.db.sort == "category" then
		local withHeads, last = {}, nil
		for _, r in ipairs(list) do
			if r.cat ~= last then
				table.insert(withHeads, { header = r.cat })
				last = r.cat
			end
			table.insert(withHeads, r)
		end
		list = withHeads
	end
	-- Keep the selection, or pick the first recipe.
	local found = false
	for _, r in ipairs(list) do
		if r.id and r.id == selectedID then found = true end
	end
	if not found then
		selectedID = nil
		for _, r in ipairs(list) do
			if r.id then selectedID = r.id break end
		end
	end
	self:DrawRows()
end

function TC:DrawRows()
	local visible = #rows
	offset = math.max(0, math.min(offset, #list - visible))
	for i, row in ipairs(rows) do
		local r = list[i + offset]
		row.r = r
		row:SetShown(r ~= nil)
		if r and r.header then
			row.sel:Hide()
			row.name:SetText("|cffffd200" .. r.header .. "|r")
			row.name:SetPoint("LEFT", 6, 0)
			row.count:SetText("")
			row.ups:SetText("")
		elseif r then
			local c = TC.DIFF[r.diff] or TC.DIFF[3]
			row.sel:SetShown(r.id == selectedID)
			row.name:SetPoint("LEFT", self.db.sort == "category" and 16 or 6, 0)
			row.name:SetText(Hex(c) .. r.name .. "|r")
			row.count:SetText(r.avail > 0 and ("|cffffffff[" .. r.avail .. "]|r") or "|cff5a5a64[0]|r")
			row.ups:SetText((r.diff < 3 and r.ups > 1) and ("|cffffd200+" .. r.ups .. "|r") or "")
		end
	end
	local range = math.max(0, #list - visible)
	scrollBar:SetMinMaxValues(0, range)
	scrollBar:SetShown(range > 0)
	scrollBar.updating = true
	scrollBar:SetValue(offset)
	scrollBar.updating = false
	main.countText:SetText(#all > 0 and (("%d recipes"):format(#all)) or "")
end

---------------------------------------------------------------------------
-- Header: profession, skill bar, next skill-up
function TC:UpdateHeader()
	local p = self:ProfessionInfo()
	local name = p.professionName or p.parentProfessionName or "Profession"
	local lvl, max = TC.Clean(p.skillLevel, 0), TC.Clean(p.maxSkillLevel, 0)
	local mod = TC.Clean(p.skillModifier, 0)
	main.title:SetText(name)
	main.skill:SetMinMaxValues(0, math.max(1, max))
	main.skill:SetValue(lvl)
	main.skill.text:SetText(("%d / %d%s"):format(lvl, max, mod > 0 and (" |cff4fd15f(+" .. mod .. ")|r") or ""))

	local nxt = self:NextSkillUp(all)
	main.nextRecipe = nxt
	if nxt then
		local c = TC.DIFF[nxt.diff]
		main.nextBtn:Enable()
		main.nextText:SetText("Next skill-up: " .. Hex(c) .. nxt.name .. "|r  |cff8a8a96(" .. nxt.avail .. " can make)|r")
	else
		main.nextBtn:Disable()
		local anyUp = false
		for _, r in ipairs(all) do if r.diff <= 2 then anyUp = true end end
		main.nextText:SetText(anyUp and "|cff8a8a96No skill-up recipe you have materials for.|r"
			or (max > 0 and lvl >= max and "|cff8a8a96Skill capped: train the next rank.|r" or "|cff8a8a96Nothing left that gives a point.|r"))
	end
	self:UpdateTabs()
end

-- One button per profession you know that has a crafting window.
function TC:UpdateTabs()
	local profs = { GetProfessions and GetProfessions() }
	local n = 0
	for i = 1, 6 do
		local idx = profs[i]
		if idx then
			local pname, icon, _, _, _, spellOffset, skillLine = GetProfessionInfo(idx)
			-- Only professions with a crafting window (not herbalism, skinning...).
			local craftable = true
			if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and C_TradeSkillUI.CanTradeSkillShowCraftingUI and spellOffset then
				local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
				local ok, item = pcall(C_SpellBook.GetSpellBookItemInfo, spellOffset + 1, bank)
				craftable = ok and item and item.spellID and C_TradeSkillUI.CanTradeSkillShowCraftingUI(item.spellID) or false
			end
			if skillLine and craftable then
				n = n + 1
				local t = main.tabs[n]
				if not t then
					t = CreateFrame("Button", nil, main.top)
					t:SetSize(26, 26)
					t:SetPoint("TOPLEFT", main.tabs[n - 1] or main.top, main.tabs[n - 1] and "TOPRIGHT" or "TOPLEFT", main.tabs[n - 1] and 4 or 8, main.tabs[n - 1] and 0 or -4)
					t.icon = t:CreateTexture(nil, "ARTWORK")
					t.icon:SetAllPoints()
					t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
					t.mark = t:CreateTexture(nil, "OVERLAY")
					t.mark:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -1)
					t.mark:SetPoint("TOPRIGHT", t, "BOTTOMRIGHT", 0, -1)
					t.mark:SetHeight(2)
					t.mark:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
					t:SetScript("OnClick", function(self)
						if C_TradeSkillUI.OpenTradeSkill then C_TradeSkillUI.OpenTradeSkill(self.skillLine) end
					end)
					t:SetScript("OnEnter", function(self)
						GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
						GameTooltip:SetText(self.pname)
						GameTooltip:Show()
					end)
					t:SetScript("OnLeave", GameTooltip_Hide)
					main.tabs[n] = t
				end
				t.skillLine, t.pname = skillLine, pname
				t.icon:SetTexture(icon)
				local p = self:ProfessionInfo()
				t.mark:SetShown(p.professionID == skillLine or p.parentProfessionID == skillLine)
				t:Show()
			end
		end
	end
	for i = n + 1, #main.tabs do main.tabs[i]:Hide() end
	main.title:ClearAllPoints()
	main.title:SetPoint("TOPLEFT", main.tabs[n] or main.top, main.tabs[n] and "TOPRIGHT" or "TOPLEFT", 10, main.tabs[n] and -1 or -6)
end

---------------------------------------------------------------------------
-- Detail pane
local function Selected()
	for _, r in ipairs(all) do
		if r.id == selectedID then return r end
	end
end

function TC:UpdateDetail()
	local r = Selected()
	detail:SetShown(r ~= nil)
	main.empty:SetShown(r == nil and #all > 0)
	if not r then return end
	local info = r.info
	local c = TC.DIFF[r.diff] or TC.DIFF[3]
	detail.icon:SetTexture(info.icon or 134400)
	detail.name:SetText(Hex(c) .. r.name .. "|r")
	local chance = c.word .. ": " .. c.chance
	if r.diff < 3 and r.ups > 1 then chance = chance .. " (|cffffd200+" .. r.ups .. "|r each)" end
	detail.diff:SetText(Hex(c) .. chance .. "|r")
	detail.cat:SetText("|cff8a8a96" .. r.cat .. "|r")

	-- Reagents, for the number in the Create box (so it doubles as a shopping list).
	local want = math.max(1, tonumber(detail.count:GetText()) or 1)
	detail.reagentHead:SetText(want > 1 and ("Reagents for " .. want) or "Reagents")
	local reagents = TC:Reagents(r.id)
	for i, rg in ipairs(reagents) do
		local line = detail.reagents[i]
		if not line then
			line = CreateFrame("Button", nil, detail)
			line:SetSize(330, 26)
			line:SetPoint("TOPLEFT", detail.reagentHead, "BOTTOMLEFT", 0, -4 - (i - 1) * 28)
			line.icon = line:CreateTexture(nil, "ARTWORK")
			line.icon:SetSize(24, 24)
			line.icon:SetPoint("LEFT")
			line.text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			line.text:SetPoint("LEFT", line.icon, "RIGHT", 8, 0)
			line.text:SetPoint("RIGHT", -60, 0)
			line.text:SetJustifyH("LEFT")
			line.count = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			line.count:SetPoint("RIGHT", -4, 0)
			line.short = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			line.short:SetPoint("LEFT", line, "RIGHT", 4, 0)
			line:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
			line:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
			line:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetItemByID(self.itemID)
				GameTooltip:Show()
			end)
			line:SetScript("OnLeave", GameTooltip_Hide)
			line:SetScript("OnClick", function(self)
				if IsModifiedClick("CHATLINK") then
					local _, link = C_Item.GetItemInfo(self.itemID)
					if link then ChatEdit_InsertLink(link) end
				end
			end)
			detail.reagents[i] = line
		end
		local have = TC.ItemCount(rg.itemID)
		line.itemID = rg.itemID
		line.icon:SetTexture((C_Item.GetItemIconByID and C_Item.GetItemIconByID(rg.itemID)) or 134400)
		line.text:SetText((C_Item.GetItemNameByID and C_Item.GetItemNameByID(rg.itemID)) or ("item " .. rg.itemID))
		local need = rg.need * want
		line.count:SetText((have >= need and "|cff4fd15f" or "|cffff5a4a") .. have .. "|r / " .. need)
		line.short:SetText(have < need and ("|cffff5a4aneed " .. (need - have) .. "|r") or "")
		line:Show()
	end
	for i = #reagents + 1, #detail.reagents do detail.reagents[i]:Hide() end
	local below = detail.reagents[#reagents] or detail.reagentHead

	-- Requirements (anvil, forge...) and cooldown
	local extra = {}
	if C_TradeSkillUI.GetRecipeRequirements then
		for _, req in ipairs(C_TradeSkillUI.GetRecipeRequirements(r.id) or {}) do
			table.insert(extra, (req.met and "|cff4fd15f" or "|cffff5a4a") .. "Requires " .. req.name .. "|r")
		end
	end
	if C_TradeSkillUI.GetRecipeCooldown then
		local cd = C_TradeSkillUI.GetRecipeCooldown(r.id)
		if cd and cd > 0 then
			table.insert(extra, "|cffff5a4aCooldown: " .. (SecondsToTime and SecondsToTime(cd) or (math.floor(cd / 60) .. " min")) .. "|r")
		end
	end
	if info.isEnchantingRecipe then
		table.insert(extra, "|cff8a8a96Enchant: after Create, click the item to enchant.|r")
	end
	detail.extra:ClearAllPoints()
	detail.extra:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -10)
	detail.extra:SetText(table.concat(extra, "\n"))

	detail.avail:SetText(r.avail > 0 and ("You can make |cffffffff" .. r.avail .. "|r") or "|cffff5a4aMissing materials|r")
	detail.create:SetEnabled(r.avail > 0)
	detail.createAll:SetEnabled(r.avail > 1 and info.canCreateMultiple ~= false)
	detail.createAll:SetText(r.avail > 1 and ("Create all (" .. r.avail .. ")") or "Create all")
	-- Shopping buttons: "Buy missing" only lights up at a vendor that sells something you lack.
	local missing = TC:Missing(r.id, want)
	detail.list:SetEnabled(#missing > 0)
	local plan = TC:VendorPlan(missing)
	detail.buy:SetEnabled(#plan > 0)
	detail.buy:SetText(#plan > 0 and ("Buy missing (" .. #plan .. ")") or "Buy missing")
end

function TC:Select(id)
	selectedID = id
	detail.count:SetText("1")
	self:DrawRows()
	self:UpdateDetail()
end

---------------------------------------------------------------------------
-- Layout
function TC:PlaceWindow()
	if not main then return end
	main:SetScale(self.db.scale)
	main:SetHeight(math.max(MIN_H, math.min(MAX_H, self.db.height)))
	main:ClearAllPoints()
	local p = self.db.pos
	if p then
		local s = main:GetEffectiveScale()
		main:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x / s, p.y / s)
	else
		main:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	end
	self:BuildRows()
end

local function SavePos()
	local s = main:GetEffectiveScale()
	TC.db.pos = { x = main:GetLeft() * s, y = main:GetTop() * s }
end

function TC:BuildRows()
	local want = math.max(1, math.floor((rowsFrame:GetHeight() - 4) / ROW_H))
	for i = 1, want do
		if pool[i] then
			rows[i] = pool[i]
		else
		local row = CreateFrame("Button", nil, rowsFrame)
		row:SetHeight(ROW_H)
		row:SetPoint("TOPLEFT", 2, -2 - (i - 1) * ROW_H)
		row:SetPoint("RIGHT", -12, 0)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row.sel = row:CreateTexture(nil, "BACKGROUND")
		row.sel:SetAllPoints()
		row.sel:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.25)
		local hl = row:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.07)
		row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.name:SetPoint("LEFT", 6, 0)
		row.name:SetPoint("RIGHT", -58, 0)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.count:SetPoint("RIGHT", -4, 0)
		row.ups = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.ups:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
		row:SetScript("OnClick", function(self, button)
			local r = self.r
			if not r or r.header then return end
			if IsModifiedClick("CHATLINK") then
				LinkRecipe(r.id, r.info)
			else
				TC:Select(r.id)
			end
		end)
		row:SetScript("OnDoubleClick", function(self)
			local r = self.r
			if r and r.id and r.avail > 0 then TC:Craft(r.id, 1) end
		end)
		row:SetScript("OnEnter", function(self)
			local r = self.r
			if not r or r.header then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local ok = C_TradeSkillUI.GetRecipeLink and pcall(GameTooltip.SetHyperlink, GameTooltip, C_TradeSkillUI.GetRecipeLink(r.id))
			if not ok then GameTooltip:SetText(r.name) end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", GameTooltip_Hide)
		pool[i], rows[i] = row, row
		end
	end
	for i = want + 1, #pool do
		pool[i]:Hide()
		rows[i] = nil
	end
	if main:IsShown() then self:DrawRows() end
end

---------------------------------------------------------------------------
function TC:CreateWindow()
	if main then return end
	main = CreateFrame("Frame", "TitanCraftFrame", UIParent, "BackdropTemplate")
	self.frame = main
	main:Hide()
	main:SetWidth(W)
	main:SetFrameStrata("HIGH")
	main:SetToplevel(true)
	main:SetMovable(true)
	main:SetResizable(true)
	main:SetClampedToScreen(true)
	main:EnableMouse(true)
	Backdrop(main, 0.05, 0.05, 0.07, 0.96)
	main.tabs = {}

	-- Title bar (drag to move)
	local title = CreateFrame("Frame", nil, main, "BackdropTemplate")
	title:SetPoint("TOPLEFT", 1, -1)
	title:SetPoint("TOPRIGHT", -1, -1)
	title:SetHeight(TITLE_H)
	Backdrop(title, 0.1, 0.1, 0.13, 1, 0, 0, 0, 0)
	title:EnableMouse(true)
	title:RegisterForDrag("LeftButton")
	title:SetScript("OnDragStart", function() if not TC.db.locked then main:StartMoving() end end)
	title:SetScript("OnDragStop", function() main:StopMovingOrSizing(); SavePos() end)
	local brand = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	brand:SetPoint("LEFT", 10, 0)
	brand:SetText("TitanCraft")
	local close = CreateFrame("Button", nil, title, "UIPanelCloseButton")
	close:SetSize(24, 24)
	close:SetPoint("RIGHT", -2, 0)
	close:SetScript("OnClick", function() main:Hide() end)
	local blizz = Button(title, "Blizzard window", 120)
	blizz:SetHeight(20)
	blizz:SetPoint("RIGHT", close, "LEFT", -4, 0)
	blizz:SetScript("OnClick", function() TC:UseBlizzard(selectedID) end)
	Tip(blizz, "Blizzard window", "Switch to Blizzard's profession window until you close this profession (for specializations, the profession book, enchant targets...).")
	local gear = Button(title, "Settings", 80)
	gear:SetHeight(20)
	gear:SetPoint("RIGHT", blizz, "LEFT", -4, 0)
	gear:SetScript("OnClick", function()
		if _G.TitanUI then _G.TitanUI:Open("TitanCraft") else SlashCmdList.TITANCRAFT("") end
	end)

	-- Top strip: profession tabs, skill bar, next skill-up
	local top = CreateFrame("Frame", nil, main)
	top:SetPoint("TOPLEFT", 0, -TITLE_H - 2)
	top:SetPoint("TOPRIGHT", 0, -TITLE_H - 2)
	top:SetHeight(TOP_H)
	main.top = top
	main.title = top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	main.title:SetPoint("TOPLEFT", 10, -6)
	local skill = CreateFrame("StatusBar", nil, top, "BackdropTemplate")
	skill:SetSize(220, 14)
	skill:SetPoint("TOPLEFT", 10, -34)
	skill:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	skill:SetStatusBarColor(ACCENT[1], ACCENT[2], ACCENT[3])
	Backdrop(skill, 0, 0, 0, 0.6, 0, 0, 0, 1)
	skill.text = skill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	skill.text:SetPoint("CENTER")
	main.skill = skill
	local nextBtn = Button(top, "Craft next skill-up", 170)
	nextBtn:SetPoint("TOPRIGHT", -10, -6)
	nextBtn:SetScript("OnClick", function()
		local r = main.nextRecipe
		if r then
			TC:Select(r.id)
			TC:Craft(r.id, 1)
		end
	end)
	Tip(nextBtn, "Craft next skill-up",
		"Makes one of the recipe most likely to give you a skill point that you have materials for (orange first, then yellow, then green).",
		"Click it again after each craft: it re-picks as recipes change colour.")
	main.nextBtn = nextBtn
	main.nextText = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	main.nextText:SetPoint("TOPRIGHT", nextBtn, "BOTTOMRIGHT", 0, -6)
	main.nextText:SetJustifyH("RIGHT")

	-- Left column: search, sort, filters, list
	local left = CreateFrame("Frame", nil, main, "BackdropTemplate")
	left:SetPoint("TOPLEFT", 6, -TITLE_H - TOP_H - 6)
	left:SetPoint("BOTTOMLEFT", 6, 6)
	left:SetWidth(LIST_W)
	Backdrop(left, 0.08, 0.08, 0.1, 1, 0, 0, 0, 1)

	local search = CreateFrame("EditBox", "TitanCraftSearch", left, "SearchBoxTemplate")
	search:SetSize(LIST_W - 150, 20)
	search:SetPoint("TOPLEFT", 12, -6)
	search:SetAutoFocus(false)
	search:HookScript("OnTextChanged", function() offset = 0; TC:UpdateList(); TC:UpdateDetail() end)
	main.search = search

	local sort = Button(left, "Sort", 124)
	sort:SetHeight(20)
	sort:SetPoint("TOPRIGHT", -6, -6)
	local function SortLabel()
		for _, s in ipairs(TC.SORTS) do
			if s.key == TC.db.sort then return (s.key == "skill" and "Skill-ups" or s.key == "craftable" and "Can make" or s.key == "name" and "Name" or "Category") end
		end
		return "Sort"
	end
	main.UpdateSort = function() sort:SetText("Sort: " .. SortLabel()) end
	sort:SetScript("OnClick", function(self)
		if MenuUtil and MenuUtil.CreateContextMenu then
			MenuUtil.CreateContextMenu(self, function(_, root)
				for _, s in ipairs(TC.SORTS) do
					root:CreateRadio(s.label, function() return TC.db.sort == s.key end,
						function() TC.db.sort = s.key; main.UpdateSort(); TC:UpdateList() end)
				end
			end)
		else
			local i = 1
			for n, s in ipairs(TC.SORTS) do if s.key == TC.db.sort then i = n end end
			TC.db.sort = (TC.SORTS[i + 1] or TC.SORTS[1]).key
			main.UpdateSort(); TC:UpdateList()
		end
	end)

	local function Check(label, key, x, tip)
		local c = CreateFrame("CheckButton", nil, left)
		c:SetSize(20, 20)
		c:SetPoint("TOPLEFT", x, -30)
		c:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
		c:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
		c:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
		c:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
		c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		c.text:SetPoint("LEFT", c, "RIGHT", 2, 0)
		c.text:SetText(label)
		c:SetHitRectInsets(0, -c.text:GetStringWidth() - 4, 0, 0)
		c:SetScript("OnClick", function(self)
			TC.db[key] = self:GetChecked() and true or false
			offset = 0
			TC:UpdateList(); TC:UpdateDetail()
		end)
		c.key = key
		Tip(c, label, tip)
		return c
	end
	main.checks = {
		Check("Have materials", "haveMats", 8, "Only recipes you can make right now."),
		Check("Hide grey", "hideTrivial", 130, "Hide recipes that can't give a skill point."),
	}
	main.countText = left:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	main.countText:SetPoint("TOPRIGHT", -8, -34)

	rowsFrame = CreateFrame("Frame", nil, left)
	rowsFrame:SetPoint("TOPLEFT", 2, -54)
	rowsFrame:SetPoint("BOTTOMRIGHT", -2, 4)
	rowsFrame:EnableMouseWheel(true)
	rowsFrame:SetScript("OnMouseWheel", function(_, delta)
		offset = offset - delta * 3
		TC:DrawRows()
	end)
	rowsFrame:SetScript("OnSizeChanged", function() TC:BuildRows() end)

	scrollBar = CreateFrame("Slider", nil, rowsFrame, "BackdropTemplate")
	scrollBar:SetPoint("TOPRIGHT", -1, -2)
	scrollBar:SetPoint("BOTTOMRIGHT", -1, 2)
	scrollBar:SetWidth(8)
	scrollBar:SetOrientation("VERTICAL")
	scrollBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
	scrollBar:SetBackdropColor(0, 0, 0, 0.5)
	scrollBar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
	scrollBar:GetThumbTexture():SetVertexColor(0.6, 0.6, 0.65, 0.9)
	scrollBar:GetThumbTexture():SetSize(8, 30)
	scrollBar:SetValueStep(1)
	scrollBar:SetObeyStepOnDrag(true)
	scrollBar:SetScript("OnValueChanged", function(self, v)
		if self.updating then return end
		offset = math.floor(v + 0.5)
		TC:DrawRows()
	end)

	-- Right column: the recipe
	detail = CreateFrame("Frame", nil, main)
	detail:SetPoint("TOPLEFT", left, "TOPRIGHT", 14, -6)
	detail:SetPoint("BOTTOMRIGHT", -10, 10)
	detail.reagents = {}
	local iconBtn = CreateFrame("Button", nil, detail)
	iconBtn:SetSize(44, 44)
	iconBtn:SetPoint("TOPLEFT")
	detail.icon = iconBtn:CreateTexture(nil, "ARTWORK")
	detail.icon:SetAllPoints()
	iconBtn:SetScript("OnEnter", function(self)
		local r = Selected()
		if not r then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local ok = GameTooltip.SetRecipeResultItem and pcall(GameTooltip.SetRecipeResultItem, GameTooltip, r.id)
		if not ok then
			local link = C_TradeSkillUI.GetRecipeLink and C_TradeSkillUI.GetRecipeLink(r.id)
			if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(r.name) end
		end
		GameTooltip:Show()
	end)
	iconBtn:SetScript("OnLeave", GameTooltip_Hide)
	iconBtn:SetScript("OnClick", function()
		local r = Selected()
		if r and IsModifiedClick("CHATLINK") then LinkRecipe(r.id, r.info) end
	end)
	detail.name = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	detail.name:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 10, -2)
	detail.name:SetPoint("RIGHT", 0, 0)
	detail.name:SetJustifyH("LEFT")
	detail.diff = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	detail.diff:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -4)
	detail.cat = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	detail.cat:SetPoint("TOPLEFT", detail.diff, "BOTTOMLEFT", 0, -3)
	detail.reagentHead = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	detail.reagentHead:SetPoint("TOPLEFT", iconBtn, "BOTTOMLEFT", 0, -16)
	detail.reagentHead:SetText("Reagents")
	detail.buy = Button(detail, "Buy missing", 120)
	detail.buy:SetHeight(20)
	detail.buy:SetPoint("LEFT", detail.reagentHead, "RIGHT", 12, 0)
	detail.buy:SetScript("OnClick", function()
		local r = Selected()
		if r then TC:BuyMissing(r.id, math.max(1, tonumber(detail.count:GetText()) or 1)) end
	end)
	Tip(detail.buy, "Buy missing", "At a vendor: buys the reagents this vendor sells that you're short of, for the number in the Create box.")
	detail.list = Button(detail, "List", 60)
	detail.list:SetHeight(20)
	detail.list:SetPoint("LEFT", detail.buy, "RIGHT", 4, 0)
	detail.list:SetScript("OnClick", function()
		local r = Selected()
		if r then TC:ShoppingList(r.id, math.max(1, tonumber(detail.count:GetText()) or 1), r.name) end
	end)
	Tip(detail.list, "Shopping list", "Prints what you still need (with links) to chat, for the number in the Create box.")
	detail.extra = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	detail.extra:SetJustifyH("LEFT")
	detail.extra:SetWidth(360)

	-- Create controls along the bottom
	detail.avail = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	detail.avail:SetPoint("BOTTOMLEFT", 0, 34)
	local minus = Button(detail, "-", 24)
	minus:SetPoint("BOTTOMLEFT", 0, 2)
	local count = CreateFrame("EditBox", nil, detail, "BackdropTemplate")
	count:SetSize(44, 22)
	count:SetPoint("LEFT", minus, "RIGHT", 4, 0)
	count:SetAutoFocus(false)
	count:SetNumeric(true)
	count:SetJustifyH("CENTER")
	count:SetFontObject(ChatFontNormal)
	Backdrop(count, 0, 0, 0, 0.6, 0.35, 0.35, 0.4, 1)
	count:SetText("1")
	count:SetScript("OnEnterPressed", function(self) self:ClearFocus(); detail.create:Click() end)
	count:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	detail.count = count
	local plus = Button(detail, "+", 24)
	plus:SetPoint("LEFT", count, "RIGHT", 4, 0)
	minus:SetScript("OnClick", function() count:SetText(tostring(math.max(1, (tonumber(count:GetText()) or 1) - 1))) end)
	plus:SetScript("OnClick", function()
		count:SetText(tostring(math.min(999, (tonumber(count:GetText()) or 1) + 1)))
	end)
	-- The number also drives the shopping list above, so it isn't capped at what you can make.
	count:SetScript("OnTextChanged", function(_, user) if user then TC:UpdateDetail() end end)
	minus:HookScript("OnClick", function() TC:UpdateDetail() end)
	plus:HookScript("OnClick", function() TC:UpdateDetail() end)
	detail.create = Button(detail, "Create", 90)
	detail.create:SetPoint("LEFT", plus, "RIGHT", 10, 0)
	detail.create:SetScript("OnClick", function()
		local r = Selected()
		if r then TC:Craft(r.id, tonumber(count:GetText()) or 1) end
	end)
	detail.createAll = Button(detail, "Create all", 130)
	detail.createAll:SetPoint("LEFT", detail.create, "RIGHT", 6, 0)
	detail.createAll:SetScript("OnClick", function()
		local r = Selected()
		if r and r.avail > 0 then TC:Craft(r.id, r.avail) end
	end)
	detail:Hide()

	main.empty = main:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	main.empty:SetPoint("CENTER", detail, "CENTER")
	main.empty:SetText("No recipe matches your search or filters.")
	main.status = main:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	main.status:SetPoint("CENTER", rowsFrame, "CENTER")

	-- Height grip (bottom-right corner)
	local grip = CreateFrame("Button", nil, main)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -1, 1)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	if main.SetResizeBounds then main:SetResizeBounds(W, MIN_H, W, MAX_H) end
	grip:SetScript("OnMouseDown", function() if not TC.db.locked then main:StartSizing("BOTTOM") end end)
	grip:SetScript("OnMouseUp", function()
		main:StopMovingOrSizing()
		TC.db.height = math.floor(main:GetHeight() + 0.5)
		SavePos()
		TC:PlaceWindow()
	end)

	main:SetScript("OnShow", function()
		TC:PlaceWindow()
		main.UpdateSort()
		for _, c in ipairs(main.checks) do c:SetChecked(TC.db[c.key]) end
		TC:Refresh()
	end)
	main:SetScript("OnHide", function()
		search:SetText("")
		if not TC.syncing then TC:CloseProfession() end
	end)

	local function OnEvent(_, event, unit)
		if not main:IsShown() then return end
		if event == "UNIT_SPELLCAST_SUCCEEDED" and unit ~= "player" then return end
		TC:RequestRefresh()
	end
	for _, e in ipairs({ "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "BAG_UPDATE_DELAYED",
		"NEW_RECIPE_LEARNED", "SKILL_LINES_CHANGED", "UNIT_SPELLCAST_SUCCEEDED", "TRADE_SKILL_ITEM_CRAFTED_RESULT",
		"MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE" }) do
		pcall(main.RegisterEvent, main, e)
	end
	main:SetScript("OnEvent", OnEvent)
	self:PlaceWindow()
end
