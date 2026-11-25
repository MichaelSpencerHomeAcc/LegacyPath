# CurseForge listing — copy into the project form

Not shipped in the addon ZIP.

## Project settings

- **Name:** LegacyPath
- **Game / type:** World of Warcraft / Addons
- **Game version (file upload):** the WoW: Forever version, 1.60.1
- **Release type for 0.1.0:** Beta until it has been tested in game
- **License:** MIT
- **Logo:** `media/logo-400.png`
- **Suggested categories:** Achievements (primary), Quests & Leveling

## Summary (one line)

What should I do next to advance my Legacy? Ranked next steps, a personal plan and character snapshots for WoW: Forever's Legacy Challenges.

## Description

**What should I do next to advance my Legacy?**

LegacyPath reads your 65 Legacy Challenges from the game, ranks the unfinished ones by how close and how doable they are, and tells you why. Pin the ones you care about to a plan, put them in your own order, and add notes.

### Features

- **Next steps** — your unfinished challenges ranked, each showing what is left, the activity, a rough difficulty, and the reason it is ranked there.
- **Dashboard** — Legacy Points out of 65, your single best next step, progress per category and recent completions.
- **Objectives** — every challenge by category, with search and collapsible categories.
- **Planner** — pinned challenges in your order, with notes. A chat message tells you when one completes.
- **Quest tracker** — your pinned challenges and their progress, right under the quest tracker.
- **Unspent points reminder** — tells you when a character has Legacy Points to spend.
- **Characters** — level, challenges earned and progress for each character you log in with, clearly dated as a snapshot.
- Movable, resizable and scalable window, optional minimap button, addon compartment entry, and a short line on Legacy Challenge achievement tooltips.

### Honest data

- Progress comes live from the game client. Class challenges on a matching character are worked out from your level and labelled as such.
- Every challenge's tooltip says where its progress comes from.
- Difficulty is LegacyPath's own rough guide. There are no made-up time estimates.
- Reward unlock thresholds and perk costs are not published by Blizzard, so they are not shown.
- If the game reports no challenge data, LegacyPath says so and lets you tick challenges off by hand instead of guessing.

### Commands

- `/lp` or `/legacypath` — open or close the window
- `/lp next` — print your top three next steps
- `/lp scale 0.6`–`1.6` — window scale
- `/lp minimap` — show or hide the minimap button
- `/lp reset` — move the window back to the centre

### Works well with

LegacyPath has no map pins. For pins and zone guidance, use Legacy Forever alongside it.

### Limitations

English only. Other characters' progress is as fresh as their last login. Hardcore is not handled yet.

No libraries required. Your data stays in your SavedVariables; nothing is sent anywhere.
