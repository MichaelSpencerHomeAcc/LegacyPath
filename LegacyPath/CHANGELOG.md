# Changelog

## 0.3.1 — 2026-11-25

- Fixed: challenge progress and completions are account-wide, but LegacyPath showed them as belonging to each character. The Characters tab listed the account's challenges as "earned here" on every alt, tooltips could say "Earned on this character" wrongly, and recommendations could claim the current character could work on a profession it does not have. The wrong saved values are removed automatically.
- New: class and profession challenges name your closest character, in recommendations, tooltips, the planner and the quest tracker section ("204/225 Tailoring Skill (Name)"). Log in to each character once so LegacyPath can record its professions.
- The Characters tab shows each character's real professions, unspent points and the challenges it is closest to.
- Characters show their first and last names, and two characters with the same first name no longer overwrite each other. Characters saved twice since Forever dropped realm names are merged, keeping the newest; one saved under a first name only is replaced when you next log in to it.
- The unspent points reminder is now a bubble pointing at the Legacy button on the micro menu (a chat line if that button is hidden). It closes when you dismiss it, open the Legacy panel or spend the points. `/lp points` shows it on demand.
- The reminder appears at every login, and when you have more points to spend, but no longer after a `/reload`.

## 0.3.0 — 2026-11-25

- Unspent Legacy Points reminder: one chat line at login (and when you earn more) if this character has points to spend, a line on the Dashboard, and the count per character on the Characters tab. Can be turned off in Settings.

## 0.2.0 — 2026-11-23

- Quest tracker section: your unfinished pinned challenges with live progress, right under the quest tracker. Docks under Questie's tracker when you use Questie. Click a challenge to open your plan, click the header to collapse it, drag it to move it. Settings let you turn it off, re-dock it and show 1–5 challenges.
- Skill progress reads "204/225 Tailoring Skill" instead of repeating the number.

## 0.1.0 — 2026-11-09

First version. Not yet run in the game client.

- Dashboard: Legacy Points, best next step, category progress, recent completions, rewards and perks reference.
- Next steps: ranked recommendations with what is left, estimated difficulty and reasons.
- Objectives browser with search and collapsible categories.
- Planner: pinned challenges, custom order, notes, completion messages.
- Characters: per-character snapshots, clearly dated.
- Settings, minimap button, addon compartment entry, achievement tooltip line.
- Live data from the client's achievement API; manual tracking when it is unavailable.
- Versioned SavedVariables with migration support.
