# Settings menu

Settings opens the same four-section hub from the title and pause menus. Every section has a title and a Back button; Escape or gamepad Start follows the same route back. The hub keeps focus on the section just visited so keyboard and gamepad navigation stays predictable.

| Section | Included example | Where to extend it |
| --- | --- | --- |
| General | Show scene hints in the HUD | `settings_menu.tscn`, `settings_menu.gd`, `match_hud.gd` |
| Display | Window mode, windowed size, FPS limit | `settings_menu.tscn`, `settings_menu.gd` |
| Audio | Master, Music, SFX levels | `settings_menu.tscn`, `settings_menu.gd`, `default_bus_layout.tres` |
| Input | Current actions, remapping, reset | `controls_menu.tscn`, `controls_menu.gd`, `project.godot` |

The Input page currently lists Pause only, because movement and abilities are not implemented. Add their actions and default bindings to `project.godot` when those mechanics exist, then update the `ACTIONS` list in `controls_menu.gd`. Add real game settings to General as they become useful. If the game introduces dialogue or chat audio, add a bus and slider for it.

The project uses a compact hierarchy instead of bundling a menu framework: **Settings → section → Back → Settings**. This follows the clear hierarchy and consistent navigation advice in [Xbox Accessibility Guideline 114](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/114) and [Guideline 112](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/112). Separate Audio, Display, and Input categories are also used in [Maaack's Options Menu Setup](https://github.com/Maaack/Godot-Menus-Template/blob/main/addons/maaacks_menus_template/docs/OptionsMenuSetup.md). The separate audio sliders follow [Guideline 105](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/105).
