# LegacyPath

**What should I do next to advance my Legacy?**

An addon for World of Warcraft: Forever. It reads your 65 Legacy Challenges from the game, ranks the unfinished ones by how close and how doable they are, and lets you keep an ordered plan with notes.

> Seen working in the game client with live data: the Dashboard, Next steps, Objectives and Planner tabs, and the quest tracker section docked under Questie's tracker (following it as zones expand). The unspent points count has been recorded from the live client, but its chat line and Dashboard row, and the rest of the checklist below, have not been confirmed in game yet.

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
| `/lp reset` | Move the window back to the centre |

The window also opens from the minimap button and the addon compartment. Drag the title bar to move it and the bottom-right corner to resize it; both are remembered.

## Tabs

- **Dashboard** — Legacy Points earned out of 65, any points this character still has to spend, your single best next step, progress per category, recent completions, and a reference list of rewards and perk trees.
- **Next steps** — up to 15 recommendations. Each shows what is left, the activity, an estimated difficulty, and why it is ranked there. Hover for the full breakdown.
- **Objectives** — all challenges by category. Click a category header to collapse it. The search box filters by name, category, profession/class, or requirement.
- **Planner** — challenges you pinned, in your order (Up / Down), each with an optional note. It updates as progress changes and tells you in chat when a pinned challenge completes.
- **Quest tracker section** — your unfinished pinned challenges (3 by default) appear under the quest tracker (Questie's tracker if you use Questie) with their progress lines. Click one to open your plan, click the header to collapse it, drag the header to move it. Forever does not allow Blizzard's own tracking of Legacy challenges, so this is LegacyPath's own section styled to match.
- **Characters** — every character LegacyPath has seen: level, challenges earned on that character, and what it was working on. Other characters are **snapshots** from their last login, dated as such.
- **Settings** — chat messages (completions and unspent points), minimap button, tooltip line, hide completed, quest tracker section (on/off, docked, how many), window scale, and which categories to recommend from.

## How recommendations are ranked

`score = progress (0–100) + 25 if this character can work on it now − 30 if an earlier tier is unfinished + up to 10 for lower estimated difficulty`

- Class challenges for another class are marked as needing that character. If LegacyPath has a snapshot of such an alt, its last-seen level is used and labelled "when last seen".
- Dungeon challenges are not counted as doable until you reach the start of their level band (15, 26, 46).
- "Estimated difficulty" (low / medium / high) is LegacyPath's own rough guide. The addon gives no time estimates.

## Where the data comes from

| Data | Source |
|---|---|
| Challenge names, requirements, completion, criteria progress | Live from the game client (achievement API) |
| Class challenge progress on a matching character | Derived from character level |
| Unspent Legacy Points | Live from the game client, read the same way as the Legacy panel's "Available points" |
| Challenge list, categories | Read from the client on build 1.60.1.70862, checked against the live list at login |
| Difficulty, tier ordering | LegacyPath's own estimates |
| Rewards and perk names | Blizzard's Legacy System post — reference only |

Every challenge tooltip states which of these its progress uses. If a patch adds challenges, they appear automatically under the game's own category.

**Manual mode:** if the client reports no achievement data, LegacyPath says so on the Dashboard and each challenge gets a Done / Undo button instead. Manual ticks are never mixed with live data.

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
2. Dashboard shows the same points and completions as the Legacy panel.
3. Window moves, resizes, rescales, and keeps its place after `/reload`.
4. Pin, reorder, note, and unpin in the Planner; the plan survives `/reload`.
5. Gaining a skill point or level updates progress within about a second, and not during combat.
6. Completing a challenge prints one chat line (and none at login).
7. A second character appears on the Characters tab and the first becomes a dated snapshot.
8. Minimap button shows, drags, hides. The addon compartment entry opens the window.
9. Hovering a Legacy Challenge achievement shows the LegacyPath tooltip line.
10. Pinned challenges appear directly under the quest tracker and follow it as quests are added or removed. Dragging the header undocks it; the Settings toggle docks it again.
11. With points to spend, login prints one reminder and the Dashboard shows the count; it matches the Legacy panel's "Available points", and spending them clears it.
