-- TitanQuests: saved settings, hiding Blizzard's tracker, events and slash commands.
local ADDON, TQ = ...
_G.TitanQuests = TQ

BINDING_HEADER_TITANQUESTS = "TitanQuests"
_G["BINDING_NAME_CLICK TitanQuestsMinimize:LeftButton"] = "Minimize / restore quest tracker"

local DEFAULTS = {
	hideBlizzard = true,
	showAll = false, -- every quest in the log, not only the tracked ones
	zones = true, -- group quests under their zone
	levels = true, -- [12] before each title
	hideDone = true, -- hide objectives that are finished
	items = true, -- quest item buttons
	minimized = false,
	dungeonMinimize = true,
	combatMinimize = false,
	locked = false,
	width = 250,
	maxHeight = 450,
	scale = 1,
	fontSize = 12,
	alpha = 0.55,
	collapsed = {}, -- [questID] = true
	zoneCollapsed = {}, -- [zone name] = true
}

local function Merge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = type(dst[k]) == "table" and dst[k] or {}
			Merge(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function TQ:Print(msg)
	print("|cff33ccffTitanQuests|r: " .. msg)
end

-- Anything touching secure frames (quest item buttons) must wait until combat ends.
local pending = {}
function TQ:RunOutOfCombat(key, fn)
	if InCombatLockdown() then
		pending[key] = fn
	else
		fn()
	end
end

---------------------------------------------------------------------------
-- Blizzard's tracker. Parenting it to a hidden frame keeps it invisible even
-- when Blizzard code calls :Show() on it, the same way TitanBars hides bars.
---------------------------------------------------------------------------
local hider = CreateFrame("Frame")
hider:Hide()
local blizzParent

function TQ:UpdateBlizzard()
	local f = ObjectiveTrackerFrame
	if not f then return end
	self:RunOutOfCombat("blizzard", function()
		if self.db.hideBlizzard then
			if f:GetParent() ~= hider then
				blizzParent = f:GetParent()
				f:SetParent(hider)
			end
		elseif f:GetParent() == hider then
			f:SetParent(blizzParent or UIParent)
			f:Show()
		end
	end)
end

---------------------------------------------------------------------------
-- Dungeons and raids
---------------------------------------------------------------------------
local wasInInstance
function TQ:CheckInstance()
	local _, kind = IsInInstance()
	local inside = kind == "party" or kind == "raid"
	if inside == wasInInstance then return end
	wasInInstance = inside
	if not self.db.dungeonMinimize then return end
	if inside then
		-- Remember whether it was open so leaving puts it back the way it was.
		-- Saved, so logging out inside a dungeon and back in outside still restores it.
		if self.db.reopenAfterInstance == nil then
			self.db.reopenAfterInstance = not self.db.minimized
		end
		self:SetMinimized(true)
	elseif self.db.reopenAfterInstance ~= nil then
		local reopen = self.db.reopenAfterInstance
		self.db.reopenAfterInstance = nil
		if reopen then self:SetMinimized(false) end
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_REMOVED")
events:RegisterEvent("BAG_UPDATE_COOLDOWN")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		TitanQuestsDB = TitanQuestsDB or {}
		Merge(TitanQuestsDB, DEFAULTS)
		TQ.db = TitanQuestsDB
	elseif event == "PLAYER_LOGIN" then
		TQ:SetupTracker()
		TQ:SetupItems()
		TQ:UpdateBlizzard()
		TQ:Refresh()
	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		TQ:UpdateBlizzard()
		TQ:CheckInstance()
		TQ:Refresh()
	elseif event == "PLAYER_REGEN_DISABLED" then
		TQ:UpdateCombat(true)
	elseif event == "PLAYER_REGEN_ENABLED" then
		for key, fn in pairs(pending) do
			pending[key] = nil
			fn()
		end
		TQ:UpdateCombat(false)
	elseif event == "BAG_UPDATE_COOLDOWN" then
		TQ:UpdateItemCooldowns()
	else
		-- Quest events come in bursts (one kill can fire several); redraw once.
		if not TQ.queued then
			TQ.queued = true
			C_Timer.After(0.1, function()
				TQ.queued = nil
				TQ:Refresh()
			end)
		end
	end
end)

SLASH_TITANQUESTS1 = "/tquests"
SLASH_TITANQUESTS2 = "/titanquests"
SlashCmdList.TITANQUESTS = function(msg)
	local cmd = strtrim(msg or ""):lower()
	if cmd == "" or cmd == "config" then
		TQ:ToggleConfig()
	elseif cmd == "min" or cmd == "toggle" then
		TQ:SetMinimized(not TQ.db.minimized)
	elseif cmd == "lock" or cmd == "unlock" then
		TQ.db.locked = cmd == "lock"
		TQ:Print(TQ.db.locked and "Locked." or "Unlocked. Drag the title bar to move it.")
		TQ:RefreshConfig()
	elseif cmd == "reset" then
		TQ:RunOutOfCombat("reset", function()
			TQ.db.pos, TQ.db.width, TQ.db.scale = nil, DEFAULTS.width, 1
			TQ:ApplyLayout()
			TQ:RefreshConfig()
		end)
	else
		TQ:Print("/tquests  - settings window")
		TQ:Print("/tquests min  - minimize or restore the tracker (also a keybind under AddOns)")
		TQ:Print("/tquests lock | unlock  - stop or allow dragging")
		TQ:Print("/tquests reset  - put it back by the minimap")
	end
end
