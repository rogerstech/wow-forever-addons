# WoW Forever Addons

Two addons for **World of Warcraft: Forever** (interface `16001`, built on the 12.1.x Midnight-era UI).
They were written against Blizzard's own Forever-branch UI source.

| Addon | What it does | Command |
|-------|--------------|---------|
| **TitanBars** | Bartender-style action bars. Hides the Blizzard bars and their art (gryphons, border, page arrows). Gives you 8 bars you can turn on/off, move, resize, set buttons per row, spacing, opacity and show/hide rules, plus hover-to-bind keys. Also moves/resizes the bag bar and menu buttons and strips their art. | `/tb` |
| **TitanFrames** | Move and resize the minimap, party frames, raid frames and XP bar. | `/tf` |

## Install

1. Close the game.
2. Copy the `TitanBars` and `TitanFrames` folders into
   `World of Warcraft\_forever_\Interface\AddOns\`
   (Battle.net > gear icon next to Play > Show in Explorer to find it).
   Each `.toc` must sit one folder below `AddOns`, e.g. `AddOns\TitanBars\TitanBars.toc`.
3. Start the game. At character select, click **Menu** (top of the screen) > **AddOns** and make sure both are ticked
   (tick "Load out of date AddOns" if a patch has bumped the interface number).

## TitanBars

On first login it copies your existing keybinds over (key `1` still fires bar 1 button 1, etc.),
so nothing changes until you start moving things.

- `/tb` opens the settings window. Pick a bar (1-8) at the top, then set:
  enabled, number of buttons, buttons per row, size, spacing, opacity, show/hide rule.
- `/tb unlock` shows a blue handle on each bar, plus the bag bar and the menu buttons
  (character, spellbook, professions...). **Drag** to move, **mouse wheel** to resize
  (hold Shift for fine steps), **right-click** for that bar's settings. `/tb lock` when done.
- `/tb bind` turns on keybind mode. Hover any button and press a key, mouse button (3-5)
  or mouse wheel to bind it. Modifiers work (Shift/Ctrl/Alt). **Esc** over a button clears it.
  Click Done (or press Esc with nothing hovered) to finish.
- `/tb importkeys` re-copies your Blizzard action bar keybinds onto the bars.
- `/tb profiles`, `/tb copy Name - Realm` - layouts are saved per character. A new character
  starts with a copy of the last one you played.
- `/tb reset` puts every bar back to default.

Bar 1 behaves like the default main bar: it swaps for stances/forms/stealth, Shift+wheel paging,
and vehicles. Bars 2-8 show the same action slots as Blizzard's bars 2-8, so anything you already
had on your bars is still there.

Show/hide rule examples (macro conditions):
`[combat] show; hide` - only in combat. `[mod:shift] show; hide` - only while holding Shift.
`[petbattle] hide; show` - the default.

Keybinds are applied as override bindings: your real Blizzard bindings are left alone and come back
if you disable the addon. "Cast on key down" (Options > Gameplay > Combat) is respected.

**Bags and menu buttons:** unlock and drag them like a bar, mouse wheel to resize, right-click to
hand them back to Edit Mode. Their sizes are also in the `/tb` window. Their frame art is hidden by
default; untick "Hide bag + menu button art" and `/reload` to get it back.

**Not replaced:** the pet bar, stance bar, extra action button and vehicle bar stay Blizzard's.
Move those in Edit Mode.

## TitanFrames

- `/tf` opens a window with a size slider for Minimap, Party frames, Raid frames, XP bar, and the
  second status bar (reputation/honor, when you track one).
- `/tf unlock` shows orange handles. Drag to move, mouse wheel to resize, right-click to hand the
  frame back to Blizzard. Handles work even when you aren't in a group.
- `/tf reset` hands everything back (then `/reload`).

Once you change a frame here, TitanFrames keeps it there even if Edit Mode or a roster change
moves it. Use Reset to let Edit Mode control it again. Party and raid frames are protected:
changes made in combat apply as soon as combat ends.

## Notes

- Nothing can move or bind action buttons during combat. That is a Blizzard rule. Changes you make
  then are queued until combat ends.
- Built from reading the Forever UI source, not yet played in-game. If you hit a Lua error, install
  BugSack/BugGrabber and send the error text.
