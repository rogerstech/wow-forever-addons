# WoW Forever Addons

Twelve addons for **World of Warcraft: Forever** (interface `16001`, built on the 12.1.x Midnight-era UI).
They were written against Blizzard's own Forever-branch UI source.

| Addon | What it does | Command |
|-------|--------------|---------|
| **TitanUI** | One settings window for all of them: addons (and their pages) in a tree on the left, settings on the right. | `/tui` |
| **TitanCraft** | A faster crafting window you can move. Sorts recipes that give a skill point to the top, crafts your next skill-up in one click, shows what you can make and what you're missing. | `/tcraft` |
| **TitanUnits** | Modern player and target frames with an animated 3D face portrait, class badge, health/mana text, target level/elite tag, target cast bar, your threat on the target and its buffs/debuffs. Plus party and raid frames for tanking: health and mana, range fading, your target outlined, and a red border on anyone who has pulled a mob off you. | `/tunits` |
| **TitanGear** | One-click gear sets (e.g. Tank and Ret): a small bar, keys, and `/tgear Tank` for macros. | `/tgear` |
| **TitanBars** | Bartender-style action bars. Hides the Blizzard bars and their art (gryphons, border, page arrows). Gives you 8 bars you can turn on/off, move, resize, set buttons per row, spacing, opacity and show/hide rules, plus hover-to-bind keys. Also moves/resizes the bag bar and menu buttons and strips their art. Optional cooldown numbers on buttons; icons turn red out of range and strong blue when you're short on mana. Info panel along the top or bottom with coordinates, zone, clock, FPS/latency, gold, durability, bag space and XP, holding the bags and menu buttons. | `/tb` |
| **TitanTools** | Buff reminder (druid and paladin buffs) and a tank form warning (Bear Form or Righteous Fury), a target-of-target frame for tanking, nameplate aggro colours, auto-repair and junk selling, quest auto-accept and turn-in, an Open All mail button, and a paladin blessing helper (one button or key blesses the next person who needs it). | `/ttools` |
| **TitanFrames** | Move and resize the minimap, party frames, raid frames and XP bar, and show map coordinates on the minimap. Viewport (shrink the game world to leave black space for your UI), an optional square, resizable minimap, and hiding the XP / reputation bars. | `/tf` |
| **TitanChat** | A cleaner, flatter chat window: dark panel, flat tabs with a class-coloured underline, Arial Narrow font, tidy input box, side buttons hidden. Restyles Blizzard's chat, so tabs, whispers and links all work as normal. | `/tchat` |
| **TitanQuests** | A cleaner quest tracker that replaces Blizzard's. Quests grouped by zone, fold quests or zones away, quest item buttons, and one button (or key) to minimize it. Minimizes itself in dungeons and raids. | `/tquests` |
| **TitanMeter** | Damage meter (damage, DPS, healing, HPS, damage taken, absorbs, interrupts, dispels, deaths; this fight or overall, with a spell breakdown on hover) and a threat meter for your target, for you and your group. Uses the game's own combat numbers. | `/tmeter` |
| **TitanMap** | A see-through map of your zone that sits on your screen while you play: your arrow, quest markers and shaded quest areas. Clicks go straight through it. Toggle with a key. | `/tmap` |
| **TitanBags** | All your bags in one window that you can drag anywhere. Hides Blizzard's bag windows. Sort button (tidies your bags), plus sorted views by quality, type, name or item level that don't move anything. Search box, free slots, gold, keyring. | `/tbags` |

## Download

