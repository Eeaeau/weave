# Spider Free-Step Gait Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Animate the new eight-leg spider rig while the body moves, before web-aware foot placement is ready.

**Architecture:** A controller on `SpiderRig` owns the eight existing IK foot targets. It keeps them planted in world space, moves alternating diagonal groups after a distance threshold, and selects non-crossing landings on the gameplay plane. The player movement script remains responsible for body motion.

**Tech Stack:** Godot 4.7, GDScript, existing CCDIK3D rig and headless smoke tests.

**Spec:** [Spider IK issue #10](https://github.com/Eeaeau/weave/issues/10), first implementation slice: Free-step debug mode.

## Global Constraints

- Do not query or modify web geometry in this slice.
- Preserve the existing rig, foot target names, and player movement rules.
- Feet step on the XZ gameplay plane; the controller works for any `BaseSpider3D` instance.

## Review Focus

- Feet remain planted while the body moves below the threshold.
- Eight targets are present and IK continues to reference them.
- Alternating diagonal groups step rather than all eight at once.
- Turning and reversed movement do not swap or cross foot target paths.
- Scene reload and a stationary spider do not cause spontaneous steps.

---

### Task 1: Free-step rig controller

**Files:** Create `src/features/spiders/spider_leg_controller_3d.gd`; modify `src/features/spiders/spider_rig.tscn`; create `tests/spider_free_step_smoke.gd`; modify `tools/check.py`.

**Interfaces:** Controller exposes `advance(delta: float)` for deterministic updates, `step_distance`, `step_duration`, `step_height`, and `step_lead` as Inspector properties. The rig instantiates one controller and retains its existing `FootTargets` and `LiftTargets`.

- [x] Write a headless smoke test that loads the real rig, verifies planted targets after small body movement, triggers alternating steps after larger movement, checks landing positions and non-crossing target paths, and checks no movement while stationary.
- [x] Run the smoke test and confirm it fails because the controller is missing.
- [x] Implement the controller and attach it to `spider_rig.tscn`; keep IK target markers world-fixed, step them through a lifted arc, and reject crossing candidates.
- [x] Run the focused smoke test and then `python tools/check.py` until both pass without new script or lint warnings.
- [x] Commit the tested implementation on `feature/spider-free-step-gait`.

### Task 2: Free-movement preview

**Files:** Create `src/features/spiders/spider_gait_preview.tscn` and its small controller script; extend `tests/spider_free_step_smoke.gd`.

**Interfaces:** The preview instantiates the normal spider rig and accepts directional input on an empty gameplay plane, so the gait can be tuned without web movement constraints.

- [x] Add a failing test that loads the preview and verifies the rig/controller hookup.
- [x] Create the preview with unrestricted movement and a simple visible reference plane.
- [x] Run the focused smoke test and the complete local checks.
- [x] Commit the preview.
