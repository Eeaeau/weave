# Spiders

A turn based jam project inspired by worms, but with spiders building webs between branches.

## Project layout

```text
project.godot
src/
  game/                         Match composition root
  features/
    spiders/                    Spider scenes, movement, and leg animation
    collectibles/               Shared collectible scene and data parents
      insects/                  Catchable insects and silk refills
      weapons/                  Equippable weapons and projectiles
    web/                        Web nodes, strands, and triangle surfaces
    world/maps/branch_canopy/   Branches, layered backgrounds, camera, and wind
    ui/                         Title, settings, input, pause, game over, match HUD
assets/                          Assets shared across features
addons/                          Optional Godot plugins
docs/                            Settings and deployment notes
tests/                           Godot smoke checks
tools/                           Local quality checker
```

Keep a scene, its script, and assets used only by that scene in one feature folder. This lets a feature move or be removed without chasing files across the project. Use top-level `assets/` for files shared by several features. Empty placeholder folders contain `.gitkeep` so they remain visible in Git.

The match plays in world X/Y: X is horizontal, Y is vertical, and Z provides depth for the 2.5D presentation. Its visible objects are flat `Sprite3D` nodes. The camera uses orthographic zoom at a fixed depth; background layers move by different amounts during pans to retain parallax. Spiders can traverse and build webs, and wind events carry collectible weapons and insects toward them. `BaseSpider3D` is the shared spider scene, while weapons and insects share `CollectibleData` and `Collectible3D` parents.

To edit a branch, open `src/features/world/maps/branch_canopy/branch_web.tscn`. It contains the assembled `branch_visual.tscn`, the web anchor markers, and the starting web edges, so you can place anchors and see the initial web against the artwork. Select two `WebAnchors` markers in the Scene tree or 3D viewport, then use **Project > Tools > Connect Selected Web Anchors**; the matching Remove command deletes an edge. Both support Undo. Edit `branch_visual.tscn` to rearrange the shared sprites. Branch Canopy instances `branch_web.tscn` twice and mirrors the right instance. Coloured editor-only rings show every anchor without selecting it. Add new markers at the end of `WebAnchors` so existing strand indices remain stable. Each player's runtime web also sees the other branch's anchors, allowing strands to cross between them. To set where windborne items enter and cross the web, select `WindEvent/WebPlane/LeftDropArea` or `RightDropArea` in Branch Canopy and move, rotate, or scale each editor-visible rectangle independently.

Planned work is tracked in [GitHub Issues](https://github.com/Eeaeau/weave/issues) and the [project board](https://github.com/users/Eeaeau/projects/3/views/2).

## Local checks and export

Run `python tools/check.py` on Windows, Linux, or macOS. It finds Godot on common paths, downloads a pinned and checksum-verified gdstyle binary on first use, checks GDScript formatting and warnings, imports the project, loads resources, and runs scene and menu smoke checks. Python and Godot must already be installed. Pass `--godot /path/to/godot` if needed. The download and check outputs live under ignored `build/`.

The Web export preset and manual itch.io workflow are carried over from the template. They will become usable after the project is published and itch.io variables are configured; see [itch deployment](docs/itch_deploy.md). GitHub quality checks run on pull requests or manually, while local checks are available for every edit. Godot's `.godot/` cache and other machine-specific files are ignored.
