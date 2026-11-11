# WoW Forever Addons

Four addons for **World of Warcraft: Forever** (interface `16001`, built on the 12.1.x Midnight-era UI).
They were written against Blizzard's own Forever-branch UI source.

| Addon | What it does | Command |
|-------|--------------|---------|
| **TitanBars** | Bartender-style action bars. Hides the Blizzard bars and their art (gryphons, border, page arrows). Gives you 8 bars you can turn on/off, move, resize, set buttons per row, spacing, opacity and show/hide rules, plus hover-to-bind keys. Also moves/resizes the bag bar and menu buttons and strips their art. Optional cooldown numbers on buttons. | `/tb` |
| **TitanTools** | Buff reminder (Mark of the Wild, Thorns, Omen of Clarity) and a "not in Bear Form" warning, a target-of-target frame for tanking, nameplate aggro colours, auto-repair and junk selling, quest auto-accept and turn-in, and an Open All mail button. | `/ttools` |
| **TitanFrames** | Move and resize the minimap, party frames, raid frames and XP bar, and show map coordinates on the minimap. | `/tf` |
| **TitanQuests** | A cleaner quest tracker that replaces Blizzard's. Quests grouped by zone, fold quests or zones away, quest item buttons, and one button (or key) to minimize it. Minimizes itself in dungeons and raids. | `/tquests` |

## Download

