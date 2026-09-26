# Canopy Corridor Map Style Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Graybox a warm-sunset canopy corridor with fixed parallel art cards, readable depth layers, stable gameplay geometry, wind motion, and focus-aware foreground dithering.

**Architecture:** `BranchCanopy` remains the map root but gains explicit back-to-front layer containers and a fixed-rotation perspective camera. Small reusable nodes own deterministic decorative sway and focus-dither shader inputs; the map scene owns composition and stable markers. A separate preview scene demonstrates composition without adding the future automatic action-camera state machine.

**Tech Stack:** Godot 4.7, GDScript, `Sprite3D`, spatial shaders, SVG graybox assets, headless Godot smoke tests.

**Spec:** `docs/superpowers/specs/2026-09-26-canopy-corridor-map-style-design.md`

## Global Constraints

- Work on `feature/map-style-design`; do not modify the user's other checkout or wind-feature branch.
- All map art cards use `rotation_degrees = Vector3(-35.5, 0, 0)` and remain parallel; no map `Sprite3D` may enable billboarding.
- The perspective camera keeps one fixed rotation and may translate or change FOV only; it must not call `look_at()` during processing.
- Only the middle gameplay plane is active; front and rear gameplay planes are reserved markers, not traversal systems.
- Gameplay starts, anchors, and obstacles remain stationary; wind motion affects decorative nodes only.
- The central obstacle blocks movement and web placement conceptually, but projectile collision is outside this task.
- Final hand-drawn assets, paper treatment, ink jitter, dynamic lighting, automatic camera focus, and leaf-platform gameplay are out of scope.
- Existing gameplay behavior and the full Godot 4.7 local check suite must remain intact.

## Review Focus

- A missing optional decorative texture leaves its layer empty without breaking scene load; pin this in Task 1's map-style smoke test.
- A map card accidentally enabling billboarding fails the orientation contract; scan every `Sprite3D` below the layer roots in Task 1.
- Repeated sway steps must not drift from the authored transform; exercise a full cycle and reset in Task 2.
- A missing or freed focus target must fall back to the arena center; exercise both cases in Task 3.
- The closest preview framing must not allow the dither safe radius to collapse below its configured minimum; assert the clamped shader input in Task 3.

---

### Task 1: Fixed parallel layer scaffold

**Files:**
- Create: `src/features/world/maps/branch_canopy/optional_card.gd`
- Create: `tests/map_style_smoke.gd`
- Modify: `tools/check.py`
- Modify: `src/features/world/maps/branch_canopy/branch_canopy.tscn`
- Modify: `src/features/world/maps/branch_canopy/parallax_camera.gd`

**Interfaces:**
- Produces: `class_name OptionalCard3D` with exported `texture_path: String` and `load_optional_texture() -> bool`; a missing path clears the texture, hides the card, warns once, and returns `false`.
- Produces: named map roots `FarSky`, `DistantCanopy`, `RearFoliage`, `GameplaySpace`, `NearFoliage`, and `ExtremeForeground` in back-to-front Z order.
- Produces: gameplay markers `GameplaySpace/RearPlane`, `GameplaySpace/MiddlePlane`, `GameplaySpace/FrontPlane`, plus the existing start markers under `MiddlePlane`.
- Produces: `ParallaxCamera` with perspective projection and a fixed authored rotation.

- [ ] **Step 1: Add the failing map-style smoke test.** Instantiate `branch_canopy.tscn`; assert all six layer roots exist, their global Z positions increase back-to-front, only `MiddlePlane` is marked playable through metadata `playable = true`, every map card has rotation `Vector3(-35.5, 0, 0)` and `billboard == BaseMaterial3D.BILLBOARD_DISABLED`, and the camera rotation remains unchanged after ten processed frames. Instantiate `OptionalCard3D` with a nonexistent path and assert `load_optional_texture()` returns `false` without preventing the map from loading.

- [ ] **Step 2: Register and run the new test to verify failure.** Add `map_style_smoke` with marker `MAP STYLE PASS:` to `tools/check.py`; run the test headlessly and expect missing layer-root assertions.

- [ ] **Step 3: Implement optional decorative cards and refactor the scene into the named roots.** Move the existing branches and start markers under `GameplaySpace/MiddlePlane`, move far and near canopy cards to their matching roots, add empty rear/front plane markers with `playable = false`, remove all map billboarding, set every map card to the shared `-35.5` degree X rotation, and keep existing node names available beneath the new hierarchy. Use `OptionalCard3D` for scenery that may be omitted without breaking the map.

