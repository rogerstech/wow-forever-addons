-- TitanMeter: threat on your target for you and your group (like Omen / Ellesmere's threat bars).
-- Uses UnitDetailedThreatSituation. If the game hides the numbers (secret values) we still draw
-- them, but we can't sort, so the list stays in group order.
local ADDON, TM = ...

local win
local dirty, elapsed, lastError = true, 0, nil
local AGGRO = CreateColor(0.85, 0.15, 0.15, 1)
local WARN = CreateColor(1, 0.55, 0.1, 1)
local YOU_NAME = CreateColor(1, 0.82, 0.25, 1)
local OTHER_NAME = CreateColor(1, 1, 1, 1)

local function Cfg() return TM.db.threat end

-- Unit checks can come back secret in combat; a secret answer counts as "yes, hostile".
local function Plain(v, ifSecret)
	if TM.IsSecret(v) then return ifSecret end
	return v
end

local function Hostile(unit)
	return Plain(UnitExists(unit), true) and Plain(UnitCanAttack("player", unit), true)
		and not Plain(UnitIsDead(unit), false)
end

-- The mob to read: your target, or (healers) your friendly target's target.
local function ThreatMob()
	if Hostile("target") then return "target" end
	if UnitExists("target") and Hostile("targettarget") then return "targettarget" end
	return nil
end

local function GroupUnits()
	local units = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
	else
		units[1] = "player"
		if IsInGroup() then
			for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
		end
	end
	if UnitExists("pet") then units[#units + 1] = "pet" end
	return units
end

local function HideRows(from)
	for i = from, #win.rows do win.rows[i]:Hide() end
end

local function Update()
	local cfg = Cfg()
	local mob = ThreatMob()
	local unlocked = not TM.db.locked
	local show = cfg.enabled and (unlocked or (mob and (cfg.show == "always" or InCombatLockdown())))
	win:SetShown(show and true or false)
	if not show then return end

	if not mob then
		win.title:SetText("Threat")
		win.right:SetText("")
		win.empty:SetText(unlocked and "No hostile target. Drag the title to move, the corner to resize." or "No hostile target.")
		return HideRows(1)
	end
	win.title:SetFormattedText("Threat: %s", UnitName(mob))

	local list, anySecret = {}, false
	for _, unit in ipairs(GroupUnits()) do
		local isTanking, _, scaled = UnitDetailedThreatSituation(unit, mob)
		if TM.IsSecret(scaled) or TM.IsSecret(isTanking) then
			anySecret = true
			list[#list + 1] = { unit = unit, tanking = isTanking, pct = scaled }
		elseif scaled ~= nil then
			list[#list + 1] = { unit = unit, tanking = isTanking, pct = scaled }
		end
	end
	if not anySecret then
		table.sort(list, function(a, b)
			if a.tanking ~= b.tanking then return a.tanking and true or false end
			return a.pct > b.pct
		end)
	end
	win.right:SetText("")

	if #list == 0 then
		win.empty:SetText("Nobody has threat yet.")
		return HideRows(1)
	end
	win.empty:SetText("")

	local shown = math.min(#list, cfg.rows)
	for r = 1, shown do
		local e = list[r]
		local row = TM:GetRow(win, r)
		row:SetMinMaxValues(0, 100)
		row:SetValue(e.pct)
		local _, class = UnitClass(e.unit)
		local classColor = TM.ClassColor(e.unit ~= "pet" and class or nil)
		local tex = row:GetStatusBarTexture()
		if not anySecret and not e.tanking and e.pct >= 80 then
			tex:SetVertexColor(WARN:GetRGB())
		else
			TM.ColorFromBoolean(tex, e.tanking, AGGRO, classColor)
		end
		row.name:SetText((UnitName(e.unit)))
		local isMe = e.unit == "player" or Plain(UnitIsUnit(e.unit, "player"), false)
		row.name:SetTextColor((isMe and YOU_NAME or OTHER_NAME):GetRGB())
		row.value:SetFormattedText("%.0f%%", e.pct)
		row:Show()
	end
	HideRows(shown + 1)
end

local function SafeUpdate()
	if not win then return end
	local ok, err = pcall(Update)
	if not ok then
		win.empty:SetText("Threat error - see chat.")
		HideRows(1)
		if err ~= lastError then
			lastError = err
			TM:Print("threat meter error (please send this to Adam): " .. tostring(err))
		end
	end
end

function TM:RefreshThreat(repos)
	if not win then return end
	TM:LayoutWindow(win, Cfg(), repos)
	for _, row in ipairs(win.rows) do row:EnableMouse(false) end
	dirty = true
	SafeUpdate()
end

function TM:SetupThreat()
	win = TM:CreateWindow("threat", 300, 80)
	win.header:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("TitanMeter threat")
		GameTooltip:AddLine("100% = has aggro. Others: how close they are to pulling it.", 1, 1, 1, true)
		GameTooltip:AddLine("Red bar = has aggro, orange = 80% or more.", 1, 1, 1, true)
		if not TM.db.locked then GameTooltip:AddLine("Drag to move, corner to resize (/tmeter lock when done)", 0.6, 0.8, 1) end
		GameTooltip:Show()
	end)
	win.header:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- A separate always-shown driver, because the window hides itself out of combat.
	local driver = CreateFrame("Frame")
	for _, e in ipairs({ "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_TARGET_CHANGED",
		"GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_PET", "UNIT_TARGET" }) do
		driver:RegisterEvent(e)
	end
	driver:SetScript("OnEvent", function() dirty = true end)
	driver:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 0.2 then return end
		if dirty or (InCombatLockdown() and elapsed >= 0.4) then
			elapsed, dirty = 0, false
			SafeUpdate()
		end
	end)

	self:RefreshThreat(true)
end
