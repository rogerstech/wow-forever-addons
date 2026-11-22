-- TitanBags: saved settings, slash commands, and hiding Blizzard's bag windows.
--
-- How the hiding works: Blizzard's bag code still opens and closes its bags exactly as
-- before (B key, backpack button, vendors, mail, bank). We only move the bag windows
-- into an invisible parent, so they stay "open" as far as the game knows but you never
-- see them. Our window shows whenever any of your bags is open and closes them when you
-- close it. Nothing Blizzard does is replaced, so bag keys and auto-open keep working.
local ADDON, TB = ...
_G.TitanBags = TB

local DEFAULTS = {
	hideBlizzard = true,
	view = "bag",       -- bag | quality | type | name | ilvl
	columns = 12,
	scale = 1,
	locked = false,
	showKeys = true,
	pos = nil,          -- { point, relPoint, x, y }
}

TB.VIEWS = {
	{ key = "bag",     label = "Bag order (as the items really sit)" },
	{ key = "quality", label = "Quality (best first)" },
	{ key = "type",    label = "Type (consumables, quest, gear, trade goods...)" },
	{ key = "name",    label = "Name (A to Z)" },
	{ key = "ilvl",    label = "Item level (highest first)" },
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

function TB:Print(msg)
	print("|cff33ccffTitanBags|r: " .. msg)
end

---------------------------------------------------------------------------
-- Which bags we own: backpack + equipped bags (+ reagent bag if the game has one),
-- and the keyring when it exists and is turned on.
function TB:KeyringID()
	local id = (Enum and Enum.BagIndex and Enum.BagIndex.Keyring) or KEYRING_CONTAINER
	if not id then return nil end
	if C_ActionBar and C_ActionBar.ShouldShowKeyring and not C_ActionBar.ShouldShowKeyring() then
		return nil
	end
	return id
end

function TB:LastBagID()
	return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_FRAMES
		or (Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots) or 4
end

function TB:IsOurBag(id)
	if type(id) ~= "number" then return false end
	if id >= 0 and id <= self:LastBagID() then return true end
	return self.db.showKeys and id == self:KeyringID()
end

function TB:AnyOurBagOpen()
	if not IsBagOpen then return false end
	for id = 0, self:LastBagID() do
		if IsBagOpen(id) then return true end
	end
	local key = self.db.showKeys and self:KeyringID()
	return key and IsBagOpen(key) and true or false
end

---------------------------------------------------------------------------
local hidden = CreateFrame("Frame")
hidden:Hide()
TB.hiddenParent = hidden

local homeParent = {}   -- Blizzard frame -> its real parent
local hookedFrames = {}

local function Reparent(frame, hide)
	if not frame then return end
	if InCombatLockdown() and frame:IsProtected() then
		TB.pendingBlizzard = true
		return
	end
	if hide then
		if frame:GetParent() ~= hidden then
			homeParent[frame] = homeParent[frame] or frame:GetParent()
			frame:SetParent(hidden)
		end
	elseif frame:GetParent() == hidden then
		frame:SetParent(homeParent[frame] or ContainerFrameContainer or UIParent)
	end
end

-- Decide where one Blizzard bag window belongs right now.
local function PlaceBlizzardFrame(frame)
	if not frame then return end
	local hide = false
	if TB.db.hideBlizzard then
		if frame == ContainerFrameCombinedBags then
			hide = true
		elseif frame.GetBagID then
			hide = TB:IsOurBag(frame:GetBagID())
		end
	end
	Reparent(frame, hide)
end

local function QueueSync()
	if TB.syncQueued then return end
	TB.syncQueued = true
	C_Timer.After(0, function()
		TB.syncQueued = false
		TB:Sync()
	end)
end
TB.QueueSync = QueueSync

local function HookFrame(frame)
	if not frame or hookedFrames[frame] then return end
	hookedFrames[frame] = true
	hooksecurefunc(frame, "Show", QueueSync)
	hooksecurefunc(frame, "Hide", QueueSync)
	hooksecurefunc(frame, "SetShown", QueueSync)
end

local function AllBlizzardFrames()
	local list = {}
	if ContainerFrameCombinedBags then table.insert(list, ContainerFrameCombinedBags) end
	if ContainerFrameContainer and ContainerFrameContainer.ContainerFrames then
		for _, f in ipairs(ContainerFrameContainer.ContainerFrames) do table.insert(list, f) end
	end
	return list
end

function TB:ApplyBlizzard()
	self.pendingBlizzard = false
	for _, f in ipairs(AllBlizzardFrames()) do
		HookFrame(f)
		PlaceBlizzardFrame(f)
	end
end

local globalsHooked = false
function TB:HookBlizzard()
	if globalsHooked or not ContainerFrame_GenerateFrame then return end
	globalsHooked = true
	-- Every time Blizzard fills a bag window with a bag, re-decide where that window lives
	-- (the same window is reused for different bags).
	hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
		HookFrame(frame)
		PlaceBlizzardFrame(frame)
		QueueSync()
	end)
	for _, name in ipairs({ "OpenBag", "CloseBag", "ToggleBag", "OpenBackpack", "CloseBackpack",
		"ToggleBackpack", "OpenAllBags", "CloseAllBags", "ToggleAllBags" }) do
		if type(_G[name]) == "function" then hooksecurefunc(name, QueueSync) end
	end
	self:ApplyBlizzard()
