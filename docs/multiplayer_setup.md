# Multiplayer dependency setup

Choose **Play > Online**, then **Host Lobby** to get a six-character code or **Join Lobby** to open code entry. The lobby shows players on the left and host-controlled match settings on the right. When both players are ready, a three-second countdown starts the match automatically. Select **Unready** to cancel it. Both copies must use the same game version. **Leave Lobby** returns to the play menu.

The host can set **Collectibles per wind** from 1 to 12 (default 3). Wind still happens at the start of each round. **Canopy** is currently the only map. Changing match settings clears readiness so both players confirm the new settings before starting.

Online play is in development. Movement, aiming, turns, wind, projectiles and silk building use host authority. Guests animate shots locally and display the host-approved silk targets. Remaining acceptance tests and the final design review are pending. Play starts after both scenes load and acknowledge the initial state.

**Play > Local** opens the same map/drop settings. Its **Play** button starts immediately, with no readiness or countdown.

GD-Sync 1.0.2 is pinned in `addons/GD-Sync`. The editor plugin and `GDSync` autoload are registered in `project.godot`. Dependency credits, revision and compatibility fixes are in `ATTRIBUTION.md`.

## Project credentials

Open **Project > Tools > GD-Sync** and enter the runtime public/private project keys from the GD-Sync dashboard. The SDK saves them in `addons/GD-Sync/keys.cfg`, which is ignored by Git. Alternatively, set `GDSYNC_PUBLIC_KEY` and `GDSYNC_PRIVATE_KEY` in the environment. Never enter dashboard login credentials here.

Each developer/build machine needs these runtime keys for online tests. Local tests do not. The SDK export plugin includes runtime keys in game exports, as required by its connection protocol; keep exported builds separate from the source repository.

GD-Sync's lobby namespace is shared by clients using the same project key. Game lobbies use `spiders-v1-`; the dependency probe uses `spiders-test-` with a fresh random suffix.

A linked database enables cloud features such as player accounts and saved data. Lobby creation and gameplay messages do not require it.

## Checks

Run `python tools/check.py` for the normal project checks, including a local SDK host/guest test.

Run the dependency probe alone:

```text
python tools/check_gd_sync.py
```

It launches two headless Godot processes, creates and joins a private two-player lobby, verifies a host/guest remote-call round trip and exits both processes. Logs are stored in `build/check/gd-sync/`. It uses SDK local mode and consumes no online allowance.

To check the real managed relay using configured keys:

```text
python tools/check_gd_sync.py --online
```

Both commands accept `--godot PATH`. The online probe uses a small amount of service data. It verifies native relay connectivity, not the browser export or multiplayer gameplay integration.

Add `--lobby` to either probe command to exercise the actual menu controls, code normalization, player count, readiness, leaving, and hosting a fresh lobby in the same process.

Run the two-client match test without online allowance:

```text
python tools/check_multiplayer.py
```

It loads the actual match, skips the wind, moves a spider, rejects another team's input, and plays both teams through a round. It checks state acknowledgements and clean shutdown. Logs are in `build/check/multiplayer/`. Use `--scenario load` for the loading handshake alone, or `--online` for the managed relay. These tests are included in the normal local checks; browser export verification is separate.

Use `--scenario combat` to check a real projectile collision, one authoritative hit, guest presentation and three shot messages. Use `--scenario silk` to cycle the shared target hints and build a strand with the same resource cost on both clients. Both scenarios run in the normal local checks.


For wind catches, misses, insect/weapon pickups and repeated recovery under different frame rates and latency:

```text
python tools/check_multiplayer.py --scenario pickups --host-fps 24 --guest-fps 144 --latency-ms 60
```

This case is included in the normal local checks. It verifies guest pickup authority and an idle interval without gameplay messages. Per-peer logs report serialized application bytes by message type; these exclude SDK/relay overhead and are not billed usage measurements.