- [ ] **Step 4: Lock the camera orientation.** Replace repeated `look_at()` calls with one exported fixed rotation authored in the scene; preserve the existing gentle X translation as a temporary preview of perspective parallax.

- [ ] **Step 5: Update existing smoke-test paths and run focused tests.** Update `tests/smoke.gd` to resolve the nested start markers; run `map_style_smoke.gd` and `smoke.gd`, expecting both PASS markers.

- [ ] **Step 6: Commit the scaffold.** Commit the test, checker, scene, camera script, and any Godot-generated import metadata as `Graybox fixed parallel map layers`.

### Task 2: Canopy corridor geometry and wind motion

**Files:**
- Create: `src/features/world/maps/branch_canopy/wind_sway.gd`
- Create: `src/features/world/maps/branch_canopy/assets/graybox/sunset_sky.svg`
- Create: `src/features/world/maps/branch_canopy/assets/graybox/distant_canopy.svg`
- Create: `src/features/world/maps/branch_canopy/assets/graybox/leaf_cluster.svg`
- Create: `src/features/world/maps/branch_canopy/assets/graybox/central_fork.svg`
- Create: `src/features/world/maps/branch_canopy/assets/graybox/foreground_branch.svg`
- Modify: `src/features/world/maps/branch_canopy/branch_canopy.tscn`
- Modify: `tests/map_style_smoke.gd`

**Interfaces:**
- Produces: `class_name WindSway3D` with `advance(delta: float) -> void` and exported `amplitude_degrees`, `cycles_per_second`, and `phase_offset`.
- Produces: stable markers `MiddlePlane/Anchors/UpperLeftStart`, `LowerRightStart`, `UpperRoute`, `LowerRoute`, and `GameplaySpace/FixedCrossings/{RearCrossing,FrontCrossing}`.
- Consumes: Task 1's fixed layer roots and orientation contract.

- [ ] **Step 1: Extend the failing test for topology and sway.** Assert diagonally opposed start markers, central obstacle, upper/lower route anchors, reserved crossings, and at least one decorative sway node per foliage layer. Instantiate `WindSway3D`, advance one full cycle, and assert it returns to the authored rotation without changing position.

- [ ] **Step 2: Run the test and confirm the new assertions fail.** Expect missing graybox nodes or the missing `WindSway3D` class.

- [ ] **Step 3: Add flat SVG graybox assets.** Use warm sky, pale distant silhouettes, mid-value rear foliage, high-contrast central terrain, and dark near/foreground shapes; keep shapes broad and free of final ink or paper treatment.

- [ ] **Step 4: Author the corridor topology.** Place the spiders' starts upper-left and lower-right, a forked central obstacle between them, reachable upper/lower route anchors, and non-playable rear/front crossing markers. Preserve current middle-plane gameplay nodes while repositioning them to match the approved silhouette.

- [ ] **Step 5: Implement deterministic decorative sway.** `WindSway3D` stores its authored rotation and applies `sin(TAU * cycles_per_second * elapsed + phase_offset) * amplitude_degrees`; never modify translation or any anchor transform. Assign smaller amplitudes to distant foliage and larger amplitudes to near leaves.

- [ ] **Step 6: Run the focused and existing smoke tests.** Expect `MAP STYLE PASS:`, `SMOKE PASS:`, and no script/resource errors.

- [ ] **Step 7: Commit the graybox geometry.** Commit assets, scene composition, sway component, tests, and generated imports as `Build canopy corridor graybox`.

### Task 3: Focus-aware foreground dithering

**Files:**
- Create: `src/features/world/maps/branch_canopy/focus_dither_layer.gd`
- Create: `src/features/world/maps/branch_canopy/focus_dither.gdshader`
- Modify: `src/features/world/maps/branch_canopy/branch_canopy.tscn`
- Modify: `tests/map_style_smoke.gd`

**Interfaces:**
- Produces: `class_name FocusDitherLayer3D` with `set_focus(target: Node3D) -> void`, `set_focus_world_position(value: Vector3) -> void`, and `update_shader_inputs() -> void`.
- Produces: exported `camera: Camera3D`, `arena_center: Node3D`, `minimum_safe_radius_pixels: float = 160.0`, and `safe_radius_ratio: float = 0.22`.
- Produces shader parameters `focus_uv: vec2`, `safe_radius_uv: float`, and `fade_width_uv: float` on materials below `ExtremeForeground`.
- Consumes: Task 1's fixed camera and Task 2's extreme-foreground cards.

