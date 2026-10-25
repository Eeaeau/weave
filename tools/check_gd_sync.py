"""Verify GD-Sync code joining and remote calls with two headless processes."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

from check import ROOT, find_godot


def wait_for_host(process: subprocess.Popen, log_path: Path, deadline: float, lobby: bool) -> str | None:
    while time.monotonic() < deadline:
        output = log_path.read_text(encoding="utf-8", errors="replace")
        code_match = re.search(r"ONLINE_LOBBY_READY: ([A-Z2-9]{6})", output)
        if lobby and code_match:
            return code_match.group(1)
        if not lobby and "GD_SYNC_JOINED: host" in output:
            return None
        if process.poll() is not None:
            raise RuntimeError(f"Host exited before joining. See {log_path}")
        time.sleep(0.05)
    raise RuntimeError(f"Host did not join before timeout. See {log_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--online", action="store_true", help="Use the real relay and local keys")
    parser.add_argument("--lobby", action="store_true", help="Exercise the production lobby menu")
    args = parser.parse_args()
    godot = find_godot(args.godot)
    run_id = uuid.uuid4().hex[:12]
    log_dir = ROOT / "build" / "check" / "gd-sync" / run_id
    log_dir.mkdir(parents=True)
    processes: dict[str, subprocess.Popen] = {}
    handles = []
    deadline = time.monotonic() + 45.0
    join_code = f"spiders-test-{run_id}"
    scene = "online_lobby_probe" if args.lobby else "gd_sync_probe"
    pass_marker = "ONLINE_LOBBY_PROBE_PASS" if args.lobby else "GD_SYNC_PROBE_PASS"

    try:
        for role in ("host", "guest"):
            log_path = log_dir / f"{role}.log"
            handle = log_path.open("w", encoding="utf-8")
            handles.append(handle)
            command = [
                str(godot), "--headless", "--path", str(ROOT),
                "--log-file", str(log_dir / f"{role}-engine.log"),
                f"res://tests/multiplayer/{scene}.tscn", "--",
                f"--role={role}", f"--code={join_code}",
            ]
            if args.online:
                command.append("--online")
            elif args.lobby:
                command.append("--local-network")
            processes[role] = subprocess.Popen(
                command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT,
            )
            if role == "host":
                generated_code = wait_for_host(processes[role], log_path, deadline, args.lobby)
                if generated_code:
                    join_code = generated_code

        for role, process in processes.items():
            try:
                status = process.wait(timeout=max(0.01, deadline - time.monotonic()))
            except subprocess.TimeoutExpired as error:
                raise RuntimeError(f"{role} timed out. See {log_dir}") from error
            output = (log_dir / f"{role}.log").read_text(encoding="utf-8", errors="replace")
            if status != 0 or f"{pass_marker}: {role}" not in output:
                raise RuntimeError(f"{role} failed (exit {status}). See {log_dir}")
            if any(marker in output for marker in (
                "SCRIPT ERROR:", "GD_SYNC_PROBE_FAIL:", "ONLINE_LOBBY_FAIL:", "Parse Error:",
                "ObjectDB instances were leaked", "resources still in use",
            )):
                raise RuntimeError(f"{role} reported an error. See {log_dir}")
        mode = "online relay" if args.online else "local"
        scenario = "menu host/join/leave" if args.lobby else "acknowledged host/guest round trip"
        print(f"GD-SYNC PASS: {mode} {scenario}")
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
        print(f"GD-SYNC FAILED: {error}", file=sys.stderr)
        sys.exit(1)
