# Canopy corridor map-style design

## Intent

Define and graybox a readable 2.5D map style for Weave before producing final hand-drawn art. The first map is a warm-sunset canopy corridor: parallel layers of sky, trunks, branches, and windblown foliage frame a clear central play space. The graybox must establish composition, depth, parallax, motion, and visibility rules that final sprites can follow.

The map is gameplay scenery, not only decoration. Its silhouette creates web-building routes, traversal obstacles, and future connections between parallel gameplay levels. The first version keeps only the middle gameplay level active while reserving space for a rear and front level.

This design is informed by the shared Gemini research on expressive doodle art, stepped visual motion, strong depth-plane separation, and atmospheric layering. Final ink, paper, shading, and lighting treatments are intentionally deferred.

## Design principles

- Keep the active gameplay plane higher-contrast and easier to read than every scenic layer.
- Create parallax through fixed, parallel world-space art cards at different depths. Sprites do not billboard or rotate to face the camera.
- Constrain the action camera to a fixed rotation. It may pan and zoom, but it does not orbit and expose the flat cards edge-on.
- Use foreground foliage to frame action without hiding spiders, webs, attacks, or moving collectibles.
- Give interactive terrain and web anchors stable world positions. Wind may animate decorative portions without moving gameplay geometry.
- Prefer authored natural structures over abstract game markers.
- Keep the first graybox narrow enough to validate quickly during the jam.

## Spatial composition

The canopy corridor is divided into named depth layers, ordered from back to front:

1. **Far sky** — a warm sunset gradient and soft cloud shapes, with almost no parallax.
2. **Distant canopy** — large, pale, desaturated tree and branch silhouettes moving very slowly.
3. **Rear foliage** — recognizable branches and leaf clusters with moderate parallax and decorative wind motion.
4. **Gameplay space** — three reserved, parallel, fixed-orientation planes aligned with the scenic art cards. Only the middle plane is initially playable.
5. **Near foliage** — dark branches and leaves moving quickly near the screen edges.
6. **Extreme foreground** — occasional near-silhouettes with the strongest parallax, softened edges, and focus-aware dithering.

All sprite planes share a fixed world orientation and remain parallel. The camera faces them from a consistent angle, so changes in position and zoom create real perspective parallax. Depth spacing and parallax strength are authored per layer rather than simulated by billboarding.

## Initial arena topology

The two spiders begin diagonally opposed: one slightly upper-left and the other lower-right. Both starts fit inside the opening camera frame.

A large forked trunk or dense branch structure occupies the center. It blocks spider movement and web placement but does not block attacks. Players must expand around it along distinct upper and lower routes. Deliberately placed intermediate anchors keep both routes viable and allow players to converge for close attacks.

The middle plane is the only playable level in this slice. The graybox reserves aligned natural crossings for future movement to rear and front gameplay levels. Those crossings are fixed structures such as crossing branches, stems, or trunks, not player-built transitions.

Projectile-blocking cover is not part of this first map-style slice. If added later, it must have a visual language distinct from terrain that only blocks traversal and web placement.

## Web attachment points

Web attachment points are authored natural anchors. Suitable forms include:

- branch forks;
- bark knots;
- thorns;
- broken twig ends with exposed pale wood;
- sturdy leaf stems.

Anchors look like ordinary scenery at a distance. They reveal usability only when the active spider is within range, using a restrained ink wiggle, a brighter cut surface, and a subtle thread-like halo. This avoids permanently cluttering the map with markers while making nearby choices discoverable.

Decorative branch tips and leaves may sway, but an anchor's gameplay transform remains fixed.

## Temporary leaf extensions

The composition reserves wind paths and attachment areas for catchable leaves. A later gameplay feature may let a caught leaf become a temporary walkable extension. Such a platform should be predictable: it visibly wears down and warns players before tearing loose.