- [ ] **Step 1: Extend the failing test for focus behavior.** Set a valid target and assert projected `focus_uv` is passed to every foreground material; free the target and assert the arena-center fallback is used; reduce viewport size and assert `safe_radius_uv` reflects at least `160.0 / min(viewport_width, viewport_height)`.

- [ ] **Step 2: Run the test and confirm failure.** Expect the missing component or shader parameters.

- [ ] **Step 3: Implement the controller.** Project the target or arena-center world position through the configured camera, normalize it by viewport size, clamp the safe radius using the exported pixel minimum, and update each child `ShaderMaterial`. Treat missing camera, zero-size viewport, or material-free children as safe no-ops with one editor warning.

- [ ] **Step 4: Implement the spatial dither shader.** Preserve pixels outside the focus-safe circle; inside it, use a stable 4x4 Bayer threshold over `FRAGCOORD.xy` and smooth the transition across `fade_width_uv`. Do not animate the pattern or alter cards that do not use this material.

- [ ] **Step 5: Wire the extreme foreground and run tests.** Give its closest cards unique shader materials, configure the arena-center marker, and run `map_style_smoke.gd` plus the full local checks.

- [ ] **Step 6: Commit visibility behavior.** Commit the controller, shader, scene material wiring, and tests as `Keep foreground clear around focused action`.

### Task 4: Preview and concept-art handoff

**Files:**
- Create: `src/features/world/maps/branch_canopy/branch_canopy_preview.tscn`
- Create: `src/features/world/maps/branch_canopy/branch_canopy_preview.gd`
- Create: `docs/art/canopy_corridor_concept_brief.md`
- Modify: `README.md`
- Modify: `tests/map_style_smoke.gd`

**Interfaces:**
- Produces: an isolated preview that instances `branch_canopy.tscn`, moves a `FocusPreview` marker through upper route `Vector3(-4, 1.8, 0)`, center `Vector3.ZERO`, and lower route `Vector3(4, -1.8, 0)`, and calls `FocusDitherLayer3D.set_focus()`.
- Consumes: Tasks 1–3 without adding automatic camera-event selection or gameplay rules.

- [ ] **Step 1: Extend the test for preview isolation.** Load and instantiate the preview; assert it contains one map instance, one focus marker, and no match manager or gameplay controller; advance its deterministic preview method and assert the focus marker visits all three authored positions.

- [ ] **Step 2: Run the test and confirm the preview assertions fail.** Expect the preview scene to be missing.

- [ ] **Step 3: Create the preview.** Add `advance_preview(delta: float) -> void` so tests and movie capture can drive it deterministically; demonstrate fixed camera rotation, parallax, wind sway, and dithering at wide and close framing.

- [ ] **Step 4: Write the concept-art brief.** Record the warm-sunset palette hierarchy, six depth layers, fixed parallel-card rule, diagonal starts, central fork silhouette, natural anchor vocabulary, wind-motion boundaries, dither safe region, and the explicit ban on relying on final shaders for readability.

- [ ] **Step 5: Update project documentation.** Point `README.md` to the preview, spec, and concept brief; state that automatic action framing and the other mechanics are tracked separately.

- [ ] **Step 6: Verify visually and automatically.** Run full local checks, record or launch the preview at wide and close framing, and confirm each visual acceptance item from the spec. Treat unreadable silhouettes or foreground obstruction as failures even if automated tests pass.

- [ ] **Step 7: Commit the handoff.** Commit the preview, concept brief, README, and tests as `Add canopy corridor art preview`.

### Task 5: Final branch review

**Files:**
- Review all files changed by Tasks 1–4.

**Interfaces:**
- Consumes: the complete map-style slice.
- Produces: a clean, reviewable branch satisfying issue #12's graybox scope.

- [ ] **Step 1: Run format and full checks.** Run `python tools/check.py` with the pinned Godot 4.7 and gdstyle 0.3.0 binaries; expect `LOCAL CHECKS PASS`.

- [ ] **Step 2: Inspect the diff.** Run `git diff origin/main...HEAD --check` and review for accidental generated files, unrelated gameplay changes, billboarding, camera rotation changes, or final-art scope creep.

- [ ] **Step 3: Perform the visual acceptance pass.** Capture the preview at wide and close framing and verify depth separation, upper/lower route readability, stable anchors, wind hierarchy, and foreground reveal.

- [ ] **Step 4: Commit only if review requires fixes.** Use a focused message describing the concrete correction; leave the branch clean.