end

---------------------------------------------------------------------------
local function Help()
	TB:Print("commands:")
	print("  /tbags - open or close your bags")
	print("  /tbags sort - tidy your bags (moves items, same as Blizzard's sort button)")
	print("  /tbags view bag|quality|type|name|ilvl - how items are shown in the window")
	print("  /tbags columns N - slots per row (6-30)")
	print("  /tbags scale N - window size (0.5-2)")
	print("  /tbags lock | unlock - stop or allow dragging the window")
	print("  /tbags keys on|off - show the keyring in the window")
	print("  /tbags blizzard show|hide - use Blizzard's bag windows again, or hide them")
	print("  /tbags reset - put the window back in the bottom-right corner")
	print("Drag the title bar to move. Right-click the title bar for all options.")
end

local function Num(v, lo, hi)
	v = tonumber(v)
	if not v then return nil end
	return math.max(lo, math.min(hi, v))
end

SLASH_TITANBAGS1 = "/tbags"
SLASH_TITANBAGS2 = "/titanbags"
SlashCmdList.TITANBAGS = function(msg)
	local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	local db = TB.db
	if cmd == "" or cmd == "show" or cmd == "toggle" then
		ToggleAllBags()
	elseif cmd == "sort" then
		TB:SortBags()
	elseif cmd == "view" then
		for _, v in ipairs(TB.VIEWS) do
			if v.key == arg then
				TB:SetView(arg)
				return
			end
		end
		TB:Print("views: bag, quality, type, name, ilvl")
	elseif cmd == "columns" and Num(arg, 6, 30) then
		db.columns = math.floor(Num(arg, 6, 30)); TB:Layout()
	elseif cmd == "scale" and Num(arg, 0.5, 2) then
		db.scale = Num(arg, 0.5, 2); TB:Layout()
	elseif cmd == "lock" or cmd == "unlock" then
		db.locked = (cmd == "lock")
		TB:Print(db.locked and "window locked." or "window unlocked: drag the title bar to move it.")
	elseif cmd == "keys" and (arg == "on" or arg == "off") then
		db.showKeys = (arg == "on")
		TB:ApplyBlizzard(); TB:Layout(); TB:Sync()
	elseif cmd == "blizzard" and (arg == "show" or arg == "hide") then
		db.hideBlizzard = (arg == "hide")
		TB:ApplyBlizzard(); TB:Sync()
		TB:Print(db.hideBlizzard and "Blizzard's bag windows hidden." or "Blizzard's bag windows back (TitanBags window is off while they show).")
	elseif cmd == "reset" then
		db.pos = nil
		TB:PlaceWindow()
	else
		Help()
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == ADDON then
		TitanBagsDB = TitanBagsDB or {}
		Merge(TitanBagsDB, DEFAULTS)
		TB.db = TitanBagsDB
	elseif event == "ADDON_LOADED" and TB.db and not globalsHooked then
		TB:HookBlizzard()
	elseif event == "PLAYER_LOGIN" then
		TB:CreateWindow()
		TB:HookBlizzard()
		TB:Sync()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if TB.pendingBlizzard then TB:ApplyBlizzard() end
		if TB.pendingLayout then TB:Layout() end
	end
end)
