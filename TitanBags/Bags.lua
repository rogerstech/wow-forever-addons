-- TitanBags: the one-window bag view.
--
-- Item buttons use Blizzard's own bag-slot button (ContainerFrameItemButtonTemplate), so
-- clicking, right-click to use, drag, split stacks, sell, tooltips and using items in
-- combat behave exactly like Blizzard's bags. Each button sits in a small holder frame
-- whose ID is the bag number; Blizzard's button reads its bag from there, so we never
-- write bag numbers into the button ourselves (that would taint using items).
local ADDON, TB = ...

local SIZE, GAP, PAD = 37, 4, 8
local HEADER_H, FOOTER_H, SECTION_H = 26, 22, 16
local SORT_UP, SORT_DOWN = "bags-button-autosort-up", "bags-button-autosort-down"

local main
local holders, buttons = {}, {}   -- holders[bag], buttons[bag][slot]

local function IsSecret(v)
	return issecretvalue and issecretvalue(v) or false
end

local function Clean(v, default)
	if v == nil or IsSecret(v) then return default end
	return v
end

---------------------------------------------------------------------------
-- Buttons
local function Holder(bag)
	local h = holders[bag]
	if not h then
		h = CreateFrame("Frame", nil, main)
		h:SetID(bag)
		h:SetSize(1, 1)
		h:SetPoint("TOPLEFT")
		holders[bag] = h
		buttons[bag] = {}
	end
	return h
end

local slotCount = 0
local function GetButton(bag, slot)
	local list = buttons[bag]
	local b = list and list[slot]
	if b then return b end
	local holder = Holder(bag)
	slotCount = slotCount + 1
	b = CreateFrame("ItemButton", "TitanBagsSlot" .. slotCount, holder, "ContainerFrameItemButtonTemplate")
	b:SetID(slot)
	b:SetFrameLevel(main:GetFrameLevel() + 3)
	buttons[bag][slot] = b
	return b
end

local function UpdateButton(b, tooltipOwner)
	local bag, slot = b:GetParent():GetID(), b:GetID()
	local info = C_Container.GetContainerItemInfo(bag, slot)
	local texture = info and info.iconFileID
	local quality = info and info.quality
	local link = info and info.hyperlink
	local q = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)

	if ClearItemButtonOverlay then ClearItemButtonOverlay(b) end
	b:SetHasItem(texture)
	b:SetItemButtonTexture(texture)
	b:SyncAppearanceWithHasItem()
	SetItemButtonQuality(b, quality, link, false, info and info.isBound)
	SetItemButtonCount(b, info and info.stackCount)
	SetItemButtonDesaturated(b, info and info.isLocked)
	b:UpdateExtended()
	if b.UpdateQuestItem then
		b:UpdateQuestItem(q and q.isQuestItem, q and q.questID, q and q.isActive)
	end
	if b.UpdateNewItem then b:UpdateNewItem(quality) end
	if b.UpdateJunkItem then b:UpdateJunkItem(quality, info and info.hasNoValue) end
	if b.UpdateItemContextMatching then b:UpdateItemContextMatching() end
	b:UpdateCooldown(texture)
	if b.SetReadable then b:SetReadable(info and info.isReadable) end
	if b.SetMatchesSearch then b:SetMatchesSearch(not (info and info.isFiltered)) end
	b:CheckUpdateTooltip(tooltipOwner)
end

local function ForEachShown(fn)
	for _, list in pairs(buttons) do
		for _, b in pairs(list) do
			if b:IsShown() then fn(b) end
		end
	end
end

function TB:UpdateAll()
	if not main or not main:IsShown() then return end
	local owner = GameTooltip:GetOwner()
	ForEachShown(function(b) UpdateButton(b, owner) end)
	self:UpdateFooter()
end

