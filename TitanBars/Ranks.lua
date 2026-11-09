-- TitanBars: keep action buttons on the newest spell rank.
-- Classic ranks are separate spells, so learning Maul (Rank 6) leaves Rank 5 on your bars.
-- After every spellbook change we compare each spell's highest known rank with the one we
-- saw last time (saved per character in db.rankTop). Buttons holding the OLD top rank are
-- moved to the new one. Buttons holding an even lower rank were downranked on purpose
-- (e.g. a cheap Healing Touch), so they are left alone. /tb rankup upgrades those too.
local ADDON, TB = ...

local BANK = Enum.SpellBookSpellBank.Player
local MAX_ACTION_SLOT = 180 -- 15 pages of 12, covers every bar and form page

-- name -> { slot = spellbook slot, spellID = highest known rank }
local function ScanSpellbook()
	local map = {}
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if info then
			for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
				local item = C_SpellBook.GetSpellBookItemInfo(i, BANK)
				if item and item.itemType == Enum.SpellBookItemType.Spell and item.spellID
					and not item.isPassive and not C_SpellBook.IsSpellBookItemLowRank(i, BANK) then
					map[item.name] = { slot = i, spellID = item.spellID }
				end
			end
		end
	end
	return map
end

local function RankText(spellID)
	local sub = C_Spell.GetSpellSubtext(spellID)
	return (sub and sub ~= "") and sub or ("spell " .. spellID)
end

-- Put the spellbook's top rank of `best` into action slot `slot`. Returns true if it stuck.
local function Upgrade(slot, best)
	if GetCursorInfo() then return false end -- don't drop whatever the player is holding
	C_SpellBook.PickupSpellBookItem(best.slot, BANK)
	PlaceAction(slot)
	ClearCursor() -- the old rank lands on the cursor after the swap
	local kind, id = GetActionInfo(slot)
	return kind == "spell" and id == best.spellID
end

-- Upgrade every button whose spell `fits(name, actionSpellID, best)` says should move.
-- Returns how many moved and a set of spell names where a swap didn't take.
local function UpgradeSlots(map, fits)
	local count, failed = 0, {}
	for slot = 1, MAX_ACTION_SLOT do
		local kind, id = GetActionInfo(slot)
		if kind == "spell" and id then
			local name = C_Spell.GetSpellName(id)
			local best = name and map[name]
			if best and best.spellID ~= id and fits(name, id, best) then
				local old = RankText(id)
				if Upgrade(slot, best) then
					count = count + 1
					TB:Print(("%s %s -> %s (slot %d)"):format(name, old, RankText(best.spellID), slot))
				else
					failed[name] = true
				end
			end
		end
	end
	return count, failed
end

-- Called (debounced) after the spellbook changes.
function TB:CheckRanks()
	local db = self.db
	local map = ScanSpellbook()
	if next(map) == nil then return end -- spellbook not loaded yet
	local firstRun = db.rankTop == nil
	db.rankTop = db.rankTop or {}

	local failed = {}
	if db.autoRankUp and not firstRun then
		local oldTop = {} -- name -> previous top spellID, only for spells that gained a rank
		for name, best in pairs(map) do
			local prev = db.rankTop[name]
			if prev and prev ~= best.spellID then oldTop[name] = prev end
		end
		if next(oldTop) then
			local _
			_, failed = UpgradeSlots(map, function(name, id) return oldTop[name] == id end)
		end
	end

	-- A spell whose swap didn't take keeps its old top, so the next check retries it.
	for name, best in pairs(map) do
		if not failed[name] then db.rankTop[name] = best.spellID end
	end
end

-- /tb rankup: move every lower rank on the bars up, downranks included.
function TB:RankUpAll()
	local n = UpgradeSlots(ScanSpellbook(), function() return true end)
	if n == 0 then self:Print("Every spell on your bars is already the highest rank you know.") end
end

local timerPending = false
local function Schedule()
	if timerPending then return end
	timerPending = true
	-- Training several ranks fires a burst of events; check once after they settle.
	C_Timer.After(1, function()
		timerPending = false
		TB:RunOutOfCombat("rankup", function() TB:CheckRanks() end, true)
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
events:SetScript("OnEvent", function()
	if TB.db then Schedule() end
end)
