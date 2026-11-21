-- TitanMeter: a simple window with a title bar and a stack of bars, shared by both meters.
local ADDON, TM = ...

local BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local HEADER_H = 18

local function SavePos(win)
	local point, _, relPoint, x, y = win:GetPoint(1)
	TM.db.pos[win.key] = { point, relPoint, x, y }
end

function TM:CreateWindow(key, defaultX, defaultY)
	local win = CreateFrame("Frame", "TitanMeter_" .. key, UIParent, "BackdropTemplate")
	win.key = key
	win.defaultX, win.defaultY = defaultX, defaultY
	win:SetFrameStrata("MEDIUM")
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	win:SetBackdropBorderColor(0, 0, 0, 1)

	local header = CreateFrame("Button", nil, win)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(HEADER_H)
	header:RegisterForClicks("AnyUp")
	header:RegisterForDrag("LeftButton")
	header.bg = header:CreateTexture(nil, "BACKGROUND")
	header.bg:SetAllPoints()
	header.bg:SetColorTexture(0.1, 0.1, 0.12, 0.9)
	header:SetScript("OnDragStart", function()
		if not TM.db.locked then win:StartMoving() end
	end)
	header:SetScript("OnDragStop", function()
		win:StopMovingOrSizing()
		SavePos(win)
	end)
	win.header = header

	win.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	win.title:SetPoint("LEFT", 6, 0)
	win.title:SetJustifyH("LEFT")
	win.title:SetWordWrap(false)

	win.right = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.right:SetPoint("RIGHT", -6, 0)
	win.right:SetJustifyH("RIGHT")

	win.empty = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	win.empty:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 6, -6)
	win.empty:SetPoint("RIGHT", -6, 0)
	win.empty:SetJustifyH("LEFT")

	win.rows = {}
	return win
end

function TM:GetRow(win, i)
	local row = win.rows[i]
	if row then return row end
	row = CreateFrame("StatusBar", nil, win)
	row:SetStatusBarTexture(BAR_TEX)
	row:SetMinMaxValues(0, 1)
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.bg:SetColorTexture(0.15, 0.15, 0.17, 0.6)

	row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.value:SetPoint("RIGHT", -4, 0)
	row.value:SetJustifyH("RIGHT")

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", 4, 0)
	row.name:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row:EnableMouse(true)
	win.rows[i] = row
	return row
end

-- Size and place the window; rows are stacked under the title.
function TM:LayoutWindow(win, cfg, repos)
	win:SetScale(cfg.scale)
	win:SetBackdropColor(0, 0, 0, cfg.alpha)
	win:SetSize(cfg.width, HEADER_H + 2 + cfg.rows * (cfg.rowHeight + 1) + 1)
	for i = 1, cfg.rows do
		local row = self:GetRow(win, i)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 1, -(HEADER_H + 2 + (i - 1) * (cfg.rowHeight + 1)))
		row:SetPoint("TOPRIGHT", -1, -(HEADER_H + 2 + (i - 1) * (cfg.rowHeight + 1)))
		row:SetHeight(cfg.rowHeight)
	end
	for i = cfg.rows + 1, #win.rows do
		win.rows[i]:Hide()
	end
	if repos or not win.placed then
		win:ClearAllPoints()
		local p = TM.db.pos[win.key]
		if p then
			win:SetPoint(p[1], UIParent, p[2], p[3], p[4])
		else
			win:SetPoint("CENTER", UIParent, "CENTER", win.defaultX, win.defaultY)
		end
		win.placed = true
	end
	win.header.bg:SetColorTexture(TM.db.locked and 0.1 or 0.1, 0.1, TM.db.locked and 0.12 or 0.3, 0.9)
end
