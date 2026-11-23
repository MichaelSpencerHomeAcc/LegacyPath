# LegacyPath

**What should I do next to advance my Legacy?** A World of Warcraft: Forever addon that reads your 65 Legacy Challenges from the game, ranks your next steps with reasons, keeps a personal plan, and shows pinned challenges under the quest tracker.

![Next steps](media/Next%20Steps.PNG)

- **Players:** install from CurseForge, or copy the `LegacyPath` folder into `World of Warcraft\_forever_\Interface\AddOns`. Usage, commands and limitations are in [LegacyPath/README.md](LegacyPath/README.md).
- **What the game exposes and how it was verified:** [RESEARCH.md](RESEARCH.md).

## Repository layout

| Path | What |
|---|---|
| `LegacyPath/` | The addon (this folder is what ships) |
| `LegacyPathProbe/` | One-off diagnostic addon used to read Legacy data from the client |
| `tests/` | Logic tests and a UI smoke test that run outside the game |
| `tools/package.ps1` | Builds `dist/LegacyPath-<version>.zip` |
| `media/` | Logo and screenshots |

## Development

```
luajit tests/run.lua
luajit tests/ui_smoke.lua
powershell -File tools/package.ps1
```

MIT licensed — see [LegacyPath/LICENSE.txt](LegacyPath/LICENSE.txt).
