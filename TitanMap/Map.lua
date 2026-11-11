-- TitanMap: the overlay. The zone map is drawn from the same tiles Blizzard's world map
-- uses, faded so you can see the game through it. Nothing on it takes the mouse, so
-- clicks go straight through to the world. Your arrow, quest markers and the shaded
-- quest areas sit on top at their own opacity.
local ADDON, TM = ...

local frame, canvas, pins, blob, arrow, box
local tiles, markers = {}, {}
local layerW, layerH = 1002, 668
local W, H = 520, 347 -- overlay size, set by ApplyLayout

---------------------------------------------------------------------------
-- Map picture
---------------------------------------------------------------------------
function TM:DrawMap()
	for _, t in ipairs(tiles) do t:Hide() end
	self.hasArt = false
	local layers = self.mapID and C_Map.GetMapArtLayers(self.mapID)
	local info = layers and layers[1]
	if not info then return end
	layerW, layerH = info.layerWidth, info.layerHeight
	canvas:SetSize(layerW, layerH)
	local cols = math.ceil(info.layerWidth / info.tileWidth)
	local rows = math.ceil(info.layerHeight / info.tileHeight)
	local textures = C_Map.GetMapArtLayerTextures(self.mapID, 1) or {}
	local n = 0
	for row = 1, rows do
		for col = 1, cols do
			n = n + 1
			local t = tiles[n]
			if not t then
				t = canvas:CreateTexture(nil, "BACKGROUND")
				tiles[n] = t
			end
			t:SetTexture(textures[(row - 1) * cols + col], nil, nil, "TRILINEAR")
			t:SetSize(info.tileWidth, info.tileHeight)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", canvas, "TOPLEFT", (col - 1) * info.tileWidth, -(row - 1) * info.tileHeight)
			t:SetAlpha(self.db.mapAlpha)
			t:Show()
		end
	end
	self.hasArt = true
	if blob then blob:SetMapID(self.mapID) end
end

-- Follows you from zone to zone (and into cities that have their own map).
function TM:CheckMap()
	if not frame then return end
	local id = C_Map.GetBestMapForUnit("player")
	if id ~= self.mapID then
		self.mapID = id
		self:DrawMap()
		self:ApplyLayout()
		self:UpdateVisibility()
	end
	self:RefreshQuests()
end

---------------------------------------------------------------------------
-- Quest markers and areas
---------------------------------------------------------------------------
local DOT = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function AcquireMarker(i)
	local m = markers[i]
	if not m then
		m = CreateFrame("Frame", nil, pins)
		m:SetSize(12, 12)
		m:EnableMouse(false)
		m.ring = m:CreateTexture(nil, "ARTWORK", nil, 1)
		m.ring:SetTexture(DOT)
		m.ring:SetPoint("CENTER")
		m.ring:SetSize(12, 12)
		m.ring:SetVertexColor(0, 0, 0, 1)
		m.dot = m:CreateTexture(nil, "ARTWORK", nil, 2)
		m.dot:SetTexture(DOT)
		m.dot:SetPoint("CENTER")
		m.dot:SetSize(9, 9)
		m.label = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		m.label:SetPoint("LEFT", m, "RIGHT", 2, 0)
		m.label:SetShadowOffset(1, -1)
		markers[i] = m
	end
	m:Show()
	return m
end

local function Short(title)
	if title and #title > 24 then return title:sub(1, 22) .. "..." end
	return title or ""
end

function TM:RefreshQuests()
	if not frame then return end
	local db = self.db
	local shown = 0
	if blob then blob:DrawNone() end

	if self.mapID and self.hasArt then
		local watched = {}
		for i = 1, C_QuestLog.GetNumQuestWatches() do
			local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
			if id then watched[id] = true end
		end
		for _, q in ipairs(C_QuestLog.GetQuestsOnMap(self.mapID) or {}) do
			local id = q.questID
			if not db.trackedOnly or watched[id] then
				shown = shown + 1
				local m = AcquireMarker(shown)
				local done = C_QuestLog.IsComplete(id)
				if done then
					m.dot:SetVertexColor(0.3, 1, 0.3)
					m.label:SetTextColor(0.3, 1, 0.3)
				else
					m.dot:SetVertexColor(1, 0.82, 0)
					m.label:SetTextColor(1, 0.82, 0)
				end
				m.label:SetText(db.names and Short(C_QuestLog.GetTitleForQuestID(id)) or "")
				m:ClearAllPoints()
				m:SetPoint("CENTER", pins, "TOPLEFT", q.x * W, -q.y * H)
				if blob and db.areas and not done then blob:DrawBlob(id, true) end
			end
		end
	end
	for i = shown + 1, #markers do markers[i]:Hide() end
end

---------------------------------------------------------------------------
-- Your arrow
---------------------------------------------------------------------------
local elapsed = 0
local function OnUpdate(_, dt)
	elapsed = elapsed + dt
	if elapsed < 0.04 then return end
	elapsed = 0
	local pos = TM.mapID and C_Map.GetPlayerMapPosition(TM.mapID, "player")
	-- No position inside dungeons; the map still shows.
	if not pos then
		arrow:Hide()
		return
	end
	local x, y = pos:GetXY()
	arrow:ClearAllPoints()
	arrow:SetPoint("CENTER", pins, "TOPLEFT", x * W, -y * H)
	arrow:SetRotation(GetPlayerFacing() or 0)
	arrow:Show()
