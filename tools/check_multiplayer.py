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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--online", action="store_true", help="Use configured keys and the managed relay")
    parser.add_argument("--scenario", choices=("load", "turns", "combat", "silk"), default="turns")
    args = parser.parse_args()
    godot = find_godot(args.godot)
    log_dir = ROOT / "build" / "check" / "multiplayer" / uuid.uuid4().hex[:12]
    log_dir.mkdir(parents=True)
    processes: dict[str, subprocess.Popen] = {}
    handles = []
    deadline = time.monotonic() + 50.0
    code = ""
    try:
        for role in ("host", "guest"):
            log_path = log_dir / f"{role}.log"
            handle = log_path.open("w", encoding="utf-8")
            handles.append(handle)
            command = [str(godot), "--headless", "--disable-crash-handler", "--verbose", "--max-fps", "60", "--path", str(ROOT),
                       "--log-file", str(log_dir / f"{role}-engine.log"),
                       "res://tests/multiplayer/online_match_probe.tscn", "--",
                       f"--role={role}", f"--code={code}", f"--scenario={args.scenario}"]
            if not args.online:
                command.append("--local-network")
            processes[role] = subprocess.Popen(command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT)
            if role == "host":
                code = wait_for_host(processes[role], log_path, deadline, True) or ""
        for role, process in processes.items():
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
