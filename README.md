# Weave

A turn based jam project inspired by worms, but with spiders building webs between branches.

## Project layout

```text
project.godot
src/
  game/                         Match composition root
  features/
    spiders/                    BaseSpider3D and inherited player/opponent sprite scenes
    collectibles/               Shared collectible scene and data parents
      insects/                  Insect data and windborne placeholder
      weapons/                  Weapon data and windborne placeholder
    web/                        WebStrand3D sprite placeholder
    world/maps/branch_canopy/   Layered tree sprites, camera, and branch start markers
    ui/                         Title, settings, input, pause, game over, match HUD
assets/                          Assets shared across features
addons/                          Optional Godot plugins
docs/                            Settings and deployment notes
tests/                           Godot smoke checks
tools/                           Local quality checker
```

Keep a scene, its script, and assets used only by that scene in one feature folder. This lets a feature move or be removed without chasing files across the project. Use top-level `assets/` for files shared by several features. Empty placeholder folders contain `.gitkeep` so they remain visible in Git.

The match uses 3D positions and a perspective camera, but its visible objects are flat `Sprite3D` nodes with 2D SVG placeholder art. `BaseSpider3D` is the shared spider scene and script. Player and opponent scenes inherit it, giving each a clear place for later controls or AI. Weapons and insects both inherit `CollectibleData` and `Collectible3D`. Weapon and insect resources are examples; spawning, catching, and effects are not connected. `WebStrand3D` exposes endpoints and durability as editable data, but no damage behavior is connected. The camera sways gently to show parallax between foreground branches and distant foliage. The map's `BackgroundMusic` node has no stream assigned yet.

The scene coordinates and art are disposable placeholders. Planned work is tracked in [GitHub Issues](https://github.com/Eeaeau/weave/issues) and the [Weave board](https://github.com/users/Eeaeau/projects/3/views/2).

## Local checks and export

Run `python tools/check.py` on Windows, Linux, or macOS. It finds Godot on common paths, downloads a pinned and checksum-verified gdstyle binary on first use, checks GDScript formatting and warnings, imports the project, loads resources, and runs scene and menu smoke checks. Python and Godot must already be installed. Pass `--godot /path/to/godot` if needed. The download and check outputs live under ignored `build/`.

The Web export preset and manual itch.io workflow are carried over from the template. They will become usable after the project is published and itch.io variables are configured; see [itch deployment](docs/itch_deploy.md). GitHub quality checks run on pull requests or manually, while local checks are available for every edit. Godot's `.godot/` cache and other machine-specific files are ignored.
