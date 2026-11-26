# LegacyPath

**What should I do next to advance my Legacy?**

An addon for World of Warcraft: Forever. It reads your 65 Legacy Challenges from the game, ranks the unfinished ones by how close and how doable they are, and lets you keep an ordered plan with notes.

> The new window layout has not been seen in the game client yet. Seen working in earlier versions: live data, recommendations, the quest tracker section docked under Questie's tracker, the unspent points bubble, the closest character in the tracker, and recorded full names and professions. The rest of the checklist below has not been confirmed in game.

## Install

1. Unzip so that the `LegacyPath` folder sits in `World of Warcraft\_forever_\Interface\AddOns\`.
2. Restart the game or type `/reload`.

No other addons or libraries are needed.

## Commands

| Command | Does |
|---|---|
| `/lp` or `/legacypath` | Open or close the window |
| `/lp next` | Print your top three next steps to chat |
| `/lp scale 0.6`–`1.6` | Set the window scale |
| `/lp minimap` | Show or hide the minimap button |
| `/lp points` | Show the unspent points reminder now |
| `/lp reset` | Move the window back to the centre |

The window also opens from the minimap button and the addon compartment. Drag the title bar to move it and the bottom-right corner to resize it; both are remembered.

## Tabs

- **Overview** — Legacy Points earned out of 65, any points this character still has to spend, your best next step and the ones close behind it (Show more lists up to 15), progress per category and recent completions. Hover a challenge for why it is ranked there.
- **Challenges** — every challenge by category. Classes and Tradeskills are grids with one column per tier: hover a square for details, click it to pin. The search box covers every category and filters by name, category, profession/class, or requirement. The last entry is a reference list of rewards and perks.
- **Plan** — challenges you pinned, in your order (arrow buttons), each with an optional note. It updates as progress changes and tells you in chat when a pinned challenge completes.
- **Quest tracker section** — your unfinished pinned challenges (3 by default) appear under the quest tracker (Questie's tracker if you use Questie) with their progress lines. Click one to open your plan, click the header to collapse it, drag the header to move it. Forever does not allow Blizzard's own tracking of Legacy challenges, so this is LegacyPath's own section styled to match.
- **Characters** — every character LegacyPath has seen: level, professions, unspent points, and the challenges it is the closest character to. Challenge progress itself is account-wide. Log in to each character once so its professions are recorded. Other characters are **snapshots** from their last login, dated as such.
- **Settings** — completion messages, unspent points reminder, minimap button, tooltip line, hide completed, quest tracker section (on/off, docked, how many), window scale, and which categories to recommend from.

## How recommendations are ranked

`score = progress (0–100) + 25 if this character is the closest one (or high enough for a dungeon band) − 30 if an earlier tier is unfinished + up to 10 for lower estimated difficulty`

- Class and profession challenges name your closest character, using its level or skill when last seen. If a character LegacyPath has not recorded is further along, it names nobody rather than the wrong one.
- For PvP, raid and adventure challenges LegacyPath does not claim the current character can do them.
- Dungeon challenges are not counted as doable until you reach the start of their level band (15, 26, 46).
- "Estimated difficulty" (low / medium / high) is LegacyPath's own rough guide. The addon gives no time estimates.

## Where the data comes from

| Data | Source |
|---|---|
| Challenge names, requirements, completion, criteria progress | Live from the game client (achievement API) |
| Class challenge progress | Derived from the level of your highest character of that class that LegacyPath has seen |
| Closest character for a profession | Each character's own profession skill, recorded when you log in to it |
| Unspent Legacy Points | Live from the game client, read the same way as the Legacy panel's "Available points" |
| Challenge list, categories | Read from the client on build 1.60.1.70862, checked against the live list at login |
| Difficulty, tier ordering | LegacyPath's own estimates |
| Rewards and perk names | Blizzard's Legacy System post — reference only |

Every challenge tooltip states which of these its progress uses. If a patch adds challenges, they appear automatically under the game's own category.

**Manual mode:** if the client reports no achievement data, LegacyPath says so on the Overview and each challenge gets a Done / Undo button instead. Manual ticks are never mixed with live data.

## Limitations

- English text only.
- Reward unlock thresholds and perk costs are not published by Blizzard and are not shown. Spend points in the game's Legacy panel.
- PvP rank, reputation, quest-line and raid challenges show only what the client reports (often just done / not done).
- Other characters' progress is only as fresh as their last login with the addon enabled.
- No map pins or zone guidance; the Legacy Forever addon does that well.
- Hardcore is not handled (not available at launch).

## Testing status

Run from the repository root with LuaJIT or Lua 5.1:

```
luajit tests/run.lua        # logic: scoring, prerequisites, migrations, filters, manual mode, snapshots
luajit tests/ui_smoke.lua   # loads all files against a stub widget API and presses every button
```

Still to check in the game client:

1. The addon loads without errors and `/lp` opens the window.
2. Overview shows the same points and completions as the Legacy panel.
3. Window moves, resizes, rescales, and keeps its place after `/reload`.
4. Pin, reorder, note, and unpin on the Plan tab; the plan survives `/reload`.
5. Gaining a skill point or level updates progress within about a second, and not during combat.
6. Completing a challenge prints one chat line (and none at login).
7. A second character appears on the Characters tab and the first becomes a dated snapshot, each with its own professions. On the second, pinned profession and class challenges name the first character.
8. Minimap button shows, drags, hides. The addon compartment entry opens the window.
9. Hovering a Legacy Challenge achievement shows the LegacyPath tooltip line.
10. Pinned challenges appear directly under the quest tracker and follow it as quests are added or removed. Dragging the header undocks it; the Settings toggle docks it again.
11. With points to spend, every login shows one bubble pointing at the Legacy micro menu button (a `/reload` does not repeat it), which closes when dismissed or when the Legacy panel opens, and the Overview shows the count; it matches the Legacy panel's "Available points", and spending them clears it.
