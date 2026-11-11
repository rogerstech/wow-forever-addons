-- TitanMap: saved settings, events and slash commands.
local ADDON, TM = ...
_G.TitanMap = TM

BINDING_HEADER_TITANMAP = "TitanMap"
BINDING_NAME_TITANMAP_TOGGLE = "Show / hide map overlay"

local DEFAULTS = {
	shown = true,
	width = 520,
	mapAlpha = 0.35, -- the map picture
	pinAlpha = 1, -- your arrow and the quest markers
	areas = true, -- shaded quest objective areas
	names = true, -- quest name next to each marker
	trackedOnly = true,
	hideInCombat = false,
	hideInInstance = false,
	-- pos = { x, y } centre in UIParent units once moved
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

function TM:Print(msg)
	print("|cff33ccffTitanMap|r: " .. msg)
end

function TM:Toggle()
	self.db.shown = not self.db.shown
	self:UpdateVisibility()
	self:RefreshConfig()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
events:RegisterEvent("QUEST_POI_UPDATE")
events:RegisterEvent("SUPER_TRACKING_CHANGED")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		TitanMapDB = TitanMapDB or {}
		Merge(TitanMapDB, DEFAULTS)
		TM.db = TitanMapDB
	elseif event == "PLAYER_LOGIN" then
		TM:SetupMap()
		TM:AddTitanQuestsButton()
	elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		TM.inCombat = event == "PLAYER_REGEN_DISABLED"
		TM:UpdateVisibility()
	elseif event == "PLAYER_ENTERING_WORLD" or event:find("^ZONE_CHANGED") then
		TM:UpdateVisibility()
		TM:CheckMap()
	else
		-- Quest events come in bursts; redraw the markers once.
		if not TM.queued then
			TM.queued = true
			C_Timer.After(0.2, function()
				TM.queued = nil
				TM:RefreshQuests()
			end)
		end
	end
end)

SLASH_TITANMAP1 = "/tmap"
SLASH_TITANMAP2 = "/titanmap"
SlashCmdList.TITANMAP = function(msg)
	local cmd = strtrim(msg or ""):lower()
	if cmd == "" or cmd == "toggle" then
		TM:Toggle()
	elseif cmd == "config" or cmd == "options" then
		TM:ToggleConfig()
	elseif cmd == "unlock" then
		TM:SetUnlocked(true)
	elseif cmd == "lock" then
		TM:SetUnlocked(false)
	elseif cmd == "reset" then
		TM.db.pos, TM.db.width = nil, DEFAULTS.width
		TM:ApplyLayout()
		TM:RefreshConfig()
	else
		TM:Print("/tmap  - show or hide the map (also a keybind under AddOns)")
		TM:Print("/tmap config  - settings")
		TM:Print("/tmap unlock  - drag to move, mouse wheel to resize; /tmap lock when done")
		TM:Print("/tmap reset  - back to the middle of the screen")
	end
end