---------------------------------------------------------------------------
-- Sorted views. These only change where items are DRAWN; nothing moves in your bags.
local TYPE_RANK = {
	[0] = 1,   -- consumable
	[12] = 2,  -- quest
	[2] = 3,   -- weapon
	[4] = 4,   -- armor
	[1] = 5,   -- container
	[11] = 6,  -- quiver
	[6] = 7,   -- projectile
	[9] = 8,   -- recipe
	[7] = 9,   -- trade goods
	[5] = 10,  -- reagent
	[3] = 11,  -- gem
	[13] = 12, -- key
	[15] = 13, -- miscellaneous
}

local function ItemKey(bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	local e = { bag = bag, slot = slot }
	if not info or not Clean(info.iconFileID) then return e end
	e.has = true
	e.quality = Clean(info.quality, 1)
	e.count = Clean(info.stackCount, 1)
	local link = Clean(info.hyperlink)
	e.name = Clean(info.itemName) or (link and link:match("%[(.-)%]")) or ""
	local id = Clean(info.itemID)
	e.id = id or 0
	if id and C_Item and C_Item.GetItemInfoInstant then
		local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
		e.class, e.sub = classID, subID
	end
	e.typeRank = TYPE_RANK[e.class or 15] or 14
	if link and C_Item and C_Item.GetDetailedItemLevelInfo then
		e.ilvl = Clean(C_Item.GetDetailedItemLevelInfo(link), 0)
	end
	e.ilvl = e.ilvl or 0
	e.junk = (e.quality == 0)
	return e
end

local function Tail(a, b)
	if a.name ~= b.name then return a.name < b.name end
	if a.count ~= b.count then return a.count > b.count end
	if a.bag ~= b.bag then return a.bag < b.bag end
	return a.slot < b.slot
end

local COMPARE = {
	quality = function(a, b)
		if a.quality ~= b.quality then return a.quality > b.quality end
		if a.typeRank ~= b.typeRank then return a.typeRank < b.typeRank end
		return Tail(a, b)
	end,
	type = function(a, b)
		if a.junk ~= b.junk then return b.junk end
		if a.typeRank ~= b.typeRank then return a.typeRank < b.typeRank end
		if (a.sub or 0) ~= (b.sub or 0) then return (a.sub or 0) < (b.sub or 0) end
		if a.quality ~= b.quality then return a.quality > b.quality end
		return Tail(a, b)
	end,
	name = function(a, b)
		return Tail(a, b)
	end,
	ilvl = function(a, b)
		if a.junk ~= b.junk then return b.junk end
		if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
		if a.quality ~= b.quality then return a.quality > b.quality end
		return Tail(a, b)
	end,
}

local function SlotList(bagFrom, bagTo, view)
	local items, empty = {}, {}
	for bag = bagFrom, bagTo do
		local n = C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, n do
			if view == "bag" then
				table.insert(items, { bag = bag, slot = slot })
			else
				local e = ItemKey(bag, slot)
				table.insert(e.has and items or empty, e)
			end
		end
	end
	if view ~= "bag" then
		table.sort(items, COMPARE[view] or COMPARE.quality)
		for _, e in ipairs(empty) do table.insert(items, e) end
	end
	return items
end

---------------------------------------------------------------------------
-- Layout
local function Place(b, index, cols, top)
	local col = (index - 1) % cols
	local row = math.floor((index - 1) / cols)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", main, "TOPLEFT", PAD + col * (SIZE + GAP), -(top + row * (SIZE + GAP)))
	b:Show()
	return row + 1
end

function TB:Layout()
	if not main then return end
	if InCombatLockdown() and main:IsProtected() then
		self.pendingLayout = true
		return
	end
	self.pendingLayout = false
	self.layoutWanted = false
	self.laidOut = true
	local db = self.db
	local cols = db.columns

	local used = {}
	local list = SlotList(0, self:LastBagID(), db.view)
	local top = HEADER_H + 4
	local rows = 0
	for i, e in ipairs(list) do
		local b = GetButton(e.bag, e.slot)
		used[b] = true
		rows = Place(b, i, cols, top)
	end
	local height = top + rows * (SIZE + GAP)

	-- Keyring, in its own section under the bags.
	local key = db.showKeys and self:KeyringID()
	local keySlots = key and (C_Container.GetContainerNumSlots(key) or 0) or 0
	if keySlots > 0 then
		main.keyLabel:ClearAllPoints()
		main.keyLabel:SetPoint("TOPLEFT", PAD + 2, -(height + 2))
		main.keyLabel:Show()
		local ktop = height + SECTION_H
		local krows = 0
		for slot = 1, keySlots do
			local b = GetButton(key, slot)
			used[b] = true
			krows = Place(b, slot, cols, ktop)
		end
		height = ktop + krows * (SIZE + GAP)
	else
		main.keyLabel:Hide()
	end

	for _, l in pairs(buttons) do
		for _, b in pairs(l) do
			if not used[b] then b:Hide() end
		end
	end

	main:SetScale(db.scale)
	main:SetSize(PAD * 2 + cols * (SIZE + GAP) - GAP, height - GAP + FOOTER_H + 4)
	self:PlaceWindow()
	self:UpdateAll()
end

-- Re-sorting under the mouse would make items jump while you click them, so in the sorted
-- views a re-layout waits until the mouse leaves the window.
-- Requests are batched: the window's OnUpdate (or OnShow) does one layout per frame.
function TB:RequestLayout()
	self.layoutWanted = true
end

---------------------------------------------------------------------------
-- Footer: free slots + gold
function TB:UpdateFooter()
	if not main then return end
	local free, total = 0, 0
	for bag = 0, self:LastBagID() do
		local n = C_Container.GetContainerNumSlots(bag) or 0
		total = total + n
		local f, family = C_Container.GetContainerNumFreeSlots(bag)
		if f and (family == 0 or family == nil) then free = free + f end
	end
	local color = free == 0 and "|cffff4040" or (free <= 4 and "|cffffcc00" or "|cffd0d0d0")
	main.free:SetText(color .. free .. "|r / " .. total .. " free")
	main.money:SetText(GetMoneyString and GetMoneyString(GetMoney(), true) or tostring(GetMoney()))
end

---------------------------------------------------------------------------
-- Position, stored in screen pixels from the bottom-right so the window grows upward
-- and to the left like Blizzard's bags.
function TB:PlaceWindow()
	if not main then return end
	local s = main:GetEffectiveScale()
	main:ClearAllPoints()
	local p = self.db.pos
	if p then
		main:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", p.x / s, p.y / s)
	else
		main:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 110)
	end
