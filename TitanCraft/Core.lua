-- TitanCraft: saved settings, recipe data, hiding Blizzard's profession window.
--
-- How the swap works: when you open a profession the game still opens Blizzard's
-- profession window as normal; TitanCraft only moves that window into an invisible parent,
-- so the profession stays open and every crafting call works, and shows its own window
-- instead. Closing ours closes the profession. Viewing someone else's linked profession,
-- a guild list or an NPC crafter leaves Blizzard's window alone.
local ADDON, TC = ...
_G.TitanCraft = TC

local DEFAULTS = {
	replace = true,      -- use TitanCraft instead of Blizzard's window
	sort = "skill",      -- skill | craftable | name | category
	hideTrivial = false, -- hide grey recipes
	haveMats = false,    -- only recipes you can make right now
	scale = 1,
	height = 520,
	locked = false,
	pos = nil,           -- { x, y } top-left in screen pixels
}

TC.SORTS = {
	{ key = "skill",     label = "Skill-ups first (orange, yellow, green, grey)" },
	{ key = "craftable", label = "Can make now first" },
	{ key = "name",      label = "Name (A to Z)" },
	{ key = "category",  label = "Category" },
}

-- Recipe colour = your chance of a skill point (Enum.TradeskillRelativeDifficulty).
TC.DIFF = {
	[0] = { r = 1.00, g = 0.50, b = 0.25, word = "Orange", chance = "always gives a skill point" },
	[1] = { r = 1.00, g = 1.00, b = 0.00, word = "Yellow", chance = "usually gives a skill point" },
	[2] = { r = 0.25, g = 0.75, b = 0.25, word = "Green",  chance = "sometimes gives a skill point" },
	[3] = { r = 0.55, g = 0.55, b = 0.55, word = "Grey",   chance = "never gives a skill point" },
}

local function Merge(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then dst[k] = v end
	end
end

function TC:Print(msg)
	print("|cff33ccffTitanCraft|r: " .. msg)
end

local function IsSecret(v) return issecretvalue and issecretvalue(v) or false end
local function Clean(v, d) if v == nil or IsSecret(v) then return d end return v end
TC.Clean = Clean

---------------------------------------------------------------------------
-- Which kind of profession window is open.
function TC:IsOwnProfession()
	local T = C_TradeSkillUI
	if not T then return false end
	if T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return false end
	if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return false end
	if T.IsNPCCrafting and T.IsNPCCrafting() then return false end
	return true
end

function TC:ProfessionInfo()
	local T = C_TradeSkillUI
	local info = T.GetChildProfessionInfo and T.GetChildProfessionInfo()
	if not info or not info.professionID or info.professionID == 0 then
		info = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
	end
	return info or {}
end

---------------------------------------------------------------------------
-- Recipe data
local function ItemCount(itemID)
	if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemID) or 0 end
	return GetItemCount and GetItemCount(itemID) or 0
end
TC.ItemCount = ItemCount

-- The basic reagents a recipe needs: { {itemID, need}, ... }
function TC:Reagents(recipeID)
	local list = {}
	local s = C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
	if not s or not s.reagentSlotSchematics then return list end
	local BASIC = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1
	for _, slot in ipairs(s.reagentSlotSchematics) do
		local r = slot.reagents and slot.reagents[1]
		if r and r.itemID and (slot.reagentType == BASIC or slot.required) then
			table.insert(list, { itemID = r.itemID, need = slot.quantityRequired or 1 })
		end
	end
	return list, s
end

function TC:Available(recipeID, info)
	if C_TradeSkillUI.GetCraftableCount then
		local ok, n = pcall(C_TradeSkillUI.GetCraftableCount, recipeID)
		if ok and type(n) == "number" then return n end
	end
	if info and type(info.numAvailable) == "number" then return info.numAvailable end
	local n = math.huge
	for _, r in ipairs(self:Reagents(recipeID)) do
		n = math.min(n, math.floor(ItemCount(r.itemID) / r.need))
	end
	return n == math.huge and 0 or n
end

local catNames = {}
local function CategoryName(id)
	if not id then return "Other" end
	if catNames[id] == nil then
		local c = C_TradeSkillUI.GetCategoryInfo and C_TradeSkillUI.GetCategoryInfo(id)
		catNames[id] = c and c.name or "Other"
	end
	return catNames[id]
end

-- Every learned recipe of the open profession.
function TC:Gather()
	local T = C_TradeSkillUI
	local ids = (T.GetAllRecipeIDs and T.GetAllRecipeIDs()) or (T.GetFilteredRecipeIDs and T.GetFilteredRecipeIDs()) or {}
	local out = {}
	wipe(catNames)
	for _, id in ipairs(ids) do
		local info = T.GetRecipeInfo(id)
		if info and info.learned and not info.isDummyRecipe and not info.isRecraft and not info.isSalvageRecipe then
			local diff = Clean(info.relativeDifficulty, 3)
			if info.canSkillUp == false then diff = 3 end
			table.insert(out, {
				id = id,
				info = info,
				name = Clean(info.name, "?"),
				diff = diff,
				ups = Clean(info.numSkillUps, 1),
				avail = self:Available(id, info),
				cat = CategoryName(info.categoryID),
			})
		end
	end
	return out
end

local function ByName(a, b) return a.name < b.name end

local COMPARE = {
	skill = function(a, b)
		if a.diff ~= b.diff then return a.diff < b.diff end
		local ca, cb = a.avail > 0, b.avail > 0
		if ca ~= cb then return ca end
		if a.ups ~= b.ups then return a.ups > b.ups end
		return ByName(a, b)
	end,
	craftable = function(a, b)
		local ca, cb = a.avail > 0, b.avail > 0
		if ca ~= cb then return ca end
		if a.diff ~= b.diff then return a.diff < b.diff end
		return ByName(a, b)
	end,
	name = ByName,
	category = function(a, b)
		if a.cat ~= b.cat then return a.cat < b.cat end
		if a.diff ~= b.diff then return a.diff < b.diff end
		return ByName(a, b)
	end,
}

