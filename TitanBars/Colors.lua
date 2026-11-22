-- TitanBars: clearer button colours.
--   Out of range: the whole icon turns red (Blizzard only reddens the keybind text).
--   Not enough mana: a stronger blue than Blizzard's pale tint.
-- Blizzard's button code still does all the work; after it colours an icon we just
-- recolour ours when one of these applies.
local ADDON, TB = ...

local RED = { 0.95, 0.25, 0.25 }
local BLUE = { 0.3, 0.45, 1.0 }

local function Secret(v) return issecretvalue and issecretvalue(v) or false end

local function Apply(btn)
	local db = TB.db
	if not db or not btn.icon or not btn.action then return end
	if db.colorRange and btn.tbOutOfRange then
		btn.icon:SetVertexColor(RED[1], RED[2], RED[3])
		return
	end
	if db.colorMana then
		local ok, usable, noMana = pcall(C_ActionBar.IsUsableAction, btn.action)
		if ok and not Secret(usable) and not Secret(noMana) and not usable and noMana then
			btn.icon:SetVertexColor(BLUE[1], BLUE[2], BLUE[3])
		end
	end
end

-- Ask Blizzard's code to colour the button again (it calls our hook after).
local function Recolor(btn)
	if btn.UpdateUsable then
		btn:UpdateUsable()
	else
		Apply(btn)
	end
end

function TB:HookButtonColors(btn)
	if btn.tbColorHooked or not btn.UpdateUsable then return end
	btn.tbColorHooked = true
	hooksecurefunc(btn, "UpdateUsable", Apply)
end

-- Re-colour every TitanBars button (after the setting changes).
function TB:RefreshButtonColors()
	for _, bar in pairs(self.bars or {}) do
		for _, btn in pairs(bar.buttons or {}) do
			if not self.db.colorRange then btn.tbOutOfRange = false end
			Recolor(btn)
		end
	end
end

local hooked = false
function TB:SetupButtonColors()
	if hooked or not ActionButton_UpdateRangeIndicator then return end
	hooked = true
	hooksecurefunc("ActionButton_UpdateRangeIndicator", function(btn, checksRange, inRange)
		if not btn.titanBar then return end
		if Secret(checksRange) or Secret(inRange) then return end
		local out = (checksRange and not inRange) and true or false
		if out ~= btn.tbOutOfRange then
			btn.tbOutOfRange = out
			Recolor(btn)
		end
	end)
end
