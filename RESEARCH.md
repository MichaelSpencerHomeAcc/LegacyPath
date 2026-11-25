# LegacyPath — research (Phase 1)

Status: **2026-11-09.** Legacy data was verified by running `LegacyPathProbe` in the live client
(build 1.60.1.70862, level 27 Warlock). The LegacyPath addon itself has not been run in the client yet.

Confidence labels: **Verified** (read from the client by the probe), **Official** (Blizzard post),
**Reported** (third-party source), **Unverified**.

## Game and client

| Fact | Value | Confidence |
|---|---|---|
| TOC Interface | `16001` | Verified (`GetBuildInfo`) |
| Build | 1.60.1.70862, 6 Nov 2026 | Verified |
| Launch | 4 Nov 2026 | Reported |
| `issecretvalue` exists | yes | Verified |
| API family | Modern (12.1.5-based); `GetSpellInfo`, `GetItemInfo`, `GetAddOnMetadata` globals removed | Reported |
| Combat log | Unavailable to addons | Reported (LegacyPath does not use it) |

## Legacy system

- **65 Legacy Challenges, 1 point each** — Verified. The probe found exactly 65 achievements that award Legacy Points, out of 111 in the achievement list.
- Categories and counts — Verified, and they match Blizzard's post:
  Classes 27 (9 classes × level 25/45/60), Tradeskills 18 (6 professions × 150/225/300),
  Player vs. Player 12 (5 ranks, 4 battleground reputations, 3 Season Journey weeks),
  Dungeons 3, Raids 3, Adventure 2.
- Names, IDs and requirement text of all 65 — Verified; they are the basis of `Database/Objectives.lua`.
- Dungeon level bands 15–25 / 26–45 / 46–60 — Official.
- Per-character spend cap of 16 points — Official.
- Perk names (3 trees × 7) and the four rewards — Official. **Perk costs and reward thresholds are not published.**
- Hardcore: not at launch; not handled.

## Addon API

| Question | Answer | Confidence |
|---|---|---|
| Is there a `C_Legacy` namespace? | No. Legacy globals are UI helpers only (`ToggleLegacySystemUI`, `ShowLegacyChallenge`, …) | Verified |
| How are challenges exposed? | As achievements: `GetCategoryList`, `GetCategoryNumAchievements`, `GetAchievementInfo`, `GetAchievementNumCriteria`, `GetAchievementCriteriaInfo` | Verified |
| Which achievements are challenges? | `C_Traits.GetTraitCurrencyForAchievement(Constants.LegacyConsts.LEGACY_POINTS_TRAIT_CURRENCY_ID, id) > 0` (currency 4225) | Verified |
| Account vs character completion | Completion and criteria are account-wide. Return 13 ("earned by this character") is **not** usable for Legacy: four level 1 characters (Priest, Rogue, Paladin, Warrior) each reported 6-7 challenges as theirs, and the same 204/225 Tailoring and dungeon progress as the main. Dungeon progress pooling across two characters was also confirmed by the player. An earlier version of these notes wrongly listed return 13 as per-character | Verified from saved data |
| Per-character profession skill | `GetProfessions` and `GetProfessionInfo` (return 3 rank, return 7 skill line), as Forever's own profession window reads them | Verified: a level 58 Warlock recorded Tailoring 204 and Enchanting 266 under skill lines 197 and 333 |
| Names | `UnitName("player")` returns first name and surname as two values (Forever `NameUtil.lua`); `GetRealmName()` now returns an empty string, and earlier builds returned a realm | Blizzard source; realm change verified in saved data |
| Criteria progress | Tradeskills report skill (e.g. 135 / 150). Dungeons and raids list each boss. Reputations report 0 / 42000. Class, rank, quest-line and Onyxia challenges have **no criteria** | Verified |
| Class challenge progress | Not reported; LegacyPath derives it from character level and labels it "derived" | By design |
| Reward track | Faction 2802 via `C_MajorFactions`; renown level readable, but `GetRenownRewardsForLevel` returned nothing | Verified — thresholds unavailable |
| Legacy Point total | `C_CurrencyInfo.GetCurrencyInfo(4225)` returned nil; LegacyPath counts completed challenges instead | Verified |
| Unspent points | Blizzard's Legacy panel (`Blizzard_LegacySystemUtil.lua`, Forever UI source mirrored at Gethe/wow-ui-source `forever`) reads `C_Traits.GetTreeCurrencyInfo(C_Traits.GetConfigIDByTreeID(LEGACY_TREE_PROFESSIONS_ID), treeID, false)[1]`: `quantity` is "Available points", `maxQuantity` the seasonal spend cap | Blizzard source; the call returns values in the live client (0 and 7 recorded on two characters), not yet compared with the panel |
| Change events | `ACHIEVEMENT_EARNED`, `CRITERIA_UPDATE`, `RECEIVED_ACHIEVEMENT_LIST` | Reported (API reference); not yet observed firing |
| Achievement tooltip hook | `TooltipDataProcessor` with `Enum.TooltipDataType.Achievement` | Unverified in Forever; skipped if absent |

What needs a maintained database: the challenge list for manual mode, difficulty estimates, tier ordering,
dungeon level bands, rewards and perks reference. Everything else is read live.

## Existing addons

| Addon | Covers |
|---|---|
| Legacy Forever | Map pins, zone completion, objective tracker |
| Hated Legacy | Challenge list, perk spending view, reward track, PvP rank card |
| Chart My Legacy | Which alt to play next, 16-point perk builds, rested XP alerts |

LegacyPath's niche: a scored "what next" list with reasons, an ordered personal plan with notes, and dated per-character snapshots.
Legacy Forever's source was read only to learn which API calls expose Legacy data; no code or data was copied.

## Decisions

- Scope: challenges only. Perks and rewards are a read-only reference with no costs or thresholds.
- All game access goes through `Systems/APIAdapter.lua`; tests replace it with a mock.
- If the achievement API is missing, LegacyPath switches to manual ticking rather than showing guessed progress.
- No external libraries.

## Not verified

- The addon running in the client (see README "Testing status").
- Whether PvP rank, reputation, raid and adventure criteria are also account-wide; LegacyPath makes no claim about them.
- Whether criteria quantities are ever secret values; the adapter treats a secret as "no data".

## Sources

- https://worldofwarcraft.blizzard.com/en-us/news/24307383
- https://maxroll.gg/wow-forever/news/wow-forevers-legacy-system-rewards-progress-across-your-account
- https://github.com/cjber/legacy-forever
- https://github.com/Atraeau/WoW-Addons
- https://wowforeverguides.com/addons/api-cheatsheet
- https://www.curseforge.com/wow/addons/hated-legacy , https://www.curseforge.com/wow/addons/chart-my-legacy
