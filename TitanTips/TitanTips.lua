-- TitanTips: more useful tooltips.
--   Items: item level on gear, which of your professions use it (learned from TitanCraft),
--          how many your other characters hold (bags + bank), and optionally item ID.
--   Units: class-coloured player names, guild, and who they're targeting.
-- Uses Blizzard's tooltip hooks (TooltipDataProcessor), so it never replaces a tooltip.
local ADDON, TT = ...
_G.TitanTips = TT

local DEFAULTS = {
	itemLevel = true,
	usedIn = true,
	altCounts = true,
	itemID = false,
	spellID = false,
	classColors = true,
	unitTarget = true,
	realms = {},   -- [realm] = { [name] = { class, faction, bags = {}, bank = {}, equip = {} } }
}

local function Merge(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then dst[k] = type(v) == "table" and {} or v end
	end
end

local function Secret(v) return issecretvalue and issecretvalue(v) or false end
local GREY = "|cff8a8a96"

---------------------------------------------------------------------------
-- Inventory snapshots (for the "your other characters" line)
local me, realm

local function Me()
	local r = TT.db.realms[realm] or {}
	TT.db.realms[realm] = r
	local c = r[me] or {}
	r[me] = c
	local _, class = UnitClass("player")
	c.class, c.faction = class, UnitFactionGroup("player")
	c.bags, c.bank, c.equip = c.bags or {}, c.bank or {}, c.equip or {}
	return c
end

local function Scan(ids)
	local out = {}
	for _, bag in ipairs(ids) do
		local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
		for slot = 1, (ok and n or 0) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID and not Secret(info.itemID) then
				out[info.itemID] = (out[info.itemID] or 0) + (not Secret(info.stackCount) and info.stackCount or 1)
			end
		end
	end
	return out
end

local function BagIDs()
	local t = {}
	for i = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4) do table.insert(t, i) end
	local key = Enum and Enum.BagIndex and Enum.BagIndex.Keyring
	if key then table.insert(t, key) end
	return t
end