**[Download the latest version (zip)](https://github.com/rogerstech/wow-forever-addons/releases/latest/download/WoW-Forever-Addons.zip)**
· [all releases](https://github.com/rogerstech/wow-forever-addons/releases)

Each addon works on its own, so install only the ones you want.

## Install

1. Close the game.
2. Copy the `TitanBars`, `TitanFrames`, `TitanTools`, `TitanQuests`, `TitanMap`, `TitanMeter`, `TitanChat`, `TitanBags`, `TitanCraft`, `TitanUnits`, `TitanGear` and `TitanUI` folders into
   `World of Warcraft\_forever_\Interface\AddOns\`
   (Battle.net > gear icon next to Play > Show in Explorer to find it).
   Each `.toc` must sit one folder below `AddOns`, e.g. `AddOns\TitanBars\TitanBars.toc`.
3. Start the game. At character select, click **Menu** (top of the screen) > **AddOns** and make sure the ones you want are ticked
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

### Info panel (`/tb panel`)

A full-width strip along the top or bottom of the screen. It holds the bag bar and menu buttons
(sized to fit, on the right) and a row of readouts on the left, each of which you can turn on or off:
coordinates (x, y, and z when the game gives it), zone and subzone, clock, FPS and latency, gold,
your lowest gear durability, free bag slots, and XP with rested XP (hidden at max level).
It can also dock your buffs and debuffs against its edge.

- `/tb panel` opens its settings: on/off, top or bottom, height, background, buff docking and the readouts.
- `/tb panel top`, `/tb panel bottom`, `/tb panel on`, `/tb panel off` for quick changes.
- Turning it off: `/reload` puts the bags, menu buttons and buffs back in their usual spots.
- Dragging the buffs in Edit Mode undocks them from the panel. The bags and menu buttons stay on the
  panel while it's on.
- To keep the game world from drawing under the panel, set a TitanFrames viewport edge (`/tf`).

## TitanTools

- `/ttools` opens the settings window. `/ttools unlock` shows green boxes over the buff reminder and
  the target-of-target frame: drag to move, mouse wheel to resize, right-click to reset.
- **Buff reminder:** large pulsing icons when Mark of the Wild (Gift of the Wild counts), Thorns or
  Omen of Clarity is missing, or yellow with a timer when one has under a minute left. Out of combat
  only. Only spells you know are checked. Paladins get a "Blessing" icon when none of their blessings
  is up (Salvation doesn't count) and "No aura" when no aura is active.
- **Tank form warning** (one setting, per class, in a group only):
  - Druid: an orange "NOT IN BEAR" icon in combat when you're not in Bear or Dire Bear Form.
  - Paladin: an orange "NO FURY" icon when Righteous Fury is off, before the pull as well as during
    it, yellow with a timer under a minute, and "REMOVE SALV" if Salvation is on you (it cuts your
    threat). If the game hides your buffs in combat, it uses what it saw just before the pull.
  - Untick it if you're healing or playing DPS on purpose.
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

## TitanMap

A faded map of the zone you're in, drawn over the game so you can keep the whole picture in view and
still play. Nothing on it takes the mouse: clicks go through to the world, so you can still target
and loot under it.

- **Toggle:** set a key in Options > Keybindings > AddOns > TitanMap, type `/tmap`, or click the map
  icon on the TitanQuests title bar.
- **What's on it:** your arrow (points the way you face), a **gold dot** for each quest in progress and
  a **green dot** for each one ready to turn in, with the quest name beside it, and the shaded areas
  where a quest's objectives are. It follows you from zone to zone and into cities.
- **Moving and sizing:** `/tmap unlock`, then drag the green box and use the mouse wheel to resize
  (Shift for fine steps). Right-click the box or `/tmap lock` when done.
- **Settings** (`/tmap config`): map opacity and marker opacity (separately), width, only tracked
  quests or all, quest names, quest areas, and hide during combat or in dungeons.
- In dungeons the game doesn't give addons your position, so there's no arrow there.

**Viewport** (in the `/tf` window): shrink the area the game world is drawn in, leaving black space
at the top, bottom, left or right for your bars and meters. The world is not stretched. Use the four
sliders, or type an exact value with `/tf viewport bottom 120` (also `top`, `left`, `right`, 0-3000);
`/tf viewport reset` gives the whole screen back. Changes made in combat apply when combat ends.

**Hide the XP bar / reputation bar** (in the `/tf` window, under "Status bars"): tick either box to hide
that bar. Untick to bring it back (`/reload` if it doesn't return to the right spot). The TitanBars info
panel (`/tb panel`) can show your XP and rested XP instead.

**Square minimap** (in the `/tf` window): tick "Square minimap" for a square map with a thin dark
border instead of the round frame. Set the size with the slider, or `/tf unlock` and drag the grip in
the minimap's bottom-right corner. Untick it to get the round minimap back.
On a square map the day/night dial moves to the top-right corner. While unlocked (`/tf unlock`) you
can drag the dial anywhere (right-click it to put it back); it follows the minimap when it moves or resizes.

## TitanChat

Restyles the game's own chat windows (it doesn't replace them, so everything chat does keeps working):
dark flat panel, flat tabs with a class-coloured line under the one you're viewing, a flat input box
that lights up while you type, and the column of buttons beside chat hidden. `/tchat` opens settings:
background darkness, line spacing, outlined text, font (Arial Narrow, Friz Quadrata or the game's
default) and whether to hide the side buttons. Font size, colours and channels stay in Blizzard's chat
settings (right-click a tab). TitanChat never reads or changes message text, so it's unaffected by the
game hiding chat text from addons in combat.

## TitanMeter

Two small windows. Forever counts damage, healing and threat itself (it has a built-in meter of
its own); TitanMeter shows those numbers in a cleaner layout. It turns the game's meter on behind
the scenes and hides Blizzard's window (`/tmeter blizzard show` brings it back).

**Damage meter**
- **Left-click the title** for the next mode, **right-click** for the previous: Damage, DPS, Healing,
  HPS, Damage Taken, Absorbs, Interrupts, Dispels, Deaths, Enemy Damage Taken.
- **Click Current / Overall** (top right) to switch between this fight and everything since the last
  reset. The timer beside it is the fight length.
- Bars are class-coloured; your name is gold. If you're further down than the window shows, you take
  the last row, so you always see yourself.
- **Hover a bar** after combat to see that player's spells (amount and share). During combat the game
  doesn't let addons look this up.
- **Shift-click the title** or `/tmeter reset` to clear all fights.

**Threat meter**
- Shows threat on your target for you, your group (or raid) and your pet. If your target is friendly
  (healers), it uses your target's target.
- **100%** = has aggro (red bar). Everyone else shows how close they are to pulling it; **orange at
  80%** or more. The tank is listed first.
- Shows in combat only by default; `/tmeter threat always` keeps it up whenever you have a hostile target.

**Commands**
- `/tmeter unlock` then drag the window titles to move them, and drag the grip in the bottom-right
  corner to resize (width follows the mouse, height snaps to whole rows); `/tmeter lock` when done.
- `/tmeter rows N`, `/tmeter width N`, `/tmeter scale N` size the damage meter;
  `/tmeter threatrows N`, `/tmeter threatwidth N`, `/tmeter threatscale N` size the threat window.
- `/tmeter meter off`, `/tmeter threat off` hide a window. `/tmeter resetpos` re-centres both.

In combat the game hides exact numbers from addons ("secret values"). They can still be drawn, which is
what TitanMeter does, but they can't be sorted by an addon. The damage list arrives already sorted by
the game. The threat list is sorted when the game allows it; if it ever doesn't, it falls back to group
order (the bars and percentages are still right).

## TitanBags

Press **B** (or click the backpack) as usual: your bags open in one TitanBags window instead of
Blizzard's. Blizzard's bag code still runs underneath, so bag keys, vendors, mail and the bank still
open and close your bags as normal. Items behave exactly like Blizzard's bags: right-click to use (works
in combat), drag, Shift-click to split, sell to vendors, tooltips.

- **Move it:** drag the title bar. It remembers where you put it and grows up and to the left from that
  corner. Right-click the title bar > Lock position to stop accidental drags.
- **Sort button** (broom icon, top right): tidies your bags for real, the same as Blizzard's sort.
  Not in combat.
- **Sorted views** (right-click the title bar > Show items by): bag order, quality, type, name or item
  level. These only change how the window draws your items; nothing moves in your bags. Empty slots go at
  the end. While your mouse is over the window, the order holds still so items don't jump under your
  cursor; it re-sorts when you move away.
- Search box filters your items. Bottom bar shows free slots (yellow at 4 or fewer, red when full) and gold.
- Keyring shows in its own "Keys" section (right-click menu to turn off).

Commands: `/tbags` (open/close), `/tbags sort`, `/tbags view bag|quality|type|name|ilvl`,
`/tbags columns N`, `/tbags scale N`, `/tbags lock` / `unlock`, `/tbags keys on|off`,
`/tbags reset` (window back to the bottom-right), `/tbags blizzard show` (go back to Blizzard's bags).

## TitanUI

One window for every Titan addon's settings, so you don't have to remember `/tb`, `/tf`, `/ttools`...

- `/tui` (or `/titanui`) opens it. `/tui bars`, `/tui bags`, `/tui meter`... jumps straight to one addon.
  You can also bind a key (Esc > Options > Keybindings > AddOns > TitanUI) or use Esc > Options > AddOns > TitanUI.
- **Left:** a tree of your installed Titan addons. Addons with several pages (TitanBars: General, Bar 1-8,
  Bags and menu, Info panel, Profiles; TitanFrames: Frames, Viewport, Square minimap, XP and rep bars;
  TitanMeter: General, Damage meter, Threat meter) open up when you click them; click again to fold.
- **Right:** that page's settings. Everything applies straight away. Mouse wheel over a slider nudges it one step.
- **Overview** shows which Titan addons are on, turned off, or not installed.
- Addons that aren't installed or are turned off simply don't appear in the tree.
- TitanBars pages can't be changed in combat (Blizzard locks action bars then).
- Each addon's own command still opens its old window, if you prefer it.

## TitanCraft

Open a profession as usual (spellbook, keybind or the profession button) and TitanCraft's window
appears instead of Blizzard's.

- **Move it:** drag the title bar. Drag the bottom-right corner to make it taller or shorter.
- **Recipe colours** are your chance of a skill point: orange always, yellow usually, green sometimes,
  grey never. `+2` next to a recipe means it gives two points. `[5]` is how many you can make now.
- **Sort** (button above the list): *Skill-ups first* (default: orange, then yellow, green, grey;
  recipes you have materials for come first within each colour), *Can make now first*, *Name*, *Category*.
- **Have materials** and **Hide grey** filters, plus a search box.
- **Craft next skill-up** (top right): makes one of the recipe most likely to give you a point that you
  have materials for. Click it again after each craft; it re-picks as recipes change colour.
- Right side: reagents with have / need (green = enough, red = short), required tools (anvil, forge...)
  and cooldowns. Create 1 or a number, or **Create all**. Double-click a recipe to make one.
  Shift-click a recipe or reagent to link it in chat.
- Your other crafting professions are icons at the top left: click to switch.
- **Blizzard window** (title bar) switches to Blizzard's window until you close the profession,
  for specializations or anything TitanCraft doesn't show. Other players' linked professions and
  guild lists always use Blizzard's window.
- `/tcraft blizzard on` goes back to Blizzard's window for good (`off` to return). Settings are in TitanUI.

## TitanUnits

**Player and target frames.** A dark, flat frame with an animated 3D portrait of the face (yours and your
target's), a class badge, health as `15.2k / 18k` and `84%`, and mana/rage/energy. The player frame shows a
combat or resting icon and a crown when you lead the group. The target frame adds its level (coloured by
difficulty, `??` for skull), an Elite / Rare / Boss tag, a **cast bar** (orange = can be interrupted, grey with a shield = can't; it fills as the cast goes, or shows the spell name on a full bar if the game hides the timing), its buffs and debuffs underneath, and your threat:
**green border = it's attacking you, red = it isn't**, with your threat % above. If the target isn't loaded
near you, the portrait falls back to the flat picture. Portrait style (3D face, flat picture, class icon),
size, and the target options are in TitanUI > TitanUnits > Player & target. `/tunits unlock` to drag them.

**Group frames.** Party and raid frames for tanking. Left-click a frame to target, right-click for the menu.

- Health bar (class colours) with health %, a thin mana/power bar, "Dead" / "Offline".
- **Red border** on anyone who has pulled a mob off you. It uses the game's threat state; if the game hides
  that in combat, it falls back to whether your current target is hitting them.
- **White outline** on your current target. Out-of-range members fade.
- Party is a column (or a row); in a raid, one column per group.
- Hides Blizzard's party and raid frames (untick in TitanUI to get them back).
- `/tunits unlock` to drag them, `/tunits solo` to show your own frame while solo (to set them up).
  Everything else is in TitanUI. Size and layout changes made in combat wait until combat ends.

## TitanGear

1. Put on your tank gear, click **+** on the gear bar, call it `Tank`.
2. Put on your ret / questing gear, click **+**, call it `Ret`.
3. Click a set's icon to put it on (green border = wearing it). Right-click a set to save your current gear into it or delete it.

Keys: Esc > Options > Keybindings > AddOns > TitanGear (sets 1-4, or one key that swaps to the next set).
Macros: `/tgear Tank`. Armour can't change in combat, so a swap asked for then happens as soon as combat ends.
Sets are the game's own equipment sets, saved on the server.

## Blessing helper (TitanTools, paladins)

A small button that shows who needs a blessing next, e.g. `Might Tankbro 3/5`. Click it (or bind a key: Esc >
Options > Keybindings > AddOns > TitanTools) to cast it, then click again for the next person. It also re-blesses
anyone with under a minute left. Which blessing each class gets is set in TitanUI > TitanTools (defaults: Might for
warriors, rogues and hunters; Wisdom for casters; Kings for paladins and druids). Salvation is never cast on you.
Blizzard only lets the button be prepared out of combat, so in combat it shows "In combat". Move it with `/ttools unlock`.

## Notes

- Nothing can move or bind action buttons during combat. That is a Blizzard rule. Changes you make
  then are queued until combat ends.
- Written against Blizzard's Forever UI source and played on a druid tank. TitanBars, TitanFrames and
  TitanTools are in daily use; TitanQuests is new. If you hit a Lua error, install BugSack/BugGrabber
  and open an issue with the error text.
