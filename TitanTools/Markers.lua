-- TitanTools: raid-marker keys. Set them in Options > Keybindings > AddOns > TitanTools.
-- Marks the mob under the mouse, or your target if the mouse isn't over one.
-- Pressing the same key on an already-marked mob takes the mark off.
local ADDON, TT = ...

BINDING_HEADER_TITANTOOLS = "TitanTools"
BINDING_NAME_TITANTOOLS_MARK_SKULL = "Mark skull (mouseover, else target)"
BINDING_NAME_TITANTOOLS_MARK_CROSS = "Mark X (mouseover, else target)"
BINDING_NAME_TITANTOOLS_MARK_CLEAR = "Clear all raid marks"

local SKULL, CROSS = 8, 7

local function MarkUnit()
	if UnitExists("mouseover") then return "mouseover" end
	if UnitExists("target") then return "target" end
end

function TT:Mark(index)
	local unit = MarkUnit()
	if not unit then return end
	local ok, current = pcall(GetRaidTargetIndex, unit)
	if ok and not (issecretvalue and issecretvalue(current)) and current == index then
		index = 0
	end
	SetRaidTarget(unit, index)
end

function TT:MarkSkull() self:Mark(SKULL) end
function TT:MarkCross() self:Mark(CROSS) end

function TT:ClearMarks()
	if RemoveRaidTargets then
		RemoveRaidTargets()
		return
	end
	-- Older clients: clear what we can reach.
	for _, unit in ipairs({ "target", "mouseover", "focus" }) do
		if UnitExists(unit) then SetRaidTarget(unit, 0) end
	end
end
