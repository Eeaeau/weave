# Multiplayer dependency setup

Choose **Online** in the main menu, then **Host Lobby** to get a six-character code or **Join Lobby** to enter a friend's code. The player count updates when someone joins or leaves. **Leave Lobby** returns to the menu.

This connects the lobby; synchronized match gameplay is not implemented yet. **Play** opens the existing local game.

GD-Sync 1.0.2 is pinned in `addons/GD-Sync`. The editor plugin and `GDSync` autoload are registered in `project.godot`. Dependency credits, revision and compatibility fixes are in `ATTRIBUTION.md`.

## Project credentials

Open **Project > Tools > GD-Sync** and enter the runtime public/private project keys from the GD-Sync dashboard. The SDK saves them in `addons/GD-Sync/keys.cfg`, which is ignored by Git. Alternatively, set `GDSYNC_PUBLIC_KEY` and `GDSYNC_PRIVATE_KEY` in the environment. Never enter dashboard login credentials here.

Each developer/build machine needs these runtime keys for online tests. Local tests do not. The SDK export plugin includes runtime keys in game exports, as required by its connection protocol; keep exported builds separate from the source repository.

GD-Sync's lobby namespace is shared by clients using the same project key. This project's dependency probe uses the `spiders-test-` prefix and a fresh random suffix on every run. Future game lobbies should also use a project-specific prefix.

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

Add `--lobby` to either probe command to exercise the actual menu controls, code normalization, player count, leaving, and hosting a fresh lobby in the same process.
