"""Verify that two simultaneous local GD-Sync rooms complete independent matches."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import re
import subprocess
import sys

from check import ROOT, find_godot


def run_room(godot: Path) -> tuple[str, Path]:
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools/check_multiplayer.py"),
         "--godot", str(godot), "--scenario", "turns"],
        cwd=ROOT, capture_output=True, text=True, timeout=90,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stdout + result.stderr)
    log_line = next((line for line in result.stdout.splitlines() if line.startswith("Logs: ")), "")
    if not log_line:
        raise RuntimeError("Room runner returned no verification logs")
    log_dir = Path(log_line.removeprefix("Logs: "))
    match = re.search(r"ONLINE_LOBBY_READY: ([A-Z2-9]{6})", (log_dir / "host.log").read_text(encoding="utf-8", errors="replace"))
    if match is None:
        raise RuntimeError(f"Room did not announce its code; see {log_dir}")
    return match.group(1), log_dir


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    args = parser.parse_args()
    godot = find_godot(args.godot)
    with ThreadPoolExecutor(max_workers=2) as pool:
        rooms = list(pool.map(run_room, [godot, godot]))
    if rooms[0][0] == rooms[1][0]:
        raise RuntimeError("Independent matches used the same lobby code")
    for code, log_dir in rooms:
        print(f"Room {code}: {log_dir}")
    print("MULTIPLAYER ROOMS PASS: two simultaneous independent matches")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"MULTIPLAYER ROOMS FAILED: {error}", file=sys.stderr)
        sys.exit(1)