**[Download the latest version (zip)](https://github.com/rogerstech/wow-forever-addons/releases/latest/download/WoW-Forever-Addons.zip)**
· [all releases](https://github.com/rogerstech/wow-forever-addons/releases)

Each addon works on its own, so install only the ones you want.

## Install

1. Close the game.
2. Copy the `TitanBars`, `TitanFrames`, `TitanTools` and `TitanQuests` folders into
   `World of Warcraft\_forever_\Interface\AddOns\`
   (Battle.net > gear icon next to Play > Show in Explorer to find it).
   Each `.toc` must sit one folder below `AddOns`, e.g. `AddOns\TitanBars\TitanBars.toc`.
3. Start the game. At character select, click **Menu** (top of the screen) > **AddOns** and make sure all four are ticked
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
- `/tb rankup` puts the highest rank you know of every spell on your bars (see Spell ranks below).
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

**Cooldown numbers:** tick "Show cooldown numbers on buttons" in `/tb` for a countdown on every button.
This is Blizzard's own setting, so it also shows in Options.

**Spell ranks (1.4.0):** learning a new rank (Maul Rank 6, say) doesn't replace the old rank on your
bars, so TitanBars does it: when you train, any button holding your previous highest rank moves to the
new one, and chat shows `Maul Rank 5 -> Rank 6 (slot 3)`. Buttons you keep on a lower rank on
purpose (a downranked heal) are left alone. `/tb rankup` moves every lower rank up, downranks
included. `/tb rankup off` / `on` turns the automatic part off and on. It waits for combat to end,
and skips a button if you're holding something on the cursor (it tries again next time).

**Not replaced:** the pet bar, stance / forms bar, extra action button and vehicle bar stay Blizzard's.
Move those in Edit Mode.

## TitanFrames

- `/tf` opens a window with a size slider for Minimap, Party frames, Raid frames, XP bar, and the
  second status bar (reputation/honor, when you track one).
- `/tf unlock` shows orange handles. Drag to move, mouse wheel to resize, right-click to hand the
  frame back to Blizzard. Handles work even when you aren't in a group.
- `/tf reset` hands everything back (then `/reload`).
- **Map coordinates:** your X, Y position at the bottom of the minimap. Blank in dungeons, where the
  game gives no position. Turn it off with the checkbox in `/tf`.

Once you change a frame here, TitanFrames keeps it there even if Edit Mode or a roster change
moves it. Use Reset to let Edit Mode control it again. Party and raid frames are protected, so
changes you make to them during combat apply when combat ends. As a fight starts, a secure
handler puts them back in your spot in case anything moved them.

## TitanTools

- `/ttools` opens the settings window. `/ttools unlock` shows green boxes over the buff reminder and
  the target-of-target frame: drag to move, mouse wheel to resize, right-click to reset.
- **Buff reminder:** large pulsing icons when Mark of the Wild (Gift of the Wild counts), Thorns or
  Omen of Clarity is missing, or yellow with a timer when one has under a minute left. Out of combat
  only. Only spells you know are checked. Druid only for now.
- **Bear Form warning:** an orange "NOT IN BEAR" icon when you're in combat, in a group, and not in
  Bear or Dire Bear Form. Untick it if you're healing or in Cat Form on purpose.
- **Target of target:** shows who your target is hitting. On a hostile target the bar is green
  while it's on you and red with a "!" when it's on someone else. Click it to target them.
- **Nameplate aggro colours:** enemy nameplates turn green while that mob is attacking you and red
  while it's attacking someone else, so you can see which mob got loose. Mobs that aren't in combat
  keep Blizzard's colour. Needs enemy nameplates turned on (V by default). There's an option to only
  colour them while in a group.
- **Vendors:** opening a vendor repairs everything and sells grey items (12 per visit, the buyback
  limit), then prints what it cost and earned.
- **Quests:** accepts quests and turns in finished ones as soon as you talk to the NPC. Hold Shift
  while clicking the NPC to do it yourself. Low-level (grey) quests are left alone. When a quest
  offers a choice of rewards it stops, marks the one that sells for the most with a gold coin, and
  lets you pick, so you can still take an upgrade. Quests that cost gold keep Blizzard's
  confirmation. Untick it in `/ttools` to turn it off.
- **Open all mail:** an "Open all" button on the mailbox that takes every item and all the gold,
  skipping COD and GM mail. Stops when your bags are full. If the mailbox already has Blizzard's own
  Open All button, TitanTools leaves it to that one.

## TitanQuests

Replaces Blizzard's quest tracker (the list on the right of the screen) with a slimmer one and hides
Blizzard's. The quest log itself (on the map) is still Blizzard's.

- **Minimize:** the `-` button on the title bar folds the tracker down to just its title bar, which
  still shows `12/25` quests and how many are ready to turn in. Click `+` to bring it back. It works in
  combat. For a key, go to Options > Keybindings > AddOns > TitanQuests. `/tquests min` does the same.
- **Dungeons and raids:** it minimizes itself when you zone in and comes back when you leave (if it
  was open when you went in). Untick it in `/tquests`. There's also "Minimize during combat".
- **Folding:** click a quest to fold its objectives away, click a zone name to fold the whole zone.
  The `+`/`-` next to each shows which are folded. Right-click a quest for: open in quest log, stop
  tracking, share with party, fold/unfold all, abandon. Shift-click a quest to stop tracking it.
- **Moving and sizing:** drag the title bar to move it. Drag the corner grip (bottom-right) to make it
  wider or narrower. Scale, text size, max height and background darkness are sliders in `/tquests`.
  Tick "Lock position and width" when you're happy. `/tquests reset` puts it back by the minimap.
- **What it shows:** by default your tracked quests. Tick "Every quest in the log" to see all of them.
  Finished objectives are hidden (untick to see them greyed out with a tick); finished quests turn
  green with "Ready to turn in". Quest levels are coloured by difficulty. Turn off zone grouping or
  levels if you want it even barer.
- **Quest items:** quests that give you an item to use show a button to the left of the quest. Click it
  to use the item. These are secure buttons, so they're placed out of combat: if the list changes
  mid-fight they catch up when combat ends, and you can't scroll the list in combat while one is showing.
- **Long lists:** past the max height it shows "N more"; mouse wheel over the list scrolls.
- **Blizzard's tracker back:** untick "Hide Blizzard's quest tracker" (or disable TitanQuests).

## Notes

- Nothing can move or bind action buttons during combat. That is a Blizzard rule. Changes you make
  then are queued until combat ends.
- Written against Blizzard's Forever UI source and played on a druid tank. TitanBars, TitanFrames and
  TitanTools are in daily use; TitanQuests is new. If you hit a Lua error, install BugSack/BugGrabber
  and open an issue with the error text.
