-- TitanMeter: the damage meter window. Reads the game's own meter data (C_DamageMeter).
local ADDON, TM = ...

local DMT = Enum and Enum.DamageMeterType or {}
local DMS = Enum and Enum.DamageMeterSessionType or {}

-- style: "total" = total (per second), "rate" = per second (total), "count" = total only
TM.MODES = {
	{ type = DMT.DamageDone, label = "Damage", style = "total" },
	{ type = DMT.Dps, label = "DPS", style = "rate" },
	{ type = DMT.HealingDone, label = "Healing", style = "total" },
	{ type = DMT.Hps, label = "HPS", style = "rate" },
	{ type = DMT.DamageTaken, label = "Damage Taken", style = "total" },
	{ type = DMT.Absorbs, label = "Absorbs", style = "total" },
	{ type = DMT.Interrupts, label = "Interrupts", style = "count" },
	{ type = DMT.Dispels, label = "Dispels", style = "count" },
	{ type = DMT.Deaths, label = "Deaths", style = "count" },
	{ type = DMT.EnemyDamageTaken, label = "Enemy Damage Taken", style = "total" },
}

local win, sessionBtn
local dirty, elapsed, lastError = true, 0, nil
local LOCAL_NAME = CreateColor(1, 0.82, 0.25, 1)
local OTHER_NAME = CreateColor(1, 1, 1, 1)

local function Cfg() return TM.db.meter end

local function Mode()
	local m = TM.MODES[Cfg().mode]
	if not m or m.type == nil then
		Cfg().mode = 1
		m = TM.MODES[1]
	end
	return m
end

local function SessionType()
	return Cfg().overall and DMS.Overall or DMS.Current
end

local function FormatTime(sec)
	if sec == nil or TM.IsSecret(sec) then return "" end
	sec = math.floor(sec)
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function HideRows(from)
	for i = from, #win.rows do
		win.rows[i]:Hide()
		win.rows[i].src = nil
	end
end

local function FillRow(row, index, src, maxAmount, style)
	row:SetMinMaxValues(0, maxAmount)
	row:SetValue(src.totalAmount)
	row:GetStatusBarTexture():SetVertexColor(TM.ClassColor(src.classFilename):GetRGB())
	row.name:SetFormattedText("%d. %s", index, src.name)
	row.name:SetTextColor((src.isLocalPlayer and LOCAL_NAME or OTHER_NAME):GetRGB())
	if style == "total" then
		row.value:SetFormattedText("%s (%s)", TM.Short(src.totalAmount), TM.Short(src.amountPerSecond))
	elseif style == "rate" then
		row.value:SetFormattedText("%s (%s)", TM.Short(src.amountPerSecond), TM.Short(src.totalAmount))
	else
		row.value:SetText(TM.Short(src.totalAmount))
	end
	row.src = src
	row:Show()
end