Issue #12 does not implement this mechanic. The graybox only proves that the arena has room for leaf approaches, attachment, and temporary traversal without obscuring the main routes.

## Motion and visibility

Scenic branches and foliage use different sway amplitudes, phases, and speeds so the canopy feels windy without moving as one rigid mass. Distant motion is subtle; near leaves may move more strongly. Gameplay terrain remains stable.

Near and extreme-foreground elements stay primarily around the edges of the composition. When an element overlaps the action camera's focus-safe region, it transitions to a sparse dither pattern instead of simply becoming transparent. The treatment preserves a hand-drawn silhouette while revealing the action beneath it.

The focus-safe region follows the event the camera is framing, which may be an active spider, a web-building action, an attack, or a moving collectible. If no valid focus is available, the visual system falls back to the arena center and a wider safe region.

## Camera contract

The intended camera behaves like an action camera in Worms: it automatically pans and zooms to frame the important event, then widens when broader context matters. Players do not need to manage it manually.

The camera's rotation remains fixed. This is a hard constraint of the parallel-card art direction. The map-style graybox must remain readable across the expected pan and zoom range, but the automatic focus selection and camera state machine belong in a separate implementation issue.

## Graybox visual language

The first pass uses flat placeholder values rather than final artwork:

- the sunset sky is the brightest and warmest layer;
- the distant canopy uses pale, desaturated silhouettes;
- rear foliage is darker and more defined;
- gameplay terrain and anchors have the strongest edge contrast;
- near foliage forms a dark frame;
- extreme foreground uses near-silhouettes, softened edges, and coarse dithering.

The graybox establishes layer dimensions, depth spacing, parallax rates, camera framing limits, sway envelopes, and visibility rules. Final hand-drawn sprites will combine flat forms with simple shading while retaining this value hierarchy.

Final paper grain, ink jitter, stepped animation, normal maps, and dynamic lighting are a separate art-production step. They must not be required to make the graybox readable.

## Issue #12 deliverables

- Refactor `branch_canopy.tscn` into clearly named depth-layer roots.
- Add graybox elements for the sky, distant canopy, rear foliage, gameplay framing, near foliage, and extreme foreground.
- Remove billboarding from map sprites and keep their art cards parallel in world space.
- Establish initial depth spacing, palette values, parallax strengths, and wind-sway envelopes.
- Graybox the diagonally opposed starts, central traversal obstacle, upper and lower routes, natural anchors, and reserved fixed crossings.
- Prototype the focus-safe foreground dither treatment with a simple controllable focus point.
- Add a dedicated preview scene for composition and motion review.
- Write a concise concept-art brief derived from the approved graybox.

Existing gameplay behavior on the middle plane must remain intact.

## Follow-up issue boundaries

Create separate, isolated issues for:

- automatic event-focused camera panning and zooming;
- three playable parallel levels with fixed natural crossings;
- temporary walkable leaf platforms;
- final hand-drawn asset production and the paper, ink, shading, and lighting treatment;
- projectile-blocking cover, if playtesting shows it is desirable.

Web-anchor interaction should be coordinated with the existing web-building work rather than implemented as a second competing system.

## Validation

Automated smoke checks should verify that:

- every named layer loads;
- layer depth ordering is correct;
- all map art cards use the fixed parallel orientation rather than billboarding;
- the existing middle gameplay plane, spiders, webs, and collectibles still load;
- missing optional decorative assets leave an empty layer instead of preventing the map from loading.

The preview scene provides the visual acceptance check. Review it at the widest and closest intended camera framing and confirm that:

- the sunset, canopy corridor, and depth separation read immediately;
- panning and zooming create convincing parallax without camera rotation;
- the central obstacle leaves clear upper and lower routes;
- decorative wind motion does not move gameplay anchors;
- close foreground shapes dither before they obscure focused action;
- spiders, web strands, attacks, and moving collectibles remain legible.

The existing local check suite must continue to pass on Godot 4.7.
