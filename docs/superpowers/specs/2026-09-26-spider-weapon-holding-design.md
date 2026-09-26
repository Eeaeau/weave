# Spider weapon holding

## Intent

The player can keep several weapons in the existing inventory, but only the selected slot is visibly equipped. A ranged weapon such as a rocket launcher sits above the spider and is held by the left and right mid-front legs. A melee weapon such as an axe sits in front and is held by the front right leg. The remaining legs continue walking. This first slice concerns visible holding poses and equipment switching; weapon damage and firing behavior remain in their existing weapon classes. The limb assignments are initial assumptions for review.

## Rig and ownership

- Keep the eight existing `FootTargets` as the only IK end targets. The leg controller normally owns them for walking. When a weapon is equipped, a pose controller owns only the specified holding legs and updates those same targets to the weapon's grip positions each frame.
- Retain the two newly added body-relative markers as `WeaponMounts/RangedMount` and `WeaponMounts/MeleeMount`. They position the held weapon, not the feet. A held-visual scene supplies one or two grip markers so weapons with different shapes can place limbs correctly.
- The mid-front pair holds ranged weapons. The front right leg holds melee weapons. This assignment can be changed later without adding IK solvers.
- On selection change, release the old holding legs, hide its visual, show the new selected weapon at its mount, and move its holding legs to the new grips. Unselected inventory entries have no held visual. Selecting `WeaponNoAction` clears the pose.
- The ranged mount follows the current aim angle so the launcher and both grips turn together. The melee mount stays at its authored rest pose in this slice; a later attack animation can swing it.
- The walking controller excludes held legs from step groups and avoids treating their grip positions as ground landings. On unequip, their current target positions become the start of ordinary walking steps so they do not snap to old ground positions. Web-aware landing rules are separate future work.

## Inventory and visuals

`PlayerSpider3D.weapons` and `selected_weapon_idx` remain the source of truth. `Weapon3D` declares an optional held-visual scene and a pose type (`none`, `ranged`, or `melee`). The real inventory item remains a child of the spider for pickup and firing; its held visual is a separate display node with no pickup collision. Existing weapons without a held-visual scene keep their current behavior. Include placeholder launcher and axe visuals to demonstrate the grips without adding new combat mechanics.

## Alternatives considered

Separate weapon IK solvers would duplicate the existing leg chains and risk competing with the gait. Using the two weapon markers directly as foot targets would put multiple limbs on one point and make weapon-specific grip spacing impossible. Reusing each leg's foot target while keeping weapon mounts and grips separate preserves the current rig and allows either one-handed or two-handed poses.

## Checks

Test selection, pickup, depletion, and no-action transitions; verify only one visual is shown and the correct one or two legs leave the gait. Confirm the other legs still step during movement, released legs resume stepping, and each grip target follows the weapon mount during turning and aiming. Run the existing project checks and inspect the pose in a preview scene.
