-- TitanQuests: the tracker window. A title bar (drag to move, one button to minimize)
-- over a list of quests grouped by zone. Click a quest to fold its objectives away,
-- click a zone to fold the whole zone, right-click a quest for its options.
local ADDON, TQ = ...

local HEADER_H = 22
TQ.HEADER_H = HEADER_H
local PAD = 6
local ZONE_INDENT, QUEST_INDENT, OBJ_INDENT = 4, 6, 18

local root, header, body, minBtn, footer
local titleFont, lineFont, zoneFont

---------------------------------------------------------------------------
-- Fonts. Own font objects so the size slider changes every line at once.
---------------------------------------------------------------------------
local function MakeFont(name, from)
	local f = CreateFont(name)
	f:CopyFontObject(from)
	f:SetShadowOffset(1, -1)
	f:SetShadowColor(0, 0, 0, 1)
	return f
end

function TQ:UpdateFonts()
	local size = self.db.fontSize
	local path = GameFontNormal:GetFont()
	titleFont:SetFont(path, size, "")
	lineFont:SetFont(path, size - 1, "")
	zoneFont:SetFont(path, size - 2, "")
end

---------------------------------------------------------------------------
-- Quest data
---------------------------------------------------------------------------
local function DifficultyColor(level)
	if GetQuestDifficultyColor then
		local c = GetQuestDifficultyColor(level)
		if c then return c.r, c.g, c.b end
	end
	return 1, 0.82, 0
end

-- "Kobold Vermin slain: 3/8" or "3/8 Kobold Vermin slain" -> name, "3/8"
local function SplitObjective(text)
	local name, count = text:match("^(.-):%s*(%d+%s*/%s*%d+)$")
	if name then return name, count end
	count, name = text:match("^(%d+%s*/%s*%d+)%s+(.+)$")
	if name then return name, count end
	return text
end

local function QuestData(info)
	local id = info.questID
	return {
		id = id,
		logIndex = info.questLogIndex,
		title = info.title,
		level = info.level,
		difficulty = info.difficultyLevel ~= 0 and info.difficultyLevel or info.level,
		complete = C_QuestLog.IsComplete(id),
		failed = C_QuestLog.IsFailed and C_QuestLog.IsFailed(id),
		objectives = C_QuestLog.GetQuestObjectives(id) or {},
	}
end

-- Zones in quest-log order, each with the quests to show under it.
function TQ:Gather()
	local watched, showAll = {}, self.db.showAll
	for i = 1, C_QuestLog.GetNumQuestWatches() do
		local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
		if id then watched[id] = true end
	end

	local zones, byName, seen = {}, {}, {}
	local zone = OTHER or "Other"
	local function Add(zoneName, q)
		local z = byName[zoneName]
		if not z then
			z = { name = zoneName, quests = {} }
			byName[zoneName] = z
			table.insert(zones, z)
		end
		table.insert(z.quests, q)
		seen[q.id] = true
	end

	local numEntries, numQuests = C_QuestLog.GetNumQuestLogEntries()
	for i = 1, numEntries do
		local info = C_QuestLog.GetInfo(i)
		if info then
			if info.isHeader then
				zone = info.title
			elseif not info.isHidden and (showAll or watched[info.questID]) then
				Add(zone, QuestData(info))
			end
		end
	end
	-- Tracked quests whose zone is folded up in Blizzard's quest log don't come
	-- back from the loop above, so pick them up here.
	for id in pairs(watched) do
		if not seen[id] then
			local index = C_QuestLog.GetLogIndexForQuestID(id)
			local info = index and C_QuestLog.GetInfo(index)
			if info and not info.isHeader then Add(OTHER or "Other", QuestData(info)) end
		end
	end

	local max = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or MAX_QUESTS or 25
	return zones, numQuests or 0, max
end

---------------------------------------------------------------------------
-- Rows. One pooled button type for zone headers, quest titles and objectives.
---------------------------------------------------------------------------
local rows, used = {}, 0

local function RowClick(row, button)
	TQ:OnRowClick(row, button)
end

local function RowEnter(row)
	if row.kind ~= "quest" then return end
	GameTooltip:SetOwner(row, "ANCHOR_LEFT")
	GameTooltip:AddLine(row.questTitle)
	GameTooltip:AddLine("Click: fold objectives", 1, 1, 1)
	GameTooltip:AddLine("Shift-click: stop tracking", 1, 1, 1)
	GameTooltip:AddLine("Right-click: options", 1, 1, 1)
	GameTooltip:Show()
