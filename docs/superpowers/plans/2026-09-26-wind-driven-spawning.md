# Wind-Driven Spawning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spawn a suspenseful group of windblown weapons and insects after each completed pair of player turns, with a precise web-plane contact handoff and layered wind audio.

**Architecture:** A wind event node owns one round's schedule, item selection, and lifecycle. Map-local lanes define start positions and web-plane regions; each flight moves one existing `Collectible3D` scene and reports one contact. The canopy map owns ambient audio, while the event owns its gust.

**Tech Stack:** Godot 4.7, GDScript, `Sprite3D`, `AudioStreamPlayer`, headless `SceneTree` smoke tests, `tools/check.py`.

**Spec:** `docs/superpowers/specs/2026-09-26-wind-driven-spawning-design.md`

## Global Constraints

- Work only on `feature/wind-driven-spawning`; preserve the user's local `main` checkout and `project.godot` edit.
- Keep web triangle collision, inventory, turns, and movement controls out of this branch. The event exposes state/signals for those future systems.
- Use the existing `Collectible3D` inheritance and 2D sprites in the 3D scene.
- Default group: three items, about 0.8 seconds apart; each flight lasts 7–9 seconds.
- Keep the contact target hidden from players. Report its plane-local `Vector2` and world-space `Vector3` once.
- Use the existing `SFX` bus. Import the three approved local MP3s from Downloads and record their Pixabay source pages in `ATTRIBUTION.md`.

## Review Focus

- A second `start_round()` while active must leave one event and one finish signal; Task 3 tests this.
- A round with no eligible entries must end promptly and release `is_active`; Task 3 tests this.
- Removing a flight early must not leave the event active forever; Task 3 tests this.
- A moved or rotated map plane must still report matching local and world contact coordinates; Task 2 tests this.
- An odd-sized group may favor one side, but six selected sides must contain three of each; Task 1 tests this.

---

### Task 1: Fair side and rarity selection

**Files:** Create `src/features/wind/wind_spawn_entry.gd`, `src/features/wind/wind_selection.gd`, `tests/wind_selection_smoke.gd`; modify `tools/check.py` to run the new smoke test.

**Interfaces:** `WindSpawnEntry` exports `scene: PackedScene`, `data: CollectibleData`, `base_weight: float`, `earliest_round: int`, `weight_growth_per_round: float`; `weight_at(round_number: int) -> float` returns zero before unlock. `WindSelection.reset(seed: int) -> void`, `next_side() -> int` (`0` left, `1` right), and `choose_entry(round_number: int, entries: Array[WindSpawnEntry]) -> WindSpawnEntry` use one seeded `RandomNumberGenerator`; the last method returns `null` when no valid entry is eligible.

- [ ] **Step 1: Write failing selection smoke test.** Assert six `next_side()` calls contain three zeros and three ones, and `reset(seed)` reproduces the same order. Assert Pebble and Silk Moth are eligible at round one; Twig Cutter first at round three; Health Beetle first at round five; later weights increase; empty and invalid lists return `null`.
- [ ] **Step 2: Run the test and confirm failure.** Use `& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/wind_selection_smoke.gd`; expect missing classes or test failure.
- [ ] **Step 3: Implement the two scripts and initial table data.** Place the four editable `.tres` entries under `src/features/wind/entries/`. Use existing weapon/insect scenes and data; placeholder art is acceptable. Give common entries `base_weight = 10`, `earliest_round = 1`, growth `0`; later entries `base_weight = 1`, growth `1` from their respective unlock rounds. A bag contains `[0, 0, 0, 1, 1, 1]`, shuffled on refill.
- [ ] **Step 4: Run the selection test to its `WIND SELECTION PASS:` marker, then `python tools/check.py --gdstyle 'C:\Users\sebsk\source\weave\build\tools\gdstyle.exe'`.** Confirm both exit zero.
- [ ] **Step 5: Commit** the selection scripts, entries, test, and check runner.

### Task 2: Curved flight and map-plane contact

**Files:** Create `src/features/wind/wind_lane.gd`, `src/features/wind/wind_flight.gd`, `tests/wind_flight_smoke.gd`; modify `tools/check.py` to run the test.

**Interfaces:** `WindLane3D` is a `Marker3D` with `side: int` and `contact_rect: Rect2` in the web plane's local X/Z axes. `WindFlight3D.configure(item: Collectible3D, path_points: PackedVector3Array, duration: float, sway: float) -> void` parents the item; `path_points` contains start, web contact, and exit in that order. It emits `plane_crossed(item: Collectible3D, world_point: Vector3)` exactly once and `finished` once; `advance(delta: float) -> void` lets the test step time without waiting for wall time.

- [ ] **Step 1: Write failing flight smoke test.** With a transformed plane and a chosen local point `(x, z)`, assert the reported world point maps back to that local point. Advance in small steps through 7–9 seconds; assert one crossing, one finish, background-to-foreground Z travel, and visible lateral motion with `sway > 0`. Advance again and assert no duplicate signals. Remove the item early and assert the flight finishes.
- [ ] **Step 2: Run `wind_flight_smoke.gd`; confirm it fails.** Use the Godot command from Task 1 with this test path.
- [ ] **Step 3: Implement the two focused scripts.** Sample a curved pre-contact path ending exactly at the contact point, then an exit curve toward the camera. Apply smooth, bounded sway that reaches zero at contact. Keep the sampled destination hidden; the flight script never inspects webs.
- [ ] **Step 4: Run the flight test to `WIND FLIGHT PASS:` and the full local checks; confirm exit zero.**
- [ ] **Step 5: Commit** the lane, flight, test, and check-runner changes.

