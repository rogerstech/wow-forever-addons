-- TitanMeter: saved settings, slash commands and shared helpers.
--
-- Where the numbers come from: Forever ships Blizzard's own damage meter (C_DamageMeter).
-- The game does the counting; this addon only draws it. In combat the game hands addons
-- "secret" values: we can put them in a bar or a text, but plain Lua can't do maths on them,
-- compare them or sort them. Everything here is written around that rule.
local ADDON, TM = ...
_G.TitanMeter = TM

local DEFAULTS = {
	locked = false,
	hideBlizzard = true,
	meter = {
		enabled = true,
		mode = 1,          -- index into TM.MODES
		overall = false,   -- false = current fight, true = overall
		rows = 8,
		width = 240,
		rowHeight = 18,
		scale = 1,
		alpha = 0.6,
	},
	threat = {
		enabled = true,
		show = "combat",   -- "combat" or "always"
		rows = 6,
		width = 220,
		rowHeight = 16,
		scale = 1,
		alpha = 0.6,
	},
	pos = {},
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
	print("|cff33ccffTitanMeter|r: " .. msg)
end

function TM.IsSecret(v)
	return issecretvalue and issecretvalue(v) or false
end

-- Colour a texture from a boolean that may be secret.
function TM.ColorFromBoolean(tex, flag, yes, no)
	if tex.SetVertexColorFromBoolean then
		tex:SetVertexColorFromBoolean(flag, yes, no)
	elseif not TM.IsSecret(flag) then
		tex:SetVertexColor((flag and yes or no):GetRGBA())
	end
end

function TM.ClassColor(class)
	if TM.IsSecret(class) then return CreateColor(0.55, 0.55, 0.6, 1) end
	local c = class and class ~= "" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return CreateColor(c.r, c.g, c.b, 1) end
	return CreateColor(0.55, 0.55, 0.6, 1)
end

-- Number formatting that works on secret numbers (the game's formatter accepts them).
-- Never test a possibly-secret value with `if`, `or`, `==` or `<`: that errors in combat.
function TM.Short(n)
	if AbbreviateNumbers then return AbbreviateNumbers(n) end
	if TM.IsSecret(n) then return "?" end
	return tostring(math.floor(n + 0.5))
end

---------------------------------------------------------------------------
-- Blizzard's own meter window: the game only fills C_DamageMeter while its meter is
-- switched on, so we keep the setting on and just hide Blizzard's window.
local blizzHooked = false

local function HideBlizzardNow()
	if DamageMeter and TM.db.hideBlizzard then
		DamageMeter:Hide()
	end
end

function TM:ApplyBlizzard()
	if C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("damageMeterEnabled") ~= nil then
		if C_CVar.GetCVar("damageMeterEnabled") ~= "1" then
			C_CVar.SetCVar("damageMeterEnabled", "1")
		end
	end
	if not DamageMeter then return end
	if not blizzHooked and DamageMeter.UpdateShownState then
		hooksecurefunc(DamageMeter, "UpdateShownState", HideBlizzardNow)
		blizzHooked = true
	end
	if self.db.hideBlizzard then
		HideBlizzardNow()
	elseif DamageMeter.UpdateShownState then
		DamageMeter:UpdateShownState()
	end
end

---------------------------------------------------------------------------
local function Help()
	TM:Print("commands:")
	print("  /tmeter lock | unlock - lock windows, or unlock to drag them by the title")
	print("  /tmeter reset - clear all fights")
	print("  /tmeter meter on|off, /tmeter threat on|off - show or hide each window")
	print("  /tmeter threat always|combat - threat window always, or only in combat")
	print("  /tmeter rows N, /tmeter width N, /tmeter scale N - damage meter size")
	print("  /tmeter threatrows N, /tmeter threatwidth N, /tmeter threatscale N - threat window size")
	print("  /tmeter blizzard show|hide - show or hide Blizzard's own meter window")
	print("  /tmeter resetpos - put both windows back to the middle of the screen")
	print("Damage meter: left-click the title for the next mode, right-click for the previous,")
	print("click Current/Overall to switch, hover a bar (out of combat) for its spells.")
end

local function Num(v, lo, hi)
	v = tonumber(v)
	if not v then return nil end
	return math.max(lo, math.min(hi, v))
end

SLASH_TITANMETER1 = "/tmeter"
SLASH_TITANMETER2 = "/titanmeter"
SlashCmdList.TITANMETER = function(msg)
	local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	local db = TM.db
	if cmd == "lock" or cmd == "unlock" then
		db.locked = (cmd == "lock")
		TM:Print(db.locked and "locked." or "unlocked: drag the window titles to move them.")
		TM:RefreshAll()
	elseif cmd == "reset" then
		StaticPopup_Show("TITANMETER_RESET")
	elseif cmd == "meter" and (arg == "on" or arg == "off") then
		db.meter.enabled = (arg == "on")
		TM:RefreshAll()
	elseif cmd == "threat" and (arg == "on" or arg == "off") then
		db.threat.enabled = (arg == "on")
		TM:RefreshAll()
	elseif cmd == "threat" and (arg == "always" or arg == "combat") then
		db.threat.show = arg
		TM:RefreshAll()
	elseif cmd == "rows" and Num(arg, 1, 40) then
		db.meter.rows = Num(arg, 1, 40); TM:RefreshAll()
	elseif cmd == "width" and Num(arg, 120, 600) then
		db.meter.width = Num(arg, 120, 600); TM:RefreshAll()
	elseif cmd == "scale" and Num(arg, 0.5, 2) then
		db.meter.scale = Num(arg, 0.5, 2); TM:RefreshAll()
	elseif cmd == "threatrows" and Num(arg, 1, 40) then
		db.threat.rows = Num(arg, 1, 40); TM:RefreshAll()
	elseif cmd == "threatwidth" and Num(arg, 120, 600) then
		db.threat.width = Num(arg, 120, 600); TM:RefreshAll()
	elseif cmd == "threatscale" and Num(arg, 0.5, 2) then
		db.threat.scale = Num(arg, 0.5, 2); TM:RefreshAll()
	elseif cmd == "blizzard" and (arg == "show" or arg == "hide") then
		db.hideBlizzard = (arg == "hide")
		TM:ApplyBlizzard()
		TM:Print("Blizzard's meter window " .. (db.hideBlizzard and "hidden." or "shown (Edit Mode controls where it sits)."))
	elseif cmd == "resetpos" then
		wipe(db.pos)
		TM:RefreshAll(true)
	else
		Help()
	end
end

StaticPopupDialogs["TITANMETER_RESET"] = {
	text = "Clear all damage meter fights?",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then
			C_DamageMeter.ResetAllCombatSessions()
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

function TM:RefreshAll(repos)
	if self.RefreshMeter then self:RefreshMeter(repos) end
	if self.RefreshThreat then self:RefreshThreat(repos) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == ADDON then
		TitanMeterDB = TitanMeterDB or {}
		Merge(TitanMeterDB, DEFAULTS)
		TM.db = TitanMeterDB
	elseif event == "ADDON_LOADED" and name == "Blizzard_DamageMeter" and TM.db then
		TM:ApplyBlizzard()
	elseif event == "PLAYER_LOGIN" then
		TM:ApplyBlizzard()
		if TM.SetupMeter then TM:SetupMeter() end
		if TM.SetupThreat then TM:SetupThreat() end
	end
end)