end

local function AcquireRow()
	used = used + 1
	local r = rows[used]
	if not r then
		r = CreateFrame("Button", nil, body)
		r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		r.toggle = r:CreateTexture(nil, "ARTWORK")
		r.toggle:SetSize(10, 10)
		r.check = r:CreateTexture(nil, "ARTWORK")
		r.check:SetSize(12, 12)
		r.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
		-- A font string needs a font before any SetText, even an empty one.
		r.text = r:CreateFontString(nil, "OVERLAY", "TitanQuestsLineFont")
		r.text:SetJustifyH("LEFT")
		r.text:SetJustifyV("TOP")
		r.text:SetWordWrap(true)
		r.right = r:CreateFontString(nil, "OVERLAY", "TitanQuestsLineFont")
		r.right:SetJustifyH("RIGHT")
		local hl = r:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.06)
		r:SetScript("OnClick", RowClick)
		r:SetScript("OnEnter", RowEnter)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)
		rows[used] = r
	end
	r.kind, r.questID, r.zone, r.logIndex, r.questTitle = nil
	r.toggle:Hide()
	r.check:Hide()
	r.right:SetText("")
	r:Show()
	return r
end

-- Lays out one row at y (from the top of the body) and returns its height.
local function SetRow(r, y, indent, font, text, rightText, red, green, blue)
	local width = TQ.db.width - PAD * 2
	r.text:SetFontObject(font)
	r.right:SetFontObject(font)
	r.text:SetTextColor(red, green, blue)
	r.right:SetTextColor(red, green, blue)
	r.right:SetText(rightText or "")
	local rightW = rightText and (r.right:GetStringWidth() + 6) or 0
	r.text:SetWidth(width - indent - rightW)
	r.text:SetText(text)
	r.text:ClearAllPoints()
	r.text:SetPoint("TOPLEFT", r, "TOPLEFT", indent, -1)
	r.right:ClearAllPoints()
	r.right:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, -1)
	local h = math.ceil(r.text:GetStringHeight()) + 3
	r:ClearAllPoints()
	r:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, -y)
	r:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, -y)
	r:SetHeight(h)
	return h
end