local function Update()
	local cfg, mode = Cfg(), Mode()
	win.title:SetText(mode.label)
	local dur = C_DamageMeter and C_DamageMeter.GetSessionDurationSeconds
		and select(2, pcall(C_DamageMeter.GetSessionDurationSeconds, SessionType()))
	sessionBtn.text:SetFormattedText("%s %s", cfg.overall and "Overall" or "Current", FormatTime(dur))

	if not C_DamageMeter then
		win.empty:SetText("This game version has no damage meter data.")
		return HideRows(1)
	end
	local okA, available, reason = pcall(C_DamageMeter.IsDamageMeterAvailable)
	if okA and available == false then
		win.empty:SetText(reason ~= "" and reason or "The damage meter isn't available right now.")
		return HideRows(1)
	end

	local session = C_DamageMeter.GetCombatSessionFromType(SessionType(), mode.type)
	local sources = session and session.combatSources or {}
	local count = #sources
	if count == 0 then
		win.empty:SetText(TM.db.locked and "No data yet." or "No data yet. Drag the title to move.")
		return HideRows(1)
	end
	win.empty:SetText("")

	-- The game already sorts the list (we can't sort secret numbers ourselves).
	-- If you're below the last row, you take the last row.
	local rows = cfg.rows
	local youAt
	for i = 1, count do
		if sources[i].isLocalPlayer then youAt = i break end
	end
	local shown = math.min(count, rows)
	for r = 1, shown do
		local i = r
		if r == rows and youAt and youAt > rows then i = youAt end
		FillRow(TM:GetRow(win, r), i, sources[i], session.maxAmount, mode.style)
	end
	HideRows(shown + 1)
end

local function SafeUpdate()
	if not win or not win:IsShown() then return end
	local ok, err = pcall(Update)
	if not ok then
		win.empty:SetText("Meter error - see chat.")
		HideRows(1)
		if err ~= lastError then
			lastError = err
			TM:Print("damage meter error (please send this to Adam): " .. tostring(err))
		end
	end
end

---------------------------------------------------------------------------
-- Tooltip: the spells behind a bar. The game only lets us look these up out of combat.
local function RowEnter(row)
	local src = row.src
	if not src then return end
	GameTooltip:SetOwner(row, "ANCHOR_LEFT")
	if InCombatLockdown() or TM.IsSecret(src.sourceGUID) or TM.IsSecret(src.name) then
		GameTooltip:SetText("Spell breakdown shows after combat.", 1, 1, 1)
		GameTooltip:Show()
		return
	end
	GameTooltip:SetText(src.name, TM.ClassColor(src.classFilename):GetRGB())
	local ok, detail = pcall(C_DamageMeter.GetCombatSessionSourceFromType, SessionType(), Mode().type,
		src.sourceGUID, src.sourceCreatureID)
	local spells = ok and detail and detail.combatSpells
	if not spells or #spells == 0 or TM.IsSecret(spells[1].totalAmount) then
		GameTooltip:AddLine("No spell details.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
		return
	end
	local list = {}
	for i = 1, #spells do list[i] = spells[i] end
	table.sort(list, function(a, b) return a.totalAmount > b.totalAmount end)
	local total = 0
	for i = 1, #list do total = total + list[i].totalAmount end
	for i = 1, math.min(#list, 12) do
		local s = list[i]
		local name = (s.spellID and s.spellID > 0 and C_Spell and C_Spell.GetSpellName(s.spellID)) or "Melee"
		if s.creatureName and s.creatureName ~= "" then
			name = name .. " (" .. s.creatureName .. ")"
		end
		local pct = total > 0 and (s.totalAmount / total * 100) or 0
		GameTooltip:AddDoubleLine(name, string.format("%s  %.0f%%", TM.Short(s.totalAmount), pct), 1, 1, 1, 1, 1, 1)
	end
	if #list > 12 then
		GameTooltip:AddLine(string.format("+%d more", #list - 12), 0.7, 0.7, 0.7)
	end
	GameTooltip:Show()
end

local function RowLeave()
	GameTooltip:Hide()
end

---------------------------------------------------------------------------
function TM:RefreshMeter(repos)
	if not win then return end
	TM:LayoutWindow(win, Cfg(), repos)
	for _, row in ipairs(win.rows) do
		if not row.tmHooked then
			row:SetScript("OnEnter", RowEnter)
			row:SetScript("OnLeave", RowLeave)
			row.tmHooked = true
		end
	end
	win:SetShown(Cfg().enabled)
	dirty = true
	SafeUpdate()
end

function TM:SetupMeter()
	win = TM:CreateWindow("meter", 300, -120)

	sessionBtn = CreateFrame("Button", nil, win.header)
	sessionBtn:SetPoint("TOPRIGHT")
	sessionBtn:SetPoint("BOTTOMRIGHT")
	sessionBtn:SetWidth(96)
	sessionBtn:SetFrameLevel(win.header:GetFrameLevel() + 2)
	sessionBtn.text = win.right
	win.right:SetParent(sessionBtn)
	sessionBtn:SetScript("OnClick", function()
		Cfg().overall = not Cfg().overall
		SafeUpdate()
	end)
	sessionBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Click: switch between this fight and overall")
		GameTooltip:Show()
	end)
	sessionBtn:SetScript("OnLeave", RowLeave)
	win.title:SetPoint("RIGHT", sessionBtn, "LEFT", -4, 0)

	win.header:SetScript("OnClick", function(_, button)
		if IsShiftKeyDown() then
			StaticPopup_Show("TITANMETER_RESET")
			return
		end
		local n = #TM.MODES
		local m = Cfg().mode + (button == "RightButton" and -1 or 1)
		if m > n then m = 1 elseif m < 1 then m = n end
		Cfg().mode = m
		SafeUpdate()
	end)
	win.header:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("TitanMeter")
		GameTooltip:AddLine("Left-click: next mode, right-click: previous", 1, 1, 1)
		GameTooltip:AddLine("Shift-click: clear all fights", 1, 1, 1)
		if not TM.db.locked then GameTooltip:AddLine("Drag to move (/tmeter lock when done)", 0.6, 0.8, 1) end
		GameTooltip:Show()
	end)
	win.header:SetScript("OnLeave", RowLeave)

	win:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
	win:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	win:RegisterEvent("DAMAGE_METER_RESET")
	win:RegisterEvent("PLAYER_REGEN_ENABLED")
	win:RegisterEvent("PLAYER_REGEN_DISABLED")
	win:SetScript("OnEvent", function() dirty = true end)
	-- Redraw at most 4 times a second; in combat redraw anyway so DPS and the timer tick.
	win:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 0.25 then return end
		local inCombat = InCombatLockdown()
		if dirty or (inCombat and elapsed >= 0.5) then
			elapsed, dirty = 0, false
			SafeUpdate()
		end
	end)

	self:RefreshMeter(true)
end
