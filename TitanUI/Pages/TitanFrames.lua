-- TitanUI pages for TitanFrames.
local ADDON, UI = ...
local P = UI.Percent

local function Frames(p, TF)
	for _, info in ipairs(TF.FRAMES) do
		p:Slider(info.label .. " size", 0.3, 3, 0.05,
			function()
				local f = _G[info.name]
				return TF:Cfg(info.key).scale or (f and f:GetScale()) or 1
			end,
			function(v)
				local cfg = TF:Cfg(info.key)
				local f = _G[info.name]
				if not cfg.pos and f and f:GetLeft() then
					local rel = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
					cfg.pos = { x = f:GetLeft() * rel, y = f:GetTop() * rel }
				end
				cfg.scale = v
				TF:Apply(info)
			end, P)
	end
	p:Buttons({
		{ function() return TF.unlocked and "Lock frames" or "Unlock frames" end,
			function() TF:SetUnlocked(not TF.unlocked) end,
			"Unlocked: drag the orange boxes, mouse wheel to resize, right-click one to give it back to Blizzard." },
		{ "Give all back to Blizzard", function()
			for _, info in ipairs(TF.FRAMES) do TF:ResetFrame(info) end
		end },
	})
	p:Note("Frames you change here ignore Edit Mode until you give them back.")
	p:Header("Minimap")
	p:Check("Show map coordinates on the minimap",
		function() return TF:CoordsEnabled() end,
		function(v) TF:Cfg("coords").enabled = v; TF:UpdateCoords() end)
end

local SIDES = { { "top", "Top" }, { "bottom", "Bottom" }, { "left", "Left" }, { "right", "Right" } }

local function Viewport(p, TF)
	p:Note("Shrinks the area the game world is drawn in, leaving black space at the edges for your UI. "
		.. "The world is redrawn, not stretched. Changes made in combat apply when combat ends.")
	for _, s in ipairs(SIDES) do
		p:Slider(s[2] .. " edge", 0, 3000, 5,
			function() return TF:ViewportCfg()[s[1]] end,
			function(v) TF:ViewportCfg()[s[1]] = v; TF:ApplyViewport() end,
			nil, "Use the mouse wheel on the slider for 5-unit steps.")
	end
	p:Buttons({ { "Reset viewport", function() TF:ResetViewport() end } })
end

local function Minimap(p, TF)
	p:Check("Square minimap",
		function() return TF:SquareCfg().enabled end,
		function(v) TF:SquareCfg().enabled = v; TF:ApplySquare() end)
	p:Slider("Square minimap size", 120, 500, 2,
		function() return TF:SquareCfg().size end,
		function(v) TF:SquareCfg().size = v; TF:ApplySquare() end)
	p:Note("While TitanFrames is unlocked (Frames page), drag the grip in the minimap's corner to resize it, "
		.. "and drag the day/night dial to move it.")
end

local function StatusBars(p, TF)
	local BARS = { { "xp", "Hide the XP bar" }, { "xp2", "Hide the reputation / honor bar" } }
	for _, b in ipairs(BARS) do
		p:Check(b[2],
			function() return TF:BarHidden(b[1]) end,
			function(v)
				TF:Cfg("hide")[b[1]] = v or nil
				TF:ApplyHiddenBars()
			end)
	end
	p:Note("If a bar doesn't come back in the right spot after you untick it, type /reload.")
end

UI:Register({
	name = "TitanFrames", global = "TitanFrames",
	summary = "Move and resize minimap and XP bars; viewport; square minimap.",
	ready = function(ns) return ns.ready and TitanFramesDB ~= nil end,
	pages = {
		{ key = "frames", label = "Frames", build = Frames },
		{ key = "viewport", label = "Viewport", build = Viewport },
		{ key = "minimap", label = "Square minimap", build = Minimap },
		{ key = "status", label = "XP and rep bars", build = StatusBars },
	},
})
