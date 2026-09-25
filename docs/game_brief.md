# Weave: first scene brief

**Theme:** Weave. **Perspective:** top-down 2D for the first version, with the option to revisit 3D later.

The game idea is a Worms-inspired contest between spiders. Each player begins on a separate tree branch with a simple web. Players should eventually build paths between branches, move across the web, damage strands, and catch weapons carried by the wind when their web is placed well.

## What this revision shows

- A separate `WebMatch2D` scene and `BranchCanopy2D` map with named start markers.
- Two inherited spider scenes and two authored starting webs.
- Reusable strand data, two weapon data examples, and a windborne weapon visual.
- The title, settings, pause, and input menus from the template.

These are **layout and code structure examples**, not implemented gameplay. The opponent does not move; webs are not destructible; the weapon does not drift or get caught. `GameOverMenu` is retained as an optional UI example but is not wired into the scene.

## Decisions for the team

- Choose turn order, player count, and whether play is local, online, or both.
- Define how spiders traverse branches and strands, and how new strands attach.
- Decide what cuts a strand, what happens when support disappears, and how a match ends.
- Define wind direction, weapon arrival rate, catch rules, and the first useful weapon set.
- Replace placeholder shapes and choose music. Keep audio on the existing `Music` and `SFX` buses.

Keep gameplay rules out of the shared spider and weapon data classes until those choices are made. A later 3D experiment can reuse data and menus while replacing the 2D actor, map, and strand scenes.