local function BankIDs()
	local t = { (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or -1 }
	local B = Enum and Enum.BagIndex
	if B and B.CharacterBankTab_1 then
		for i = 1, 8 do
			local id = B["CharacterBankTab_" .. i]
			if id then table.insert(t, id) end
		end
	else
		for i = (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 7) do table.insert(t, i) end
	end
	return t
end

local bankOpen = false
function TT:SaveBags() Me().bags = Scan(BagIDs()) end
function TT:SaveBank() if bankOpen then Me().bank = Scan(BankIDs()) end end
function TT:SaveEquip()
	local e = {}
	for slot = 1, 19 do
		local id = GetInventoryItemID("player", slot)
		if id then e[id] = (e[id] or 0) + 1 end
	end
	Me().equip = e
end

-- "Bob 20 (bank 5), Sue 3" for one item, other characters on this realm.
local function AltLine(itemID)
	local parts, total = {}, 0
	for name, c in pairs(TT.db.realms[realm] or {}) do
		if name ~= me then
			local bags, bank, eq = (c.bags or {})[itemID] or 0, (c.bank or {})[itemID] or 0, (c.equip or {})[itemID] or 0
			local n = bags + bank + eq
			if n > 0 then
				total = total + n
				local col = c.class and RAID_CLASS_COLORS[c.class]
				local label = col and ("|cff%02x%02x%02x%s|r"):format(math.floor(col.r * 255), math.floor(col.g * 255), math.floor(col.b * 255), name) or name
				local extra = {}
				if bank > 0 then table.insert(extra, "bank " .. bank) end
				if eq > 0 then table.insert(extra, "worn") end
				table.insert(parts, label .. " " .. n .. (#extra > 0 and (GREY .. " (" .. table.concat(extra, ", ") .. ")|r") or ""))
			end
		end
	end
	if total == 0 then return nil end
	table.sort(parts)
	return parts
end

---------------------------------------------------------------------------
-- Which of your professions use an item: TitanCraft records every reagent of every
-- recipe you've opened (TitanCraftDB.reagentUse). Without TitanCraft, trade goods get a
-- hint from their category.
local TRADE_HINT = {
	[5] = "Tailoring, First Aid",           -- cloth
	[6] = "Leatherworking",                 -- leather
	[7] = "Blacksmithing, Engineering",     -- metal & stone
	[8] = "Cooking",                        -- meat / cooking
	[9] = "Alchemy",                        -- herb
	[10] = "Enchanting, crafting",          -- elemental
	[12] = "Enchanting",                    -- enchanting
	[1] = "Engineering",                    -- parts
}

local function UsedIn(itemID)
	local db = _G.TitanCraftDB
	local use = db and db.reagentUse and db.reagentUse[itemID]
	if use then
		local list = {}
		for prof, n in pairs(use) do table.insert(list, ("%s (%d)"):format(prof, n)) end
		table.sort(list)
		if #list > 0 then return table.concat(list, ", "), true end
	end
	local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(itemID)
	if classID == 7 and TRADE_HINT[subID] then return TRADE_HINT[subID], false end
end

---------------------------------------------------------------------------
-- Tooltip hooks
local function OnItem(tip)
	if tip ~= GameTooltip and tip ~= ItemRefTooltip then return end
	local ok, _, link, id = pcall(tip.GetItem, tip)
	if not ok or not link or Secret(link) then return end
	id = id or C_Item.GetItemInfoInstant(link)
	if not id then return end
	local db = TT.db
	local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(id)
	if db.itemLevel and (classID == 2 or classID == 4) and equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
		local ilvl = C_Item.GetDetailedItemLevelInfo(link)
		if ilvl and ilvl > 0 then tip:AddLine("Item level " .. ilvl, 1, 0.82, 0) end
	end
	if db.usedIn then
		local text, mine = UsedIn(id)
		if text then tip:AddLine((mine and "Your crafts use this: " or "Used in: ") .. text, 0.45, 0.75, 1, true) end
	end
	if db.altCounts then
		local parts = AltLine(id)
		if parts then
			tip:AddLine("Your other characters:", 0.6, 0.8, 1)
			for _, p in ipairs(parts) do tip:AddLine("  " .. p, 1, 1, 1) end
		end
	end
	if db.itemID then tip:AddLine(GREY .. "Item ID " .. id .. "|r") end
	tip:Show()
end

local function OnUnit(tip)
	if tip ~= GameTooltip then return end
	local ok, _, unit = pcall(tip.GetUnit, tip)
	if not ok or not unit or Secret(unit) then return end
	local db = TT.db
	if db.classColors and UnitIsPlayer(unit) then
		local okc, _, class = pcall(UnitClass, unit)
		local col = okc and not Secret(class) and class and RAID_CLASS_COLORS[class]
		local line = _G[tip:GetName() .. "TextLeft1"]
		if col and line then line:SetTextColor(col.r, col.g, col.b) end
	end
	if db.unitTarget and UnitExists(unit .. "target") then
		local name = UnitName(unit .. "target")
		local isMe = UnitIsUnit(unit .. "target", "player")
		pcall(function()
			if not Secret(isMe) and isMe then
				tip:AddLine("Target: |cffff4040YOU|r", 1, 0.82, 0)
			else
				tip:AddDoubleLine("Target:", name, 1, 0.82, 0, 1, 1, 1)
			end
		end)
	end
	tip:Show()
end

local function OnSpell(tip)
	if not TT.db.spellID or tip ~= GameTooltip then return end
	local ok, _, id = pcall(tip.GetSpell, tip)
	if ok and id and not Secret(id) then
		tip:AddLine(GREY .. "Spell ID " .. id .. "|r")
		tip:Show()
	end
end

local function Hook()
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		local T = Enum.TooltipDataType
		TooltipDataProcessor.AddTooltipPostCall(T.Item, function(tip) pcall(OnItem, tip) end)
		TooltipDataProcessor.AddTooltipPostCall(T.Unit, function(tip) pcall(OnUnit, tip) end)
		if T.Spell then TooltipDataProcessor.AddTooltipPostCall(T.Spell, function(tip) pcall(OnSpell, tip) end) end
	else
		GameTooltip:HookScript("OnTooltipSetItem", function(tip) pcall(OnItem, tip) end)
		GameTooltip:HookScript("OnTooltipSetUnit", function(tip) pcall(OnUnit, tip) end)
	end
end

---------------------------------------------------------------------------
function TT:Characters()
	local list = {}
	for name, c in pairs(self.db.realms[realm] or {}) do table.insert(list, { name = name, class = c.class }) end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

function TT:Forget(name)
	local r = self.db.realms[realm]
	if r and name ~= me then r[name] = nil end
end

SLASH_TITANTIPS1 = "/ttips"
SLASH_TITANTIPS2 = "/titantips"
SlashCmdList.TITANTIPS = function(msg)
	local cmd, arg = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
	if cmd == "forget" and arg ~= "" then
		TT:Forget(arg)
		print("|cff33ccffTitanTips|r: forgot " .. arg .. ".")
	elseif _G.TitanUI then
		_G.TitanUI:Open("TitanTips")
	else
		print("|cff33ccffTitanTips|r: settings are in TitanUI. /ttips forget <name> removes a character.")
	end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
	"BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
	"PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }) do
	pcall(ev.RegisterEvent, ev, e)
end
local BANKER = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker
ev:SetScript("OnEvent", function(_, event, a1)
	if event == "ADDON_LOADED" then
		if a1 == ADDON then
			TitanTipsDB = TitanTipsDB or {}
			Merge(TitanTipsDB, DEFAULTS)
			TT.db = TitanTipsDB
		end
		return
	end
	if not TT.db then return end
	if event == "PLAYER_LOGIN" then
		me, realm = UnitName("player"), GetRealmName()
		Hook()
		TT:SaveBags()
		TT:SaveEquip()
		TT.ready = true
	elseif event == "BAG_UPDATE_DELAYED" then
		TT:SaveBags()
		TT:SaveBank()
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		TT:SaveEquip()
	elseif event == "BANKFRAME_OPENED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and a1 == BANKER) then
		bankOpen = true
		C_Timer.After(0.5, function() TT:SaveBank() end)
	elseif event == "BANKFRAME_CLOSED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" and a1 == BANKER) then
		TT:SaveBank()
		bankOpen = false
	elseif event == "PLAYERBANKSLOTS_CHANGED" then
		TT:SaveBank()
	end
end)