-- The list shown, after search and filters, in the chosen order.
function TC:Filtered(all, search)
	local db = self.db
	local list = {}
	search = search and search:lower() or ""
	for _, r in ipairs(all) do
		local keep = true
		if db.hideTrivial and r.diff == 3 then keep = false end
		if db.haveMats and r.avail <= 0 then keep = false end
		if keep and search ~= "" and not r.name:lower():find(search, 1, true) then keep = false end
		if keep then table.insert(list, r) end
	end
	table.sort(list, COMPARE[db.sort] or COMPARE.skill)
	return list
end

-- The recipe "Craft next skill-up" makes: best chance of a point that you can make now.
function TC:NextSkillUp(all)
	local best
	for _, r in ipairs(all) do
		if r.diff <= 2 and r.avail > 0 then
			if not best or COMPARE.skill(r, best) then best = r end
		end
	end
	return best
end

function TC:Craft(recipeID, count)
	if InCombatLockdown() then
		self:Print("can't craft in combat.")
		return
	end
	count = math.max(1, math.floor(count or 1))
	C_TradeSkillUI.CraftRecipe(recipeID, count)
end

---------------------------------------------------------------------------
-- Blizzard's window
local hidden = CreateFrame("Frame")
hidden:Hide()
local blizzParent
TC.showBlizzard = false   -- "Blizzard window" button, until the profession closes

function TC:WantOurs()
	return self.db.replace and not self.showBlizzard and self:IsOwnProfession()
end

function TC:PlaceBlizzard()
	local f = ProfessionsFrame
	if not f then return end
	if self:WantOurs() then
		if f:GetParent() ~= hidden then
			blizzParent = blizzParent or f:GetParent()
			f:SetParent(hidden)
		end
	elseif f:GetParent() == hidden then
		f:SetParent(blizzParent or UIParent)
	end
end

local hooked = false
function TC:HookBlizzard()
	local f = ProfessionsFrame
	if hooked or not f then return end
	hooked = true
	local function Later() C_Timer.After(0, function() TC:Sync() end) end
	hooksecurefunc(f, "Show", Later)
	hooksecurefunc(f, "Hide", Later)
	hooksecurefunc(f, "SetShown", Later)
	self:PlaceBlizzard()
end

-- Ours is shown while Blizzard's profession window is "open" and we're replacing it.
function TC:Sync()
	if not self.frame then return end
	local open = ProfessionsFrame and ProfessionsFrame:IsShown()
	if not open then self.showBlizzard = false end
	self:PlaceBlizzard()
	local want = open and self:WantOurs() or false
	-- Blizzard's window was closed (Esc, another panel) while hidden: its own close code
	-- didn't run, so end the profession session here.
	if not open and self.frame:IsShown() and C_TradeSkillUI.CloseTradeSkill then
		C_TradeSkillUI.CloseTradeSkill()
	end
	if want ~= self.frame:IsShown() then
		self.syncing = true
		self.frame:SetShown(want)
		self.syncing = false
	end
	if want then self:RequestRefresh() end
end

-- Our close button / Esc: close the profession the same way Blizzard's window does.
function TC:CloseProfession()
	if ProfessionsFrame and ProfessionsFrame:IsShown() then HideUIPanel(ProfessionsFrame) end
	if C_TradeSkillUI.CloseTradeSkill then C_TradeSkillUI.CloseTradeSkill() end
end

function TC:UseBlizzard(recipeID)
	self.showBlizzard = true
	self:Sync()
	if recipeID and C_TradeSkillUI.OpenRecipe then pcall(C_TradeSkillUI.OpenRecipe, recipeID) end
end

---------------------------------------------------------------------------
SLASH_TITANCRAFT1 = "/tcraft"
SLASH_TITANCRAFT2 = "/titancraft"
SlashCmdList.TITANCRAFT = function(msg)
	local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	local db = TC.db
	if cmd == "blizzard" and (arg == "on" or arg == "off") then
		db.replace = (arg == "off")
		TC:Sync()
		TC:Print(db.replace and "TitanCraft replaces Blizzard's profession window." or "Blizzard's profession window is back.")
	elseif cmd == "reset" then
		db.pos, db.height = nil, DEFAULTS.height
		TC:PlaceWindow()
	elseif cmd == "settings" and _G.TitanUI then
		_G.TitanUI:Open("TitanCraft")
	else
		TC:Print("open a profession as usual and TitanCraft's window appears.")
		print("  /tcraft blizzard on|off - use Blizzard's window instead (on) or TitanCraft (off)")
		print("  /tcraft reset - window back to the middle of the screen")
		print("  /tcraft settings - TitanCraft's page in TitanUI")
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("TRADE_SKILL_SHOW")
ev:RegisterEvent("TRADE_SKILL_CLOSE")
ev:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
ev:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name == ADDON then
			TitanCraftDB = TitanCraftDB or {}
			Merge(TitanCraftDB, DEFAULTS)
			TC.db = TitanCraftDB
		elseif name == "Blizzard_Professions" then
			TC:HookBlizzard()
		end
	elseif event == "PLAYER_LOGIN" then
		TC:CreateWindow()
		TC:HookBlizzard()
	else
		if event == "TRADE_SKILL_CLOSE" then TC.showBlizzard = false end
		TC:HookBlizzard()
		TC:PlaceBlizzard()
		C_Timer.After(0, function() TC:Sync() end)
	end
end)
