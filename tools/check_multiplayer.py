"""Run a production online match with two automatic Godot clients on this computer."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys
import time
import uuid

from check import ROOT, find_godot
from check_gd_sync import wait_for_host


def wait_for_loaded(process: subprocess.Popen, path: Path, role: str, deadline: float) -> None:
    while time.monotonic() < deadline:
        output = path.read_text(encoding="utf-8", errors="replace")
        if any(marker in output for marker in ("SCRIPT ERROR:", "ONLINE_MATCH_FAIL:", "Parse Error:")):
            raise RuntimeError(f"{role} failed before disconnect test; see {path.parent}")
        if f"ONLINE_MATCH_LOADED: {role}" in output:
            return
        if process.poll() is not None:
            raise RuntimeError(f"{role} exited before disconnect test; see {path.parent}")
        time.sleep(0.05)
    raise RuntimeError(f"{role} did not load before disconnect test; see {path.parent}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--online", action="store_true", help="Use configured keys and the managed relay")
    parser.add_argument("--scenario", choices=("load", "turns", "combat", "silk", "pickups",
                                                 "disconnect-host", "disconnect-guest"), default="turns")
    parser.add_argument("--host-fps", type=int, default=60)
    parser.add_argument("--guest-fps", type=int, default=60)
    parser.add_argument("--latency-ms", type=int, default=0)
    args = parser.parse_args()
    if min(args.host_fps, args.guest_fps) < 1 or not 0 <= args.latency_ms <= 500:
        parser.error("Frame rates must be positive; latency must be between 0 and 500 ms")
    godot = find_godot(args.godot)
    log_dir = ROOT / "build" / "check" / "multiplayer" / uuid.uuid4().hex[:12]
    log_dir.mkdir(parents=True)
    processes: dict[str, subprocess.Popen] = {}
    handles = []
    killed_role = args.scenario.removeprefix("disconnect-") if args.scenario.startswith("disconnect-") else ""
    deadline = time.monotonic() + (75.0 if killed_role else 50.0)
    code = ""
    try:
        for role in ("host", "guest"):
            log_path = log_dir / f"{role}.log"
            handle = log_path.open("w", encoding="utf-8")
            handles.append(handle)
            frame_rate = args.host_fps if role == "host" else args.guest_fps
            command = [str(godot), "--headless", "--disable-crash-handler", "--verbose",
                       "--max-fps", str(frame_rate), "--path", str(ROOT),
                       "--log-file", str(log_dir / f"{role}-engine.log"),
                       "res://tests/multiplayer/online_match_probe.tscn", "--",
                       f"--role={role}", f"--code={code}", f"--scenario={args.scenario}",
                       f"--latency-ms={args.latency_ms}"]
            if not args.online:
                command.append("--local-network")
            processes[role] = subprocess.Popen(command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT)
            if role == "host":
                code = wait_for_host(processes[role], log_path, deadline, True) or ""
        if killed_role:
            for role, process in processes.items():
                wait_for_loaded(process, log_dir / f"{role}.log", role, deadline)
            processes[killed_role].kill()
            processes[killed_role].wait(timeout=5)
        for role, process in processes.items():
            if role == killed_role:
                continue
            try:
                status = process.wait(timeout=max(0.01, deadline - time.monotonic()))
            except subprocess.TimeoutExpired as error:
                raise RuntimeError(f"{role} timed out; see {log_dir}") from error
            output = (log_dir / f"{role}.log").read_text(encoding="utf-8", errors="replace")
            if status != 0 or f"ONLINE_MATCH_PASS: {role}" not in output or any(
                marker in output for marker in ("SCRIPT ERROR:", "ONLINE_MATCH_FAIL:",
                                                "ObjectDB instances were leaked", "resources still in use")
            ):
                raise RuntimeError(f"{role} failed (exit {status}); see {log_dir}")
        print(f"MULTIPLAYER PASS: {'relay' if args.online else 'local'} production match {args.scenario}")
        print(f"Logs: {log_dir}")
        return 0
    finally:
        for process in processes.values():
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
        for handle in handles:
            handle.close()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError) as error:
        print(f"MULTIPLAYER FAILED: {error}", file=sys.stderr)
        sys.exit(1)