end

local function SavePos()
	local s = main:GetEffectiveScale()
	TB.db.pos = { x = main:GetRight() * s, y = main:GetBottom() * s }
	TB:PlaceWindow()
end

---------------------------------------------------------------------------
-- Actions
function TB:SortBags()
	if InCombatLockdown() then
		self:Print("can't sort in combat.")
		return
	end
	if not (C_Container and C_Container.SortBags) then
		self:Print("this game version has no bag sorting. Use a sorted view instead: /tbags view quality")
		return
	end
	if SOUNDKIT and SOUNDKIT.UI_BAG_SORTING_01 then PlaySound(SOUNDKIT.UI_BAG_SORTING_01) end
	C_Container.SortBags()
end

function TB:SetView(key)
	self.db.view = key
	self:Layout()
	for _, v in ipairs(self.VIEWS) do
		if v.key == key then self:Print("view: " .. v.label) end
	end
end

local function OpenMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then
		SlashCmdList.TITANBAGS("help")
		return
	end
	local db = TB.db
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle("TitanBags")
		root:CreateButton("Sort bags now (moves items)", function() TB:SortBags() end)
		if C_Container.GetSortBagsRightToLeft then
			root:CreateCheckbox("Sort fills the last bag first",
				function() return C_Container.GetSortBagsRightToLeft() end,
				function() C_Container.SetSortBagsRightToLeft(not C_Container.GetSortBagsRightToLeft()) end)
		end
		local view = root:CreateButton("Show items by")
		for _, v in ipairs(TB.VIEWS) do
			view:CreateRadio(v.label, function() return db.view == v.key end, function() TB:SetView(v.key) end)
		end
		local cols = root:CreateButton("Slots per row")
		for _, n in ipairs({ 8, 10, 12, 14, 16, 18, 20, 24 }) do
			cols:CreateRadio(tostring(n), function() return db.columns == n end,
				function() db.columns = n; TB:Layout() end)
		end
		local scale = root:CreateButton("Size")
		for _, n in ipairs({ 0.7, 0.8, 0.9, 1, 1.1, 1.25, 1.5 }) do
			scale:CreateRadio(math.floor(n * 100 + 0.5) .. "%", function() return math.abs(db.scale - n) < 0.01 end,
				function() db.scale = n; TB:Layout() end)
		end
		if TB:KeyringID() then
			root:CreateCheckbox("Show keyring", function() return db.showKeys end,
				function() db.showKeys = not db.showKeys; TB:ApplyBlizzard(); TB:Layout() end)
		end
		root:CreateCheckbox("Lock position", function() return db.locked end,
			function() db.locked = not db.locked end)
		root:CreateButton("Reset position", function() db.pos = nil; TB:PlaceWindow() end)
	end)
