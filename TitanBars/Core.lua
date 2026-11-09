-- TitanBars: core setup, saved settings, hiding the Blizzard bars, slash commands.
local ADDON, TB = ...
_G.TitanBars = TB

TB.NUM_BARS = 9
TB.STANCE_BAR = 9
TB.MAX_BUTTONS = 12

-- Which action slots each bar shows (page N = slots (N-1)*12+1 .. N*12) and which
-- Blizzard key binding it inherits on first load. Bar 1 also pages with stance/forms.
-- Bar 9 is the stance bar: it shows your forms instead of action slots.
TB.BAR_INFO = {
	{ page = 1,  binding = "ACTIONBUTTON",          label = "Main bar" },
	{ page = 6,  binding = "MULTIACTIONBAR1BUTTON", label = "Bottom left" },
	{ page = 5,  binding = "MULTIACTIONBAR2BUTTON", label = "Bottom right" },
	{ page = 3,  binding = "MULTIACTIONBAR3BUTTON", label = "Right" },
	{ page = 4,  binding = "MULTIACTIONBAR4BUTTON", label = "Right 2" },
	{ page = 13, binding = "MULTIACTIONBAR5BUTTON", label = "Bar 6" },
	{ page = 14, binding = "MULTIACTIONBAR6BUTTON", label = "Bar 7" },
	{ page = 15, binding = "MULTIACTIONBAR7BUTTON", label = "Bar 8" },
	{ stance = true, binding = "SHAPESHIFTBUTTON",  label = "Forms / stance" },
}

TB.DEFAULT_VISIBILITY = "[petbattle] hide; show"
local DEFAULT_VISIBILITY = TB.DEFAULT_VISIBILITY

local function BarDefaults(id)
	-- Bars 1-3 start stacked bottom-centre, 4-5 as columns on the right, 6-8 off,
	-- 9 (forms) above bar 3.
	-- pos (bar centre, in UIParent units from the bottom-left) is set on first layout.
	return {
		enabled = id <= 5 or id == TB.STANCE_BAR,
		buttons = id == TB.STANCE_BAR and 10 or 12,
		perRow = (id == 4 or id == 5) and 1 or 12,
		scale = 1,
		padding = 4,
		alpha = 1,
		visibility = DEFAULT_VISIBILITY,
	}
end

local function DeepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = DeepCopy(v) end
	return c
end
TB.DeepCopy = DeepCopy

local function NewProfile()
	local p = { hideBlizzard = true, hideExtraArt = true, bars = {}, keys = {}, extras = {}, keysImported = false }
	for id = 1, TB.NUM_BARS do p.bars[id] = BarDefaults(id) end
	return p
end

function TB:ResetBar(id)
	self.db.bars[id] = BarDefaults(id)
end

function TB:CharKey()
	return UnitName("player") .. " - " .. GetRealmName()
end

-- Settings are account-wide with one profile per character. A new character starts
-- from a copy of the last profile used, so your layout follows you to alts.
function TB:LoadDB()
	TitanBarsDB = TitanBarsDB or {}
	local sv = TitanBarsDB
	sv.profiles = sv.profiles or {}
	local key = self:CharKey()
	if not sv.profiles[key] then
		local last = sv.lastProfile and sv.profiles[sv.lastProfile]
		sv.profiles[key] = last and DeepCopy(last) or NewProfile()
	end
	sv.lastProfile = key
	self.db = sv.profiles[key]
	self:FillDefaults()
end

-- Profiles saved by older versions are missing newer settings.
function TB:FillDefaults()
	local db = self.db
	for id = 1, self.NUM_BARS do
		db.bars[id] = db.bars[id] or BarDefaults(id)
	end
	db.extras = db.extras or {}
	if db.hideExtraArt == nil then db.hideExtraArt = true end
end

function TB:CopyProfileFrom(name)
	local src = TitanBarsDB.profiles[name]
	if not src then
		self:Print("No profile named '" .. name .. "'. Use /tb profiles to list them.")
		return
	end
	TitanBarsDB.profiles[self:CharKey()] = DeepCopy(src)
	self.db = TitanBarsDB.profiles[self:CharKey()]
	self:FillDefaults()
	self:Print("Copied settings from " .. name .. ".")
	self:RunOutOfCombat("refreshAll", function()
		TB:RefreshAll()
		TB:ApplyExtras()
	end)
end

