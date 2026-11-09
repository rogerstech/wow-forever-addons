-- TitanTools: colours enemy nameplates by who the mob is hitting. Green = on you,
-- red = on someone else. Mobs that aren't fighting keep Blizzard's colour.
--
-- Blizzard's nameplate code runs with secret combat values, so we never write to
-- its frames or call into it: each plate gets our own coloured fill laid over the
-- health bar's fill, so it still shrinks with the mob's health.
local ADDON, TT = ...

local ON_ME = CreateColor(0.15, 0.85, 0.2, 0.85)
local OFF_ME = CreateColor(1, 0.1, 0.1, 0.85)

local overlays = {} -- nameplate -> our overlay
local active = {}   -- nameplate unit token -> nameplate

local function HealthBar(plate)
	local uf = plate.UnitFrame
	return uf and uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar
end

local function GetOverlay(plate)
	local o = overlays[plate]
	if o then return o end
	local bar = HealthBar(plate)
	if not bar then return end
	o = CreateFrame("Frame", nil, plate)
	o:SetAllPoints(bar)
	o:SetFrameLevel(bar:GetFrameLevel() + 1)
	o.fill = o:CreateTexture(nil, "ARTWORK")
	o.fill:SetColorTexture(1, 1, 1, 1)
	local fill = bar:GetStatusBarTexture()
	o.fill:SetPoint("TOPLEFT", fill, "TOPLEFT")
	o.fill:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
	o:Hide()
	overlays[plate] = o
	return o
end

local function Update(unit, plate)
	local o = GetOverlay(plate)
	if not o then return end
	local cfg = TT.db.aggro
	local target = unit .. "target"
	local show = cfg.enabled and UnitCanAttack("player", unit) and UnitAffectingCombat(unit)
		and UnitExists(target) and (not cfg.groupOnly or IsInGroup())
	if not show then
		o:Hide()
		return
	end
	TT.ColorFromBoolean(o.fill, UnitIsUnit(target, "player"), ON_ME, OFF_ME)
	o:Show()
end

local function SafeUpdate(unit, plate)
	if not pcall(Update, unit, plate) and overlays[plate] then overlays[plate]:Hide() end
end

function TT:UpdateAggro()
	for unit, plate in pairs(active) do SafeUpdate(unit, plate) end
end

function TT:SetupAggro()
	local events = CreateFrame("Frame")
	events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	events:RegisterEvent("UNIT_TARGET")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:RegisterEvent("GROUP_ROSTER_UPDATE")
	events:SetScript("OnEvent", function(_, event, unit)
		if event == "NAME_PLATE_UNIT_ADDED" then
			local plate = C_NamePlate.GetNamePlateForUnit(unit)
			if plate then
				active[unit] = plate
				SafeUpdate(unit, plate)
			end
		elseif event == "NAME_PLATE_UNIT_REMOVED" then
			local plate = active[unit]
			active[unit] = nil
			if plate and overlays[plate] then overlays[plate]:Hide() end
		elseif event == "UNIT_TARGET" then
			if active[unit] then SafeUpdate(unit, active[unit]) end
		else
			TT:UpdateAggro()
		end
	end)
	-- Mobs swap targets without always telling us; check a few times a second too.
	C_Timer.NewTicker(0.2, function() TT:UpdateAggro() end)
end