### Task 3: Round wind event and preview

**Files:** Create `src/features/wind/wind_event.gd`, `src/features/wind/wind_event.tscn`, `src/features/wind/wind_preview.gd`, `src/features/wind/wind_preview.tscn`, `tests/wind_event_smoke.gd`; modify `src/features/world/maps/branch_canopy/branch_canopy.tscn` and `tools/check.py`.

**Interfaces:** `WindEvent3D.start_round(round_number: int) -> void`, `is_active: bool`, `event_started(round_number: int)`, `item_contact(item: Collectible3D, side: int, local_point: Vector2, world_point: Vector3)`, and `event_finished(round_number: int)`. The `WindEvent` scene contains a `WebPlane` marker, left/right `WindLane3D` markers, and a flight container. The local point maps the plane's X/Z axes to `Vector2(x, z)`. `WindEvent3D` consumes Task 1 selection and Task 2 flights. `wind_preview.tscn` instantiates the match with its starting webs, hides static collectible placeholders, calls `start_round(1)` at scene start, and logs contact and finish signals; regular `web_match.tscn` does not auto-start it.

- [ ] **Step 1: Write failing event smoke test.** Assert three staggered items, one contact each, the `(local.x, local.z)` projection of the world contact, `is_active` true until the group ends, one finish signal, duplicate starts ignored, and a no-eligible-entry event finishing promptly. Remove one active flight and assert the event still finishes.
- [ ] **Step 2: Run `wind_event_smoke.gd`; confirm it fails.** Use the Godot command from Task 1 with this test path.
- [ ] **Step 3: Implement the event scene and script; instance it in `branch_canopy.tscn`.** Author left/right lanes and contact rectangles around the existing starting webs; spawn behind the map and exit toward the camera. Keep event timing exported. Add the isolated preview scene and script.
- [ ] **Step 4: Run the event test to `WIND EVENT PASS:` and the full local checks; confirm exit zero.** Launch `wind_preview.tscn` in Godot for a visual pass of suspense, sway, contact area, and visibility.
- [ ] **Step 5: Commit** the event, map, preview, test, and check-runner changes.

### Task 4: Ambient layers, event gust, and attribution

**Files:** Create `src/features/world/maps/branch_canopy/canopy_ambience.gd`; add the forest and soft-wind MP3s under that map's `assets/audio/`; add the harsh-wind MP3 under `src/features/wind/assets/audio/`; modify `branch_canopy.tscn`, `wind_event.tscn`, `wind_event.gd`, `ATTRIBUTION.md`, `tests/wind_event_smoke.gd`.

**Interfaces:** `CanopyAmbience` owns `ForestA`, `ForestB`, and `SoftWind` players on the `SFX` bus. It starts a quiet forest bed, crossfades its loop, and varies the soft wind's intervals and levels. `WindEvent3D` owns a `Gust` player on `SFX`, starts it at the first spawn, and fades it when the group finishes. Forest, soft-wind, gust, and fade levels are exported for tuning. Missing streams leave the event lifecycle functional and produce a warning.

- [ ] **Step 1: Extend the failing event test.** Assert ambience and gust players use `SFX`; a three-item event starts the gust once, leaves ambience playing, and stops/fades the gust by finish. Use a short test stream to verify the forest alternates players at a loop boundary; seeded soft-wind intervals must not all be identical. Repeat with a missing gust stream and assert `event_finished` still fires.
- [ ] **Step 2: Run `wind_event_smoke.gd`; confirm the new audio assertions fail.**
- [ ] **Step 3: Copy the three local MP3s, wire players and fades, and add three `ATTRIBUTION.md` rows.** Source pages: `https://pixabay.com/sound-effects/nature-forest-wind-with-birds-singing-364368/`, `https://pixabay.com/sound-effects/nature-soft-wind-318856/`, and `https://pixabay.com/sound-effects/nature-harsh-wind-515272/`; license: `https://pixabay.com/service/license-summary/`.
- [ ] **Step 4: Run the event test and full local checks; confirm exit zero.** Play the preview scene and listen for a quiet, varying bed and one gust over the whole group.
- [ ] **Step 5: Commit** audio, attribution, ambience, and test changes.

### Task 5: Final integration review

**Files:** Modify only the files required by failures discovered here; update the design or plan if an interface changes.

- [ ] **Step 1: Re-read the spec and inspect the branch diff.** Check round-start/finish, hidden contact, left/right balance, delayed rarity, sprite motion, audio, and no web catch logic.
- [ ] **Step 2: Run `python tools/check.py --gdstyle 'C:\Users\sebsk\source\weave\build\tools\gdstyle.exe'`; confirm `LOCAL CHECKS PASS`.** Verify no generated `.import` changes remain staged.
- [ ] **Step 3: Run the preview scene in Godot 4.7 and inspect one full event.** Check that no item remains frozen, all three contacts are logged, and `is_active` clears when `event_finished` fires.
- [ ] **Step 4: Review the whole branch, fix concrete issues, and push `feature/wind-driven-spawning`.** Keep `main` unchanged and hand the contact signal contract to the web teammate.
