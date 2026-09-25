# Weave

A Godot 4.7.2 game jam project about spiders building webs between branches. This first revision is a **2D scene scaffold**: the title menu opens a tree canopy with two branch starts, two inherited spider placeholders, two simple webs, and a windborne weapon marker. It does not implement movement, turns, web damage, wind, weapon collection, or combat yet.

## Open and inspect

1. Import `project.godot` in Godot 4.7.2.
2. Press **F5** for the title menu and **Play** for the 2D scene. Press **Escape** or gamepad **Start** to pause.
3. Open `src/game/web_match.tscn` in the editor to inspect the composition. The map is `src/features/world/maps/branch_canopy/branch_canopy.tscn`.

The Settings menu remains from the template. General controls scene hints; Display includes window mode, resolution, and frame limit; Audio has Master, Music, and SFX buses; Input currently lists only **Pause**, the one mapped game action. Add movement and ability bindings when their behavior is implemented.

## Project layout

```text
project.godot
src/
  game/                         Match composition root
  features/
    spiders/                    BaseSpider2D and inherited player/opponent scenes
    web/                        WebStrand2D placeholder
    weapons/                    WeaponData, two inherited types, windborne marker
    world/maps/branch_canopy/   2D tree map and branch start markers
    ui/                         Title, settings, input, pause, game over, match HUD
assets/                          Assets shared across features
addons/                          Optional Godot plugins
docs/                            Game brief, settings, release notes
tests/                           Godot smoke checks
tools/                           Local quality checker
```

Keep a scene, its script, and assets used only by that scene in one feature folder. This lets a feature move or be removed without chasing files across the project. Use top-level `assets/` for files shared by several features. Empty placeholder folders contain `.gitkeep` so they remain visible in Git.

`BaseSpider2D` is the shared spider scene and script. Player and opponent scenes inherit it, giving each a clear place for later controls or AI. `WeaponData` is a shared Resource class; `ThrownWeaponData` and `WebToolData` inherit it, with `pebble.tres` and `twig_cutter.tres` as examples. `WebStrand2D` exposes endpoints and durability as editable data, but no damage behavior is connected. The map's `BackgroundMusic` node has no stream assigned yet.

The scene coordinates and art are disposable placeholders. See [the game brief](docs/game_brief.md) for the intended direction and the choices still open.

## Local checks and export

Run `python tools/check.py` on Windows, Linux, or macOS. It finds Godot 4.7 on common paths, downloads a pinned and checksum-verified gdstyle binary on first use, checks GDScript formatting and warnings, imports the project, loads resources, and runs scene and menu smoke checks. Python and Godot must already be installed. Pass `--godot /path/to/godot` if needed. The download and check outputs live under ignored `build/`.

The Web export preset and manual itch.io workflow are carried over from the template. They will become usable after the project is published and itch.io variables are configured; see [itch deployment](docs/itch_deploy.md). GitHub quality checks run on pull requests or manually, while local checks are available for every edit. Godot's `.godot/` cache and other machine-specific files are ignored.

This repository started from the team's [Godot game jam template](https://github.com/Eeaeau/godot-gamejam-starter), with its menu and project tooling adapted to Weave. Review [attribution](ATTRIBUTION.md) as assets are added.
