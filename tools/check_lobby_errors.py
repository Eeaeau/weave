"""Exercise local lobby errors and cancellation through the real SDK and menus."""

import argparse
from pathlib import Path
import secrets
import subprocess
import sys
import time
import uuid

from check import ROOT, find_godot
from check_gd_sync import wait_for_host


CASES = ("full", "closed", "missing", "version", "cancel")


def run_case(godot: Path, case: str) -> None:
    log_dir = ROOT / "build/check/lobby-errors" / uuid.uuid4().hex[:12]
    log_dir.mkdir(parents=True)
    code = "".join(secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(6))
    stop_path = log_dir / "stop-fixture"
    processes = {}
    handles = []
    deadline = time.monotonic() + 40
    try:
        for role in ("host", "guest"):
            handle = (log_dir / f"{role}.log").open("w", encoding="utf-8")
            handles.append(handle)
            command = [str(godot), "--headless", "--disable-crash-handler", "--path", str(ROOT),
                       "--log-file", str(log_dir / f"{role}-engine.log"),
                       "res://tests/multiplayer/lobby_failure_probe.tscn", "--", "--local-network",
                       f"--role={role}", f"--case={case}", f"--code={code}", f"--stop={stop_path}"]
            processes[role] = subprocess.Popen(command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT)
            if role == "host":
                wait_for_host(processes[role], log_dir / "host.log", deadline, True)
            else:
                processes[role].wait(timeout=max(0.01, deadline - time.monotonic()))
                stop_path.touch()
        for role, process in processes.items():
            status = process.wait(timeout=max(0.01, deadline - time.monotonic()))
            output = (log_dir / f"{role}.log").read_text(encoding="utf-8", errors="replace")
            if status or f"LOBBY_FAILURE_PASS: {role} {case}" not in output or any(
                marker in output for marker in ("SCRIPT ERROR:", "LOBBY_FAILURE_FAIL:",
                                                "ObjectDB instances were leaked", "resources still in use")
            ):
                raise RuntimeError(f"{case} {role} failed (exit {status}); see {log_dir}")
        print(f"LOBBY ERROR PASS: {case}; logs: {log_dir}")
    finally:
        stop_path.touch()
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--case", choices=CASES)
    args = parser.parse_args()
    godot = find_godot(args.godot)
    for case in (args.case,) if args.case else CASES:
        run_case(godot, case)
    print("LOBBY ERRORS PASS")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"LOBBY ERRORS FAILED: {error}", file=sys.stderr)
        sys.exit(1)
