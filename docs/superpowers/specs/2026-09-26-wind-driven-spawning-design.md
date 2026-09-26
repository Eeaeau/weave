# Wind-driven spawning design

## Intent and scope

After both players have acted, a new round begins with a wind event. Players wait and watch a small group of weapons and insects blow from the background toward their webs. The changing paths and near misses build suspense; players cannot steer or predict the contact point during the event. This feature spawns and animates collectibles and reports where they reach the map's web plane. The teammate's triangle-based web system will decide whether a reported contact is caught.

This work stays on `feature/wind-driven-spawning`. It does not implement turns, spider movement, weapons, inventory, or web collision.

## Approach

Use map-authored spawn lanes with randomized curved flights. Fixed animations would repeat, while free physics would make balanced opportunities and exact plane contacts difficult to control. The wind event samples a hidden contact point and a curved path for each item. Gentle side-to-side sway and small vertical changes make the motion look windblown. Perspective makes distant sprites grow as they approach. There is no target marker or other advance cue for players.

Each flight crosses the map's horizontal web plane once at its sampled point, then continues toward the camera if another system has not claimed it. The existing starting webs lie near `y = 0.1`; the new map plane marker defines the actual transform and bounds so this value is not hard-coded into the flight logic. Map-authored regions identify the two players' sides. The crossing report contains the collectible node, side, plane-local `Vector2` contact point, and world-space `Vector3` contact point. It fires once per item. It does not report a catch or change inventory. The web system may call `WindEvent3D.claim(item, target_parent)` from that signal; a successful claim keeps the item's world transform, moves it under `target_parent`, and ends its flight without destroying it.

## Event and spawn flow

`start_round(round_number)` is the integration entry point. The future turn controller calls it after both players act, including the first completed pair of turns. While the event is active, it exposes `is_active` and emits start and finish signals. Future movement controls must use that state to block actions until the finish signal; this branch cannot wire the guard because no turn or movement controller exists yet. A separate preview scene starts an event for visual and audio review without changing match rules. `reset_match(seed)` resets the side bag and random streams at match start. Empty events finish on the next event tick, after `start_round()` returns.

The first version sends three items per event, about 0.8 seconds apart. Each flight takes about 7–9 seconds, so their approaches overlap without hiding each other. Count and timing are editable. A shuffled bag of six side entries, three per player, selects spawn opportunities: a single round can favor either side, but every completed bag gives both sides the same number of opportunities. The bag persists across rounds and resets at match start. It tracks spawns, not catches. Within a side, the event selects an authored lane and randomizes the contact point, curve, sway, and flight time. Both sides use the same item rarity rules.

Weapons and insects use the existing `Collectible3D` base and data resources. An editable wind spawn table names each scene and data resource, its selection weight, earliest round, and weight growth with later rounds. The initial table uses Pebble and Silk Moth as common round-one entries, Twig Cutter from round three, and Health Beetle from round five. The later entries start with lower weights that increase each round. These are tuning defaults, not weapon or insect gameplay rules; their current sprites can remain placeholders.

The event finishes after its last flight has passed the web plane and left the view. It releases its active state once, even if a spawned node is removed early. A second start request while the event is active is ignored with a warning. Empty or invalid spawn entries are skipped with a clear editor warning; if nothing can spawn, the event finishes instead of holding the match in a wind phase.

## Audio

The map owns ambience on the existing `SFX` bus. The initial forest bed is `eryliaa-forest-wind-with-birds-singing-364368.mp3`; the soft wind layer is `storegraphic-soft-wind-318856.mp3`. The forest bed crossfades at loop boundaries. Soft wind fades in and out at varied intervals and levels so the combined sound does not repeat on a fixed short cycle.

The wind event owns one stronger gust for the whole group, starting as the first item appears and fading out when the group is over. The initial event clip is `dragon-studio-harsh-wind-515272.mp3`, whose roughly 13-second duration fits a staggered group. Audio streams and mix levels remain editable for later tuning. Imported files are recorded in `ATTRIBUTION.md` with creator, source, license, and any edits. Ambient playback continues underneath the gust.

## Boundaries and verification

The map provides side regions, spawn lanes, and the web-plane transform. The wind event handles scheduling, fair side selection, rarity selection, group audio, and lifecycle signals. A flight handles one collectible's motion and plane-crossing report. Neither the map nor the wind event inspects web triangles.

Tests use a fixed random seed to check group size, staggered spawn and finish order, one crossing report per item, valid plane-local/world coordinates, delayed rarity eligibility, and equal side opportunities after a full shuffled bag. A preview scene checks that sprites travel from background to foreground with gentle sway and that the gust covers the group while ambient layers continue. The existing local check script must still pass on Godot 4.7.