end

---------------------------------------------------------------------------
-- Window
local function Backdrop(f, bg, border)
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	f:SetBackdropColor(unpack(bg))
	f:SetBackdropBorderColor(unpack(border))
end

local function Tip(self, title, ...)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(title)
	for i = 1, select("#", ...) do GameTooltip:AddLine(select(i, ...), 0.8, 0.8, 0.8, true) end
	GameTooltip:Show()
end

function TB:CreateWindow()
	if main then return end
	main = CreateFrame("Frame", "TitanBagsFrame", UIParent, "BackdropTemplate")
	self.frame = main
	main:Hide()
	main:SetFrameStrata("MEDIUM")
	main:SetToplevel(true)
	main:SetMovable(true)
	main:SetClampedToScreen(true)
	main:EnableMouse(true)
	Backdrop(main, { 0.06, 0.06, 0.08, 0.92 }, { 0, 0, 0, 1 })
	tinsert(UISpecialFrames, "TitanBagsFrame")

	-- Title bar: drag to move, right-click for options.
	local bar = CreateFrame("Button", nil, main, "BackdropTemplate")
	bar:SetPoint("TOPLEFT", 1, -1)
	bar:SetPoint("TOPRIGHT", -1, -1)
	bar:SetHeight(HEADER_H)
	Backdrop(bar, { 0.12, 0.12, 0.15, 1 }, { 0, 0, 0, 0 })
	bar:RegisterForDrag("LeftButton")
	bar:RegisterForClicks("RightButtonUp")
	bar:SetScript("OnDragStart", function()
		if not TB.db.locked then main:StartMoving() end
	end)
	bar:SetScript("OnDragStop", function()
		main:StopMovingOrSizing()
		SavePos()
	end)
	bar:SetScript("OnClick", function(self, button)
		if button == "RightButton" then OpenMenu(self) end
	end)
	bar:SetScript("OnEnter", function(self)
		Tip(self, "Bags", TB.db.locked and "Locked (right-click to unlock)." or "Drag to move.",
			"Right-click for options: sorted views, slots per row, size.")
	end)
	bar:SetScript("OnLeave", GameTooltip_Hide)

	local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", 8, 0)
	title:SetText("Bags")

	local close = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
	close:SetSize(22, 22)
	close:SetPoint("RIGHT", -1, 0)
	close:SetScript("OnClick", function() main:Hide() end)

	local sort = CreateFrame("Button", nil, bar)
	sort:SetSize(22, 22)
	sort:SetPoint("RIGHT", close, "LEFT", -2, 0)
	sort:SetNormalAtlas(SORT_UP)
	sort:SetPushedAtlas(SORT_DOWN)
	sort:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	sort:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	sort:SetScript("OnClick", function(self, button)
		if button == "RightButton" then OpenMenu(self) else TB:SortBags() end
	end)
	sort:SetScript("OnEnter", function(self)
		Tip(self, "Sort bags", "Left-click: tidy your bags (items really move).",
			"Right-click: options, including sorted views that don't move anything.")
	end)
	sort:SetScript("OnLeave", GameTooltip_Hide)

	local search = CreateFrame("EditBox", "TitanBagsSearchBox", bar, "SearchBoxTemplate")
	search:SetSize(110, 18)
	search:SetPoint("RIGHT", sort, "LEFT", -6, 0)
	search:SetAutoFocus(false)
	search:HookScript("OnTextChanged", function(self)
		if C_Container.SetItemSearch then C_Container.SetItemSearch(self:GetText() or "") end
	end)
	main.search = search

	-- Footer
	main.free = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	main.free:SetPoint("BOTTOMLEFT", PAD, 7)
	main.money = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	main.money:SetPoint("BOTTOMRIGHT", -PAD, 7)

	main.keyLabel = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	main.keyLabel:SetText("Keys")
	main.keyLabel:Hide()

	main:SetScript("OnShow", function()
		if SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN then PlaySound(SOUNDKIT.IG_BACKPACK_OPEN) end
		if TB.layoutWanted or not TB.laidOut then
			TB:Layout()
		else
			TB:UpdateAll()
		end
	end)
	main:SetScript("OnHide", function()
		if SOUNDKIT and SOUNDKIT.IG_BACKPACK_CLOSE then PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE) end
		-- Clear the "new item" glow, like Blizzard does on close.
		if C_NewItems and C_NewItems.RemoveNewItem then
			ForEachShown(function(b) C_NewItems.RemoveNewItem(b:GetParent():GetID(), b:GetID()) end)
		end
		if search:GetText() ~= "" then search:SetText("") end
		search:ClearFocus()
		-- Closed by us (X, Esc): close the real bags too, so the B key stays in step.
		if not TB.syncing and TB:AnyOurBagOpen() then
			CloseAllBags()
		end
	end)
	main:SetScript("OnUpdate", function(self)
		if TB.layoutWanted and (TB.db.view == "bag" or not self:IsMouseOver()) then
			TB:Layout()
		end
	end)

	local function OnEvent(_, event, a1, a2)
		if event == "BAG_UPDATE_DELAYED" or event == "BAG_CONTAINER_UPDATE"
			or event == "GET_ITEM_INFO_RECEIVED" then
			if event == "GET_ITEM_INFO_RECEIVED" and TB.db.view == "bag" then return end
			TB:RequestLayout()
		elseif not main:IsShown() then
			return
		elseif event == "ITEM_LOCK_CHANGED" then
			local b = a1 and a2 and buttons[a1] and buttons[a1][a2]
			if b and b:IsShown() then UpdateButton(b, GameTooltip:GetOwner()) end
		elseif event == "BAG_UPDATE_COOLDOWN" then
			ForEachShown(function(b)
				local has = C_Container.HasContainerItem(b:GetParent():GetID(), b:GetID())
				b:UpdateCooldown(has)
			end)
		elseif event == "PLAYER_MONEY" then
			TB:UpdateFooter()
		else
			TB:UpdateAll()
		end
	end
	for _, e in ipairs({ "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE", "GET_ITEM_INFO_RECEIVED",
		"ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY", "INVENTORY_SEARCH_UPDATE",
		"BAG_NEW_ITEMS_UPDATED", "QUEST_ACCEPTED", "QUEST_REMOVED", "UNIT_QUEST_LOG_CHANGED",
		"MERCHANT_SHOW", "MERCHANT_CLOSED" }) do
		pcall(main.RegisterEvent, main, e)
	end
	main:SetScript("OnEvent", OnEvent)
	self:PlaceWindow()
end

-- Show our window while any of our bags is open (and Blizzard's are hidden).
function TB:Sync()
	if not main then return end
	local want = self.db.hideBlizzard and self:AnyOurBagOpen()
	if want == main:IsShown() then return end
	self.syncing = true
	main:SetShown(want)
	self.syncing = false
end