function TB:Print(msg)
	print("|cff33ccffTitanBars|r: " .. msg)
end

-- Anything touching secure frames must wait until combat ends.
local pending = {}
function TB:RunOutOfCombat(key, fn, silent)
	if InCombatLockdown() then
		if not pending[key] and not silent then
			self:Print("Change queued until combat ends.")
		end
		pending[key] = fn
	else
		fn()
	end
end

---------------------------------------------------------------------------
-- Hiding Blizzard's bars and their art
---------------------------------------------------------------------------
local hider = CreateFrame("Frame", "TitanBarsUIHider", UIParent)
hider:Hide()

local BLIZZARD_BARS = {
	"MainActionBar", "MainMenuBar", -- MainMenuBar is the pre-12.x name, kept as a fallback
	"MultiBarBottomLeft", "MultiBarBottomRight",
	"MultiBarLeft", "MultiBarRight",
	"MultiBar5", "MultiBar6", "MultiBar7",
}

function TB:HideBlizzard()
	for _, name in ipairs(BLIZZARD_BARS) do
		local bar = _G[name]
		if bar then
			-- Parenting to a hidden frame keeps the bar (and its gryphon/border art)
			-- invisible even when Blizzard code calls :Show() on it.
			bar:SetParent(hider)
		end
	end
	-- Blizzard's stance bar only goes when ours (bar 9) is on.
	if StanceBar and self.db.bars[self.STANCE_BAR].enabled then
		StanceBar:SetParent(hider)
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_BINDINGS")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")

events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		TB:LoadDB()
	elseif event == "PLAYER_LOGIN" then
		if TB.db.hideBlizzard then TB:HideBlizzard() end
		TB:CreateBars()
		TB:RefreshAll()
		TB:SetupExtras()
	elseif event == "PLAYER_ENTERING_WORLD" then
		TB:ImportBlizzardKeys()
		TB:ApplyBindings()
	elseif event == "UPDATE_BINDINGS" then
		-- Our own override bindings fire this too, so only re-apply after an import.
		if TB:ImportBlizzardKeys() then
			TB:ApplyBindings()
		elseif TB.bars[1] then
			TB:UpdateAllHotkeys()
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Movers and bind mode can't work in combat; close them cleanly.
		if TB.unlocked then TB:SetUnlocked(false) end
		if TB.bindMode then TB:SetBindMode(false) end
	elseif event == "PLAYER_REGEN_ENABLED" then
		for key, fn in pairs(pending) do
			pending[key] = nil
			fn()
		end
	end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local HELP = {
	"/tb  - open the settings window",
	"/tb unlock  - drag bars, bags and menu buttons to move them; mouse wheel to resize",
	"/tb lock  - lock bars in place",
	"/tb bind  - keybind mode: hover a button and press a key (Esc clears)",
	"/tb importkeys  - re-copy your Blizzard action bar keybinds onto the bars",
	"/tb profiles  - list saved character profiles",
	"/tb copy <Name - Realm>  - copy another character's layout and keys",
	"/tb reset  - reset every bar to defaults",
}

SLASH_TITANBARS1 = "/tb"
SLASH_TITANBARS2 = "/titanbars"
SlashCmdList.TITANBARS = function(msg)
	local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()
	if InCombatLockdown() and cmd ~= "help" and cmd ~= "profiles" then
		TB:Print("Can't change bars in combat.")
		return
	end
	if cmd == "" or cmd == "config" then
		TB:ToggleConfig()
	elseif cmd == "unlock" then
		TB:SetUnlocked(true)
	elseif cmd == "lock" then
		TB:SetUnlocked(false)
	elseif cmd == "bind" or cmd == "kb" then
		TB:SetBindMode(not TB.bindMode)
	elseif cmd == "importkeys" then
		TB:ImportBlizzardKeys(true)
		TB:ApplyBindings()
	elseif cmd == "profiles" then
		for name in pairs(TitanBarsDB.profiles) do TB:Print("  " .. name) end
	elseif cmd == "copy" and rest ~= "" then
		TB:CopyProfileFrom(rest)
	elseif cmd == "reset" then
		for id = 1, TB.NUM_BARS do TB:ResetBar(id) end
		wipe(TB.db.extras)
		TB:RefreshAll()
		TB:Print("All bars reset. Type /reload to put the bags and menu buttons back.")
	else
		for _, line in ipairs(HELP) do TB:Print(line) end
	end
end
