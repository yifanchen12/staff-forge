# Staff Forge · Seal Workshop

[简体中文](README.md) · [English](README.en.md) · [Security policy](SECURITY.md)

A first-person, single-player staff-crafting demo in a Gothic alchemy workshop, built with **Godot 4.7.2 Standard**, GDScript and the Compatibility renderer. The current in-game interface and narrative are in Simplified Chinese; this README is an English project guide.

## Play the Windows demo

Download **StaffForge-Windows-x64.zip** from [Releases](https://github.com/yifanchen12/staff-forge/releases), extract the entire archive, and run **StaffForge.exe**. Keep StaffForge.pck beside the executable. No Godot installation, account or network connection is required to play.

The repository contains the editable source and selected assets. Executables, engine binaries, download caches and player saves are excluded from Git.

![Upgrade tree in the actual game](docs/images/upgrade-tree.png)
![An astrolabe staff in the actual game](docs/images/staff-astrolabe.png)

## What is playable

- A five-day contract: collect materials, assemble a staff, risk probabilistic infusions, test spells, then offer the staff or exchange it for a relic.
- Three woods, three head types, fire/ice/lightning cores, two runes, adjustable dimensions and wood color.
- Five infusion outcomes: success, great success, stagnation, downgrade and breakage. Charge builds toward a temporary no-break resonance window.
- An upgrade tree at **+3 / +6 / +9**, with seven selectable nodes and **12 combinations**. Choices change real geometry and spell or stability attributes. At +12, the chosen design receives its final crown.
- Downgrades temporarily deactivate branches above the current level; recovering the level restores them. Each choice is permanent for that staff.
- Fire explosions and burning, ice movement slow, and chained lightning against moving training targets.
- Six environmental clues, four narrative chapters and two final choices in a recurrence mystery. Offering staffs with specific attributes advances the story.
- Memories persist across new contracts; inventory, relics and daily progress restart. The main story requires at least three runs. The chosen narrative ending persists on later returns.
- Automatic saving, a backup save, legacy save migration, volume, sensitivity, fullscreen and camera-shake settings.

## Controls

| Input | Action |
|---|---|
| WASD / mouse | Move / look |
| E | Use a nearby station or investigate a clue |
| J | Open the investigation journal |
| T | Open the upgrade tree |
| Tab | Inventory |
| Esc | Leave a station or pause |
| Space | Infuse at the altar / cast at the spell range |
| Left click | UI interaction / aim and cast at the range |
| R | Reset training targets |

Start by collecting materials from the rear-left rack. Investigate the ledger on the small writing table beside it to begin the mystery. The journal explains the next objective; the seal previews whether the equipped staff can trigger a chapter.

## Edit and build

Clone the repository, import project.godot in **Godot 4.7.2 Standard**, then press F5. The project uses GDScript and Compatibility/OpenGL 3.3; no add-ons are required.

On Windows, run from the project directory:

~~~powershell
./tools/build.ps1 -Verify
~~~

The script downloads missing official Godot binaries and export templates, imports the project, runs checks, exports Windows x64, and verifies the standalone executable. The initial template download is approximately 1.2 GB and requires network access. Output: build/windows/StaffForge.exe.

For packaging, install Python 3 and run:

~~~powershell
python tools/package.py
~~~

The script creates Windows and source archives under delivery/ and verifies their ZIP CRCs.

## Project layout

| Path | Responsibility |
|---|---|
| data/balance.json | Economy, materials, probabilities and relics |
| data/chronicle.json | Clues, chapter conditions, endings and upgrade nodes |
| scripts/rules.gd | Canonical crafting, infusion, stats and contract rules |
| scripts/chronicle.gd | Persistent memories, story predicates and branch definitions |
| scripts/staff_visual.gd | Parametric staff geometry and upgrade branches |
| scripts/gothic_scene.gd | Architecture and static decoration batching |
| scripts/environmental_story.gd | Investigable objects and persistent scene changes |
| scripts/spells.gd | Training targets, hits and elemental effects |
| scripts/workshop.gd | Input, stations, transactions and integration checks |
| scripts/ui.gd | Chinese game interface |
| scripts/save_store.gd | Validated saves, atomic replacement, backups and settings |
| tests/ | Rule, visual, story and balance checks |

Memory and current-run state share one save transaction: if saving an offering fails, both item consumption and story advancement roll back. Saves normally live under %APPDATA%\Godot\app_userdata\铸杖模拟器 · 封印工坊\. Verification uses separate test directories.

## Verification and limits

Version 0.3 passed **767 automated checks**: 514 rules/save checks, 73 baseline visual checks, 106 story/branch checks, and 74 standalone scene checks. A fresh extraction of the source archive also passed import and the three unit suites. See the [test record (Chinese)](docs/测试记录.md); detailed reports accompany the Windows release.

A three-second spell-range benchmark measured 189.3 FPS on an i7-14700HX / RTX 4060 Laptop GPU with a 1920×1080 requested window. This is a short, machine-specific measurement, not a minimum-performance guarantee.

The 20–30 minute playtime target, full human narrative playthrough, audio listening quality, long-session performance and other hardware/DPI configurations have not been verified. The existing economy is forgiving. No Steam SDK, cloud saves or multiplayer are included.

## Security and third-party licenses

Use [private vulnerability reporting](https://github.com/yifanchen12/staff-forge/security/advisories/new) for security issues. Do not post credentials, personal saves or unredacted logs in public issues. See [SECURITY.md](SECURITY.md) and its [Chinese version](SECURITY.zh-CN.md).

Bundled third-party resources retain their own licenses: selected Kenney assets are CC0; Noto Sans SC is SIL OFL 1.1. Godot and dependency notices are in [GODOT_LICENSES.txt](docs/GODOT_LICENSES.txt). See [asset attribution](docs/素材来源.md), assets/licenses/ and assets/fonts/OFL.txt. This project does not reuse ForgeTax code, models, textures or audio. No paid Lux3D generation task was used.

No open-source license has currently been designated for this project’s original code or assets. Third-party resources remain governed by their own licenses. The security policy is not a software license.