end

---------------------------------------------------------------------------
-- Size, position, visibility
---------------------------------------------------------------------------
function TM:ApplyLayout()
	if not frame then return end
	local db = self.db
	W = db.width
	H = math.floor(W * layerH / layerW + 0.5)
	frame:SetSize(W, H)
	canvas:SetScale(W / layerW)
	frame:ClearAllPoints()
	if db.pos then
		frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.pos.x, db.pos.y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	end
	for _, t in ipairs(tiles) do t:SetAlpha(db.mapAlpha) end
	pins:SetAlpha(db.pinAlpha)
	if blob then blob:SetAlpha(db.pinAlpha) end
	self:RefreshQuests()
end

function TM:UpdateVisibility()
	if not frame then return end
	local db = self.db
	local show = db.shown and self.hasArt
	if show and db.hideInCombat and self.inCombat then show = false end
	if show and db.hideInInstance and IsInInstance() then show = false end
	-- While unlocked it always shows, so there's something to drag.
	frame:SetShown(show or self.unlocked)
end

---------------------------------------------------------------------------
-- Moving: /tmap unlock puts a box over the map. Drag to move, wheel to resize.
---------------------------------------------------------------------------
local function SavePosition()
	local x, y = frame:GetCenter()
	TM.db.pos = { x = x, y = y }
	TM:ApplyLayout()
end

function TM:SetUnlocked(on)
	self.unlocked = on
	box:SetShown(on)
	self:UpdateVisibility()
	self:RefreshConfig()
	self:Print(on and "Unlocked. Drag the green box to move, mouse wheel to resize, /tmap lock when done." or "Locked.")
end

local function MakeMover()
	box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	box:SetAllPoints()
	box:SetFrameStrata("DIALOG")
	box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	box:SetBackdropColor(0.2, 0.8, 0.3, 0.15)
	box:SetBackdropBorderColor(0.4, 1, 0.5, 1)
	box.label = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	box.label:SetPoint("TOP", 0, -6)
	box.label:SetText("TitanMap - drag to move, wheel to resize, right-click to lock")
	box:EnableMouse(true)
	box:EnableMouseWheel(true)
	box:RegisterForDrag("LeftButton")
	box:SetScript("OnDragStart", function() frame:StartMoving() end)
	box:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		frame:SetUserPlaced(false)
		SavePosition()
	end)
	box:SetScript("OnMouseWheel", function(_, delta)
		if not TM.db.pos then SavePosition() end
		local step = IsShiftKeyDown() and 10 or 40
		TM.db.width = math.max(200, math.min(1600, TM.db.width + delta * step))
		TM:ApplyLayout()
		TM:RefreshConfig()
	end)
	box:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then TM:SetUnlocked(false) end
	end)
	box:Hide()
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
function TM:SetupMap()
	frame = CreateFrame("Frame", "TitanMapFrame", UIParent)
	frame:SetFrameStrata("BACKGROUND")
	frame:SetClipsChildren(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(false)
	self.frame = frame

	canvas = CreateFrame("Frame", nil, frame)
	canvas:SetPoint("TOPLEFT")
	canvas:EnableMouse(false)

	-- Blizzard's shaded quest areas. Created safely in case the frame type is missing.
	local ok, b = pcall(CreateFrame, "QuestPOIFrame", nil, canvas)
	if ok and b then
		blob = b
		blob:SetAllPoints(canvas)
		blob:EnableMouse(false)
		blob:SetFillTexture("Interface\\WorldMap\\UI-QuestBlob-Inside")
		blob:SetBorderTexture("Interface\\WorldMap\\UI-QuestBlob-Outside")
		blob:SetFillAlpha(110)
		blob:SetBorderAlpha(200)
		blob:SetBorderScalar(1.0)
	end

	pins = CreateFrame("Frame", nil, frame)
	pins:SetAllPoints()
	pins:SetFrameLevel(canvas:GetFrameLevel() + 10)
	pins:EnableMouse(false)

	arrow = pins:CreateTexture(nil, "OVERLAY", nil, 7)
	arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
	arrow:SetSize(26, 26)
	arrow:Hide()
	frame:SetScript("OnUpdate", OnUpdate)

	MakeMover()
	self:CheckMap()
	self:ApplyLayout()
	self:UpdateVisibility()
end

-- A map button on the TitanQuests title bar, when that addon is loaded too.
function TM:AddTitanQuestsButton()
	C_Timer.After(0, function()
		local TQ = _G.TitanQuests
		if not (TQ and TQ.minBtn) then return end
		local b = CreateFrame("Button", nil, TQ.minBtn:GetParent())
		b:SetSize(15, 15)
		b:SetFrameLevel(TQ.minBtn:GetFrameLevel())
		b:SetPoint("RIGHT", TQ.minBtn, "LEFT", -26, 0)
		b:SetNormalTexture("Interface\\Icons\\INV_Misc_Map02")
		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		b:SetScript("OnClick", function() TM:Toggle() end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:AddLine("Show / hide map overlay")
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end)
end
