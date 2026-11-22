-- TitanUI: the window. Addons (and their pages) on the left, the chosen page on the right.
--
-- Each Pages\<Addon>.lua file registers one addon. An addon only appears in the tree when
-- it is installed, turned on and loaded; the Overview page lists the rest.
local ADDON, UI = ...

BINDING_HEADER_TITANUI = "TitanUI"
BINDING_NAME_TITANUI_TOGGLE = "Open / close TitanUI settings"

local W, H = 780, 560
local TREE_W, ROW_H, TITLE_H = 200, 22, 30

UI.addons = {}

function UI:Print(msg)
	print("|cff33ccffTitanUI|r: " .. msg)
end

function UI:Error(err)
	self:Print("|cffff5555error:|r " .. tostring(err))
end

-- def = { name = "TitanBars", global = "TitanBars", summary = "...",
--         ready = function(ns) -> bool, pages = { { key, label, build(page, ns), noCombat }, ... } }
function UI:Register(def)
	def.order = #self.addons + 1
	table.insert(self.addons, def)
end

local function IsLoaded(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
	return IsAddOnLoaded and IsAddOnLoaded(name)
end

local function Metadata(name, field)
	if C_AddOns and C_AddOns.GetAddOnMetadata then return C_AddOns.GetAddOnMetadata(name, field) end
	return GetAddOnMetadata and GetAddOnMetadata(name, field)
end

function UI:AddonState(def)
	if not IsLoaded(def.name) then
		local exists = C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist(def.name)
		return exists and "off" or "missing"
	end
	local ns = _G[def.global]
	if not ns or (def.ready and not def.ready(ns)) then return "loading" end
	return "ready", ns
end

function UI:Version(name)
	return Metadata(name, "Version") or "?"
end

---------------------------------------------------------------------------
local win, tree, scroll, bar
local rows = {}
local built = {}       -- "addon/page" -> page object
local current          -- page object on show
local selected         -- "addon/page"
local treeOffset = 0

local function Backdrop(f, r, g, b, a, br, bg, bb, ba)
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	f:SetBackdropColor(r, g, b, a)
	f:SetBackdropBorderColor(br or 0, bg or 0, bb or 0, ba or 1)
end

-- The tree as a flat list of visible rows.
local function TreeItems()
	local items = { { id = "overview", label = "Overview", depth = 0 } }
	for _, def in ipairs(UI.addons) do
		if UI:AddonState(def) == "ready" then
			local many = #def.pages > 1
			local open = UI.db.expanded[def.name]
			table.insert(items, {
				id = def.name .. "/" .. def.pages[1].key, addon = def, label = def.name, depth = 0,
				expandable = many, open = open,
			})
			if many and open then
				for _, pg in ipairs(def.pages) do
					table.insert(items, { id = def.name .. "/" .. pg.key, addon = def, label = pg.label, depth = 1 })
				end
			end
		end
	end
	return items
end

local function FindPage(id)
	local addonName, key = id:match("^(.-)/(.*)$")
	for _, def in ipairs(UI.addons) do
		if def.name == addonName then
			for _, pg in ipairs(def.pages) do
				if pg.key == key then return def, pg end
			end
		end
	end
end

local function UpdateScrollBar()
	if not current then return end
	local viewH = scroll:GetHeight()
	local range = math.max(0, current.frame:GetHeight() - viewH)
	bar:SetMinMaxValues(0, range)
	bar:SetValue(math.min(bar:GetValue(), range))
	bar:SetShown(range > 0)
	scroll:SetVerticalScroll(bar:GetValue())
end

---------------------------------------------------------------------------
-- Overview page: what's installed.
local function BuildOverview(p)
	p:Title("TitanUI", "Settings for all your Titan addons in one place. Pick an addon on the left; addons with "
		.. "more than one page open up to show them. Changes apply straight away.")
	p:Header("Your addons")
	for _, def in ipairs(UI.addons) do
		p:Note(function()
			local state = UI:AddonState(def)
			local line = "|cffffd200" .. def.name .. "|r  "
			if state == "ready" then
				line = line .. "|cff4fd15fon|r  v" .. UI:Version(def.name)
			elseif state == "off" then
				line = line .. "|cff8a8a96installed but turned off (character select > Menu > AddOns)|r"
			elseif state == "missing" then
				line = line .. "|cff8a8a96not installed|r"
			else
				line = line .. "|cffffcc00still loading|r"
			end
			return line .. "\n|cffb0b0b8" .. (def.summary or "") .. "|r"
		end)
	end
	p:Header("Opening this window")
	p:Note("/tui  or  /titanui. You can also bind a key: Esc > Options > Keybindings > AddOns > TitanUI, "
		.. "or use Esc > Options > AddOns > TitanUI.")
	p:Note("Each addon's own command (/tb, /tf, /ttools, ...) still opens its old window too.")
	p:Buttons({
		{ "Reload UI", function() ReloadUI() end, "Some settings (marked \"needs /reload\") only take effect after this." },
	})
end

---------------------------------------------------------------------------
function UI:Select(id)
	if not win then return end
	local def, pg
	if id ~= "overview" then
		def, pg = FindPage(id)
		if not def or self:AddonState(def) ~= "ready" then id = "overview" end
	end
	if current then current.frame:Hide() end
	selected = id
	self.db.last = id

	local p = built[id]
	if not p then
		p = UI:NewPage(scroll)
		p.noCombat = pg and pg.noCombat
		local ok, err
		if id == "overview" then
			ok, err = pcall(BuildOverview, p)
		else
			local _, ns = self:AddonState(def)
			if #def.pages > 1 then
				p:Title(def.name .. "  |cff8a8a96>  " .. pg.label .. "|r")
			else
				p:Title(def.name)
			end
			ok, err = pcall(pg.build, p, ns)
		end
		if not ok then
			p:Note("|cffff5555This page hit an error:|r " .. tostring(err))
		end
		p:Finish()
		built[id] = p
	end
	current = p
	scroll:SetScrollChild(p.frame)
	p.frame:Show()
	bar:SetValue(0)
	p:Refresh()
	UpdateScrollBar()

	win.path:SetText(id == "overview" and "Overview" or (def.name .. (#def.pages > 1 and ("  >  " .. pg.label) or "")))
	self:RefreshTree()
end

function UI:RefreshTree()
	if not win then return end
	local items = TreeItems()
	local visible = math.floor((tree:GetHeight() - 8) / ROW_H)
	treeOffset = math.max(0, math.min(treeOffset, #items - visible))
	for i = 1, math.max(#rows, visible) do
		local row = rows[i]
		if not row and i <= visible then
			row = CreateFrame("Button", nil, tree)
			row:SetHeight(ROW_H)
			row:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_H)
			row:SetPoint("RIGHT", -4, 0)
			row.sel = row:CreateTexture(nil, "BACKGROUND")
			row.sel:SetAllPoints()
			row.sel:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.25)
			row.mark = row:CreateTexture(nil, "ARTWORK")
			row.mark:SetPoint("TOPLEFT")
			row.mark:SetPoint("BOTTOMLEFT")
			row.mark:SetWidth(3)
			row.mark:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 1)
			row.hl = row:CreateTexture(nil, "HIGHLIGHT")
			row.hl:SetAllPoints()
			row.hl:SetColorTexture(1, 1, 1, 0.07)
			row.arrow = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			row.arrow:SetPoint("LEFT", 8, 0)
			row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			row.text:SetJustifyH("LEFT")
			row:SetScript("OnClick", function(self)
				local it = self.item
				if not it then return end
				if it.expandable then
					-- Clicking an addon with pages opens it on its first page; clicking it again
					-- while one of its pages is shown folds it away.
					local n = it.addon.name
					local mine = selected and selected:sub(1, #n + 1) == n .. "/"
					if UI.db.expanded[n] and mine then
						UI.db.expanded[n] = false
						UI:RefreshTree()
						return
					end
					UI.db.expanded[n] = true
				end
				UI:Select(it.id)
			end)
			rows[i] = row
		end
		if row then
			local it = (i <= visible) and items[i + treeOffset]
			row.item = it
			row:SetShown(it ~= nil)
			if it then
				-- An open addon's own row isn't highlighted; the page row under it is.
				local isSel = (it.id == selected) and not (it.expandable and it.open)
				row.sel:SetShown(isSel)
				row.mark:SetShown(isSel)
				row.arrow:SetText(it.expandable and (it.open and "-" or "+") or "")
				row.text:ClearAllPoints()
				row.text:SetPoint("LEFT", 22 + it.depth * 14, 0)
				row.text:SetPoint("RIGHT", -4, 0)
				row.text:SetText(it.label)
				if it.depth == 0 then
					row.text:SetFontObject(it.id == "overview" and "GameFontHighlight" or "GameFontNormal")
				else
					row.text:SetFontObject("GameFontHighlightSmall")
				end
			end
		end
	end
end

---------------------------------------------------------------------------
local function SavePos()
	local s = win:GetEffectiveScale()
	UI.db.pos = { x = win:GetLeft() * s, y = win:GetTop() * s }
end

local function PlaceWindow()
	win:ClearAllPoints()
	local p = UI.db.pos
	if p then
		local s = win:GetEffectiveScale()
		win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x / s, p.y / s)
	else
		win:SetPoint("CENTER")
	end
end

local function Build()
	win = CreateFrame("Frame", "TitanUIFrame", UIParent, "BackdropTemplate")
	win:SetSize(W, H)
	win:SetFrameStrata("HIGH")
	win:SetToplevel(true)
	win:SetMovable(true)
	win:SetClampedToScreen(true)
	win:EnableMouse(true)
	Backdrop(win, 0.05, 0.05, 0.07, 0.96)
	tinsert(UISpecialFrames, "TitanUIFrame")
	win:Hide()

	local title = CreateFrame("Frame", nil, win, "BackdropTemplate")
	title:SetPoint("TOPLEFT", 1, -1)
	title:SetPoint("TOPRIGHT", -1, -1)
	title:SetHeight(TITLE_H)
	Backdrop(title, 0.1, 0.1, 0.13, 1, 0, 0, 0, 0)
	title:EnableMouse(true)
	title:RegisterForDrag("LeftButton")
	title:SetScript("OnDragStart", function() win:StartMoving() end)
	title:SetScript("OnDragStop", function()
		win:StopMovingOrSizing()
		SavePos()
	end)
	local accent = title:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("BOTTOMLEFT")
	accent:SetPoint("BOTTOMRIGHT")
	accent:SetHeight(1)
	accent:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.8)
	local name = title:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	name:SetPoint("LEFT", 12, 0)
	name:SetText("TitanUI")
	win.path = title:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.path:SetPoint("LEFT", name, "RIGHT", 14, -1)
	win.path:SetTextColor(0.7, 0.7, 0.75)
	local close = CreateFrame("Button", nil, title, "UIPanelCloseButton")
	close:SetSize(24, 24)
	close:SetPoint("RIGHT", -3, 0)
	close:SetScript("OnClick", function() win:Hide() end)

	tree = CreateFrame("Frame", nil, win, "BackdropTemplate")
	tree:SetPoint("TOPLEFT", 1, -TITLE_H - 1)
	tree:SetPoint("BOTTOMLEFT", 1, 1)
	tree:SetWidth(TREE_W)
	Backdrop(tree, 0.08, 0.08, 0.1, 1, 0, 0, 0, 0)
	local divider = tree:CreateTexture(nil, "ARTWORK")
	divider:SetPoint("TOPRIGHT")
	divider:SetPoint("BOTTOMRIGHT")
	divider:SetWidth(1)
	divider:SetColorTexture(0, 0, 0, 1)
	tree:EnableMouseWheel(true)
	tree:SetScript("OnMouseWheel", function(_, delta)
		treeOffset = treeOffset - delta * 2
		UI:RefreshTree()
	end)

	scroll = CreateFrame("ScrollFrame", nil, win)
	scroll:SetPoint("TOPLEFT", TREE_W + 8, -TITLE_H - 6)
	scroll:SetPoint("BOTTOMRIGHT", -20, 8)
	scroll:EnableMouseWheel(true)

	bar = CreateFrame("Slider", nil, win, "BackdropTemplate")
	bar:SetPoint("TOPRIGHT", -6, -TITLE_H - 8)
	bar:SetPoint("BOTTOMRIGHT", -6, 10)
	bar:SetWidth(8)
	bar:SetOrientation("VERTICAL")
	bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
	bar:SetBackdropColor(0, 0, 0, 0.5)
	bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
	bar:GetThumbTexture():SetVertexColor(0.6, 0.6, 0.65, 0.9)
	bar:GetThumbTexture():SetSize(8, 40)
	bar:SetValueStep(1)
	bar:SetMinMaxValues(0, 0)
	bar:SetScript("OnValueChanged", function(_, v) scroll:SetVerticalScroll(v) end)
	scroll:SetScript("OnMouseWheel", function(_, delta) bar:SetValue(bar:GetValue() - delta * 50) end)

	win:SetScript("OnShow", function()
		PlaceWindow()
		UI:Select(selected or UI.db.last or "overview")
	end)
	PlaceWindow()
end

function UI:Open(addonName, pageKey)
	if not win then Build() end
	if addonName then
		for _, def in ipairs(self.addons) do
			if def.name == addonName then
				local key = pageKey or def.pages[1].key
				self.db.expanded[def.name] = true
				selected = def.name .. "/" .. key
			end
		end
	end
	if win:IsShown() then
		self:Select(selected or "overview")
	else
		win:Show()
	end
end

function UI:Toggle()
	if win and win:IsShown() then win:Hide() else self:Open() end
end

---------------------------------------------------------------------------
SLASH_TITANUI1 = "/tui"
SLASH_TITANUI2 = "/titanui"
SlashCmdList.TITANUI = function(msg)
	msg = strtrim(msg or "")
	if msg == "" then
		UI:Toggle()
		return
	end
	-- /tui bars, /tui titanbars ...: jump straight to an addon.
	local want = msg:lower()
	for _, def in ipairs(UI.addons) do
		local n = def.name:lower()
		if n == want or n == "titan" .. want then
			UI:Open(def.name)
			return
		end
	end
	UI:Print("/tui opens the settings window. /tui <addon> (e.g. /tui bars) jumps to one addon.")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, _, name)
	if name ~= ADDON then return end
	TitanUIDB = TitanUIDB or {}
	TitanUIDB.expanded = TitanUIDB.expanded or {}
	UI.db = TitanUIDB

	-- Esc > Options > AddOns > TitanUI
	if Settings and Settings.RegisterCanvasLayoutCategory then
		local panel = CreateFrame("Frame")
		local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		open:SetSize(200, 26)
		open:SetPoint("TOPLEFT", 16, -16)
		open:SetText("Open TitanUI settings")
		open:SetScript("OnClick", function()
			if SettingsPanel then HideUIPanel(SettingsPanel) end
			UI:Open()
		end)
		local category = Settings.RegisterCanvasLayoutCategory(panel, "TitanUI")
		Settings.RegisterAddOnCategory(category)
	end
end)