local function SetToggle(r, indent, folded)
	r.toggle:SetTexture(folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
	r.toggle:ClearAllPoints()
	r.toggle:SetPoint("TOPLEFT", r, "TOPLEFT", indent - 12, -2)
	r.toggle:Show()
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
TQ.offset = 0 -- quests scrolled off the top
TQ.itemSlots = {} -- { questID, logIndex, y } for Items.lua, rebuilt each layout

function TQ:Refresh()
	if not root then return end
	local db = self.db
	local zones, numQuests, maxQuests = self:Gather()

	local ready = 0
	for _, z in ipairs(zones) do
		for _, q in ipairs(z.quests) do
			if q.complete then ready = ready + 1 end
		end
	end
	header.count:SetText(("%d/%d"):format(numQuests, maxQuests))
	header.ready:SetText(ready > 0 and ("%d ready"):format(ready) or "")

	used = 0
	wipe(self.itemSlots)
	local y, skipped, hidden, total = 4, 0, 0, 0
	local limit = db.maxHeight
	local full = false

	for _, z in ipairs(zones) do
		total = total + #z.quests
		local zoneFolded = db.zones and db.zoneCollapsed[z.name]
		-- Scrolling counts quests; a zone header shows once its first quest is on
		-- screen (a folded zone shows as soon as scrolling reaches it).
		local onScreen = skipped + (zoneFolded and 0 or #z.quests) >= self.offset + (zoneFolded and 0 or 1)
		if full or y > limit then
			full = true
		elseif db.zones and onScreen then
			local r = AcquireRow()
			r.kind, r.zone = "zone", z.name
			local label = zoneFolded and ("%s  (%d)"):format(z.name, #z.quests) or z.name
			y = y + SetRow(r, y, ZONE_INDENT + 12, zoneFont, label:upper(), nil, 0.6, 0.6, 0.6) + 1
			SetToggle(r, ZONE_INDENT + 12, zoneFolded)
		end
		if not zoneFolded then
			for _, q in ipairs(z.quests) do
				if skipped < self.offset then
					skipped = skipped + 1
				elseif full or y > limit then
					full = true
					hidden = hidden + 1
				else
					y = y + self:LayoutQuest(q, y)
				end
			end
		end
	end
	if self.offset > 0 and total > 0 and used == 0 then
		-- Scrolled past the end (quests were turned in); start again from the top.
		self.offset = 0
		return self:Refresh()
	end

	if hidden > 0 or self.offset > 0 then
		footer:SetText(("%s%d more - mouse wheel to scroll"):format(self.offset > 0 and ("%d above, "):format(self.offset) or "", hidden))
		footer:ClearAllPoints()
		footer:SetPoint("TOPLEFT", body, "TOPLEFT", PAD + QUEST_INDENT, -y - 2)
		footer:Show()
		y = y + 16
	else
		footer:Hide()
	end
	if total == 0 then
		footer:SetText(db.showAll and "Your quest log is empty." or "No tracked quests. Shift-click a quest in your log to track it, or tick \"Every quest in the log\" in /tquests.")
		footer:SetWidth(db.width - PAD * 2 - QUEST_INDENT)
		footer:ClearAllPoints()
		footer:SetPoint("TOPLEFT", body, "TOPLEFT", PAD + QUEST_INDENT, -6)
		footer:Show()
		y = y + footer:GetStringHeight() + 6
	else
		footer:SetWidth(0)
	end

	for i = used + 1, #rows do rows[i]:Hide() end
	body:SetHeight(y + 4)
	self:LayoutItems()
end

function TQ:LayoutQuest(q, y)
	local db = self.db
	local start = y
	local folded = db.collapsed[q.id]

	local r = AcquireRow()
	r.kind, r.questID, r.logIndex, r.questTitle = "quest", q.id, q.logIndex, q.title
	local text = q.title
	if db.levels then
		local lr, lg, lb = DifficultyColor(q.difficulty)
		-- %x and %d need whole numbers; colours come back as fractions.
		local function Hex(v) return math.floor(v * 255 + 0.5) end
		text = ("|cff%02x%02x%02x[%d]|r %s"):format(Hex(lr), Hex(lg), Hex(lb), q.level or 0, q.title)
	end
	local red, green, blue = 1, 0.82, 0
	local right
	if q.failed then
		red, green, blue, right = 1, 0.25, 0.25, "Failed"
	elseif q.complete then
		red, green, blue = 0.3, 1, 0.3
	end
	y = y + SetRow(r, y, QUEST_INDENT + 12, titleFont, text, right, red, green, blue)
	local hasObjectives = #q.objectives > 0 or q.complete
	if hasObjectives then SetToggle(r, QUEST_INDENT + 12, folded) end
	table.insert(self.itemSlots, { questID = q.id, logIndex = q.logIndex, complete = q.complete, y = start })

	if not folded then
		if q.complete then
			local o = AcquireRow()
			o.kind = "objective"
			y = y + SetRow(o, y, OBJ_INDENT + 14, lineFont, "Ready to turn in", nil, 0.3, 1, 0.3)
			o.check:SetPoint("TOPLEFT", o, "TOPLEFT", OBJ_INDENT, -1)
			o.check:Show()
		else
			for _, obj in ipairs(q.objectives) do
				if not (obj.finished and db.hideDone) and obj.text and obj.text ~= "" then
					local o = AcquireRow()
					o.kind, o.questID = "objective", q.id
					local name, count = SplitObjective(obj.text)
					if obj.finished then
						y = y + SetRow(o, y, OBJ_INDENT + 14, lineFont, name, count, 0.5, 0.5, 0.5)
						o.check:SetPoint("TOPLEFT", o, "TOPLEFT", OBJ_INDENT, -1)
						o.check:Show()
					else
						y = y + SetRow(o, y, OBJ_INDENT + 14, lineFont, "- " .. name, count, 0.85, 0.85, 0.85)
					end
				end
			end
		end
	end
	return y - start + 4
end

---------------------------------------------------------------------------
-- Clicks and the right-click menu
---------------------------------------------------------------------------
local function OpenDetails(questID)
	if QuestMapFrame_OpenToQuestDetails then
		QuestMapFrame_OpenToQuestDetails(questID)
	elseif ToggleQuestLog then
		ToggleQuestLog()
	end
end

local function InsertLink(questID)
	if ChatFrameUtil and ChatFrameUtil.TryInsertQuestLinkForQuestID then
		return ChatFrameUtil.TryInsertQuestLinkForQuestID(questID)
	end
	local link = GetQuestLink and GetQuestLink(questID)
	return link and ChatEdit_InsertLink and ChatEdit_InsertLink(link)
end

local function ToggleWatch(questID)
	if C_QuestLog.GetQuestWatchType(questID) then
		C_QuestLog.RemoveQuestWatch(questID)
	else
		C_QuestLog.AddQuestWatch(questID)
	end
end

function TQ:SetAllFolded(folded)
	local zones = self:Gather()
	for _, z in ipairs(zones) do
		for _, q in ipairs(z.quests) do self.db.collapsed[q.id] = folded or nil end
	end
	self:Refresh()
end

function TQ:OnRowClick(row, button)
	local db = self.db
	if row.kind == "zone" then
		db.zoneCollapsed[row.zone] = not db.zoneCollapsed[row.zone] or nil
		self:Refresh()
		return
	end
	if row.kind ~= "quest" then return end
	local id = row.questID
	if button == "LeftButton" then
		if IsModifiedClick("CHATLINK") and InsertLink(id) then return end
		if IsModifiedClick("QUESTWATCHTOGGLE") then
			ToggleWatch(id)
		else
			db.collapsed[id] = not db.collapsed[id] or nil
			self:Refresh()
		end
		return
	end
	if not MenuUtil then
		OpenDetails(id)
		return
	end
	MenuUtil.CreateContextMenu(row, function(_, menu)
		menu:CreateTitle(row.questTitle)
		menu:CreateButton("Open in quest log", function() OpenDetails(id) end)
		menu:CreateButton(C_QuestLog.GetQuestWatchType(id) and "Stop tracking" or "Track", function() ToggleWatch(id) end)
		if C_QuestLog.IsPushableQuest(id) and IsInGroup() then
			menu:CreateButton("Share with party", function()
				if QuestUtil and QuestUtil.ShareQuest then
					QuestUtil.ShareQuest(id)
				else
					C_QuestLog.SetSelectedQuest(id)
					QuestLogPushQuest()
				end
			end)
		end
		menu:CreateDivider()
		menu:CreateButton("Fold all quests", function() TQ:SetAllFolded(true) end)
		menu:CreateButton("Unfold all quests", function() TQ:SetAllFolded(false) end)
		if QuestMapQuestOptions_AbandonQuest then
			menu:CreateDivider()
			menu:CreateButton("|cffff5555Abandon quest|r", function() QuestMapQuestOptions_AbandonQuest(id) end)
		end
	end)
end

---------------------------------------------------------------------------
-- Minimize. The button is secure so it can also hide the quest item buttons
-- (which are protected) in combat; the rest of the tracker follows in Lua.
---------------------------------------------------------------------------
function TQ:IsMinimizedNow()
	return self.db.minimized or (self.db.combatMinimize and self.inCombat)
end

function TQ:ApplyMinimized()
	local min = self:IsMinimizedNow()
	body:SetShown(not min)
	minBtn.icon:SetTexture(min and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
	header.ready:SetShown(min)
end

function TQ:SetMinimized(min)
	self.db.minimized = min and true or false
	self:ApplyMinimized()
	self:SyncItemHolder()
	self:RefreshConfig()
end

function TQ:UpdateCombat(inCombat)
	self.inCombat = inCombat
	self:ApplyMinimized()
end

---------------------------------------------------------------------------
-- Position, size and the title bar
---------------------------------------------------------------------------
function TQ:ApplyLayout()
	local db = self.db
	header.bg:SetColorTexture(0, 0, 0, math.min(1, db.alpha + 0.2))
	body.bg:SetColorTexture(0, 0, 0, db.alpha)
	self:UpdateFonts()
	-- The title bar holds secure children (minimize, quest items), so it only
	-- moves or resizes out of combat.
	self:RunOutOfCombat("layout", function()
		root:SetScale(db.scale)
		root:SetWidth(db.width)
		root:ClearAllPoints()
		if db.pos then
			root:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.pos.x / db.scale, db.pos.y / db.scale)
		else
			root:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -230)
		end
	end)
	self:Refresh()
end

local function SavePosition()
	local s = root:GetScale()
	TQ.db.pos = { x = root:GetLeft() * s, y = root:GetTop() * s }
	TQ:ApplyLayout()
end

function TQ:SetupTracker()
	titleFont = MakeFont("TitanQuestsTitleFont", GameFontNormal)
	lineFont = MakeFont("TitanQuestsLineFont", GameFontHighlight)
	zoneFont = MakeFont("TitanQuestsZoneFont", GameFontNormalSmall)

	root = CreateFrame("Frame", "TitanQuestsFrame", UIParent)
	root:SetHeight(HEADER_H)
	root:SetFrameStrata("LOW")
	root:SetMovable(true)
	root:SetClampedToScreen(true)
	self.root = root

	header = CreateFrame("Frame", nil, root)
	header:SetAllPoints()
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function()
		if not TQ.db.locked and not InCombatLockdown() then root:StartMoving() end
	end)
	header:SetScript("OnDragStop", function()
		root:StopMovingOrSizing()
		root:SetUserPlaced(false)
		SavePosition()
	end)
	header.bg = header:CreateTexture(nil, "BACKGROUND")
	header.bg:SetAllPoints()
	local line = header:CreateTexture(nil, "BORDER")
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	line:SetHeight(1)
	line:SetColorTexture(1, 0.82, 0, 0.5)
	header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header.title:SetPoint("LEFT", 8, 0)
	header.title:SetText("Quests")
	header.count = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	header.count:SetPoint("LEFT", header.title, "RIGHT", 6, 0)
	header.ready = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	header.ready:SetPoint("LEFT", header.count, "RIGHT", 8, 0)
	header.ready:SetTextColor(0.3, 1, 0.3)

	minBtn = CreateFrame("Button", "TitanQuestsMinimize", root, "SecureHandlerClickTemplate")
	minBtn:SetFrameLevel(header:GetFrameLevel() + 2)
	minBtn:SetSize(16, 16)
	minBtn:SetPoint("RIGHT", root, "RIGHT", -4, 0)
	minBtn:RegisterForClicks("AnyUp")
	minBtn.icon = minBtn:CreateTexture(nil, "ARTWORK")
	minBtn.icon:SetAllPoints()
	minBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
	minBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_LEFT")
		GameTooltip:AddLine("Minimize / restore")
		GameTooltip:AddLine("Set a key in Options > Keybindings > AddOns", 1, 1, 1)
		GameTooltip:Show()
	end)
	minBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.minBtn = minBtn

	local gear = CreateFrame("Button", nil, header)
	gear:SetSize(14, 14)
	gear:SetPoint("RIGHT", minBtn, "LEFT", -6, 0)
	gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
	gear:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton", "ADD")
	gear:SetScript("OnClick", function() TQ:ToggleConfig() end)
	gear:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_LEFT")
		GameTooltip:AddLine("TitanQuests settings")
		GameTooltip:Show()
	end)
	gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

	body = CreateFrame("Frame", nil, root)
	body:SetPoint("TOPLEFT", root, "BOTTOMLEFT")
	body:SetPoint("TOPRIGHT", root, "BOTTOMRIGHT")
	body:SetHeight(1)
	body.bg = body:CreateTexture(nil, "BACKGROUND")
	body.bg:SetAllPoints()
	body:EnableMouseWheel(true)
	body:SetScript("OnMouseWheel", function(_, delta)
		-- Quest item buttons are protected and can't follow a scroll in combat.
		if InCombatLockdown() and TQ:HasItemButtons() then return end
		TQ.offset = math.max(0, TQ.offset - delta)
		TQ:Refresh()
	end)
	footer = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	footer:SetJustifyH("LEFT")

	-- Width grip in the bottom-right corner.
	local grip = CreateFrame("Button", nil, body)
	grip:SetSize(12, 12)
	grip:SetPoint("BOTTOMRIGHT", -1, 1)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetScript("OnMouseDown", function(g)
		if InCombatLockdown() or TQ.db.locked then return end
		g:SetScript("OnUpdate", function()
			local x = GetCursorPosition() / root:GetEffectiveScale()
			local w = math.floor(math.max(180, math.min(500, x - root:GetLeft())))
			if w ~= TQ.db.width then
				TQ.db.width = w
				root:SetWidth(w)
				TQ:Refresh()
			end
		end)
	end)
	grip:SetScript("OnMouseUp", function(g)
		g:SetScript("OnUpdate", nil)
		TQ:RefreshConfig()
	end)
	self.grip = grip

	self:ApplyLayout()
	self:ApplyMinimized()
end
