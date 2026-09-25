"""Run the template's Godot and GDScript checks on any desktop platform."""

from __future__ import annotations

import argparse
import hashlib
import io
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile


sys.stdout.reconfigure(errors="replace")
sys.stderr.reconfigure(errors="replace")

ROOT = Path(__file__).resolve().parent.parent
TOOL_DIR = ROOT / "build" / "tools"
GDSTYLE_VERSION = "0.3.0"
GDSTYLE_RELEASES = {
    ("Windows", "x86_64"): (
        "gdstyle-x86_64-pc-windows-msvc.zip",
        "eca2f19b5f19b710d0343e5bff3a6b39b0a047ee01a8bd2aaf51f02b24f58cdc",
    ),
    ("Linux", "x86_64"): (
        "gdstyle-x86_64-unknown-linux-gnu.tar.gz",
        "afa1d2c49adfd077cf570c4270c495e3127df324af065d32cdc9218f6d1e110b",
    ),
    ("Darwin", "x86_64"): (
        "gdstyle-x86_64-apple-darwin.tar.gz",
        "190d9b64fdfc5cd9723f0a0c0a64426509dc0cd1d2252b318e88ef2eec868659",
    ),
    ("Darwin", "aarch64"): (
        "gdstyle-aarch64-apple-darwin.tar.gz",
        "4dee311782212fd60a9e3be01c9a52d7f763ccbc0f2eaca202923628b818313e",
    ),
}


def machine_name() -> str:
    machine = platform.machine().lower()
    return {"amd64": "x86_64", "arm64": "aarch64"}.get(machine, machine)


def resolve_executable(value: str | None) -> Path | None:
    if not value:
        return None
    path = Path(value).expanduser()
    if path.is_file():
        return path.resolve()
    found = shutil.which(value)
    return Path(found).resolve() if found else None


def find_godot(override: str | None) -> Path:
    if override:
        found = resolve_executable(override)
        if found:
            return found
        raise RuntimeError(f"Godot executable does not exist: {override}")

    candidates: list[Path] = []
    if platform.system() == "Windows":
        steam_root = os.environ.get("ProgramFiles(x86)")
        if steam_root:
            candidates.append(
                Path(steam_root)
                / "Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
            )
    elif platform.system() == "Darwin":
        candidates.append(Path("/Applications/Godot.app/Contents/MacOS/Godot"))
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    for name in ("godot", "godot4"):
        found = resolve_executable(name)
        if found:
            return found
    raise RuntimeError("Godot was not found. Pass --godot or set GODOT_BIN.")


def find_gdstyle(override: str | None) -> Path:
    if override:
        found = resolve_executable(override)
        if found:
            return found
        raise RuntimeError(f"gdstyle executable does not exist: {override}")

    binary = TOOL_DIR / ("gdstyle.exe" if platform.system() == "Windows" else "gdstyle")
    if binary.is_file():
        return binary

    release = GDSTYLE_RELEASES.get((platform.system(), machine_name()))
    if release is None:
        raise RuntimeError("No pinned gdstyle binary for this platform. Pass --gdstyle.")
    asset, expected_hash = release
    url = f"https://github.com/atelico/gdstyle/releases/download/v{GDSTYLE_VERSION}/{asset}"
    print(f"Downloading gdstyle {GDSTYLE_VERSION} for {platform.system()}...")
    with urllib.request.urlopen(url, timeout=60) as response:
        archive = response.read()
    if hashlib.sha256(archive).hexdigest() != expected_hash:
        raise RuntimeError("gdstyle download checksum did not match the pinned release.")

    member = "gdstyle.exe" if platform.system() == "Windows" else "gdstyle"
    TOOL_DIR.mkdir(parents=True, exist_ok=True)
    if asset.endswith(".zip"):
        with zipfile.ZipFile(io.BytesIO(archive)) as package:
            with package.open(member) as source, binary.open("wb") as target:
                shutil.copyfileobj(source, target)
    else:
        with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as package:
            source = package.extractfile(member)
            if source is None:
                raise RuntimeError("gdstyle binary is missing from release archive.")
            with source, binary.open("wb") as target:
                shutil.copyfileobj(source, target)
    if platform.system() != "Windows":
        binary.chmod(0o755)
    return binary


def run(
    command: list[str], marker: str | None = None, godot: bool = False, timeout: int = 60
) -> str:
    display = " ".join(command)
    print(f"\n$ {display}", flush=True)
    try:
        result = subprocess.run(
            command,
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        partial = exc.stdout or b""
        if isinstance(partial, bytes):
            partial = partial.decode("utf-8", errors="replace")
        print(partial, flush=True)
        raise RuntimeError(f"Command timed out after {timeout}s: {display}") from exc
    output = result.stdout
    print(output, end="" if output.endswith("\n") else "\n", flush=True)
    if result.returncode != 0:
        raise RuntimeError(f"Command exited with status {result.returncode}: {display}")
    if marker and marker not in output:
        raise RuntimeError(f"Missing test result marker: {marker}")
    if godot and any(
        error in output
        for error in ("SCRIPT ERROR:", "Parse Error:", "Failed loading resource", "Failed to load script")
    ):
        raise RuntimeError(f"Godot reported a script or resource error: {display}")
    return output.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN") or os.environ.get("GODOT_PATH"))
    parser.add_argument("--gdstyle", default=os.environ.get("GDSTYLE_BIN") or os.environ.get("GDSTYLE_PATH"))
    args = parser.parse_args()

    godot = find_godot(args.godot)
    gdstyle = find_gdstyle(args.gdstyle)
    if not run([str(godot), "--version"]).startswith("4.7."):
        raise RuntimeError("This template expects Godot 4.7.x. Pass --godot for that version.")
    if GDSTYLE_VERSION not in run([str(gdstyle), "--version"]):
        raise RuntimeError(f"This template expects gdstyle {GDSTYLE_VERSION}.")

    run([str(gdstyle), "fmt", "--check", "src", "tests"])
    run([str(gdstyle), "check", "--max-warnings", "0", "src", "tests"])

    check_dir = ROOT / "build" / "check"
    check_dir.mkdir(parents=True, exist_ok=True)
    base = [str(godot), "--headless", "--path", str(ROOT)]
    run(base + ["--import", "--log-file", str(check_dir / "import.log")], godot=True, timeout=300)
    for script, marker in (
        ("resource_smoke", "RESOURCE PASS:"),
        ("smoke", "SMOKE PASS:"),
        ("menu_smoke", "MENU PASS:"),
        ("wind_selection_smoke", "WIND SELECTION PASS:"),
        ("wind_flight_smoke", "WIND FLIGHT PASS:"),
    ):
        run(
            base + ["--script", f"res://tests/{script}.gd", "--log-file", str(check_dir / f"{script}.log")],
            marker=marker,
            godot=True,
            timeout=40,
        )
    print("\nLOCAL CHECKS PASS")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, KeyError, zipfile.BadZipFile, tarfile.TarError) as exc:
        print(f"CHECKS FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
