#!/usr/bin/env python3
"""Generate a disposable f14769e save, upgrade it, then reload the current save."""
import json
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
COMMIT = "f14769e3a9a0a7e2c26eeeab08486885a1be45b4"
sys.path.insert(0, str(ROOT / "tools"))
from factorio_test_engine import executable, isolated_environment


def run(command, environment):
    result = subprocess.run(command, env=environment, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=60)
    if result.returncode:
        raise RuntimeError(result.stdout[-12000:])
    return result.stdout


def server(base, save, settings, write, work, stage, environment, checkpoint=None):
    marker = write / "script-output" / f"ct-legacy-{stage}.txt"
    assert not marker.exists(), f"Stale marker: {marker}"
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    logfile = work / f"{stage}.log"
    with logfile.open("w") as output:
        process = subprocess.Popen(base + ["--start-server", str(save), "--server-settings", str(settings),
                                   "--bind", "127.0.0.1", "--port", str(port)],
                                   env=environment, stdout=output, stderr=subprocess.STDOUT)
        found = None
        try:
            deadline = time.monotonic() + 60
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    break
                if marker.exists():
                    if checkpoint:
                        saves = list(write.rglob(f"*{checkpoint}*.zip"))
                        if len(saves) == 1:
                            try:
                                with zipfile.ZipFile(saves[0]) as archive:
                                    if archive.testzip() is None:
                                        found = saves[0]
                                        break
                            except (OSError, zipfile.BadZipFile):
                                pass
                    else:
                        break
                if "Error while running" in logfile.read_text():
                    break
                time.sleep(.1)
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
    output = logfile.read_text()
    with (ROOT / "tests/last-legacy-upgrade.log").open("a") as stream:
        stream.write(output)
    print("\n".join(line for line in output.splitlines() if "CT_LEGACY" in line), flush=True)
    if not marker.exists() or (checkpoint and found is None) or "Error while running" in output:
        raise RuntimeError(f"Échec de l’étape {stage}:\n{output[-12000:]}")
    return found


def instrument(mod, stage):
    tests = mod / "tests"
    tests.mkdir(exist_ok=True)
    for name in ("legacy_fixture.lua", "legacy_upgrade.lua"):
        shutil.copy2(ROOT / "tests" / name, tests / name)
    with (mod / "control.lua").open("a") as stream:
        stream.write('\nrequire("tests.legacy_fixture").install_fixture(Runtime)\n' if stage == "fixture"
                     else '\nrequire("tests.legacy_upgrade")(Runtime)\n')


def main():
    (ROOT / "tests/last-legacy-upgrade.log").write_text("")
    binary = executable()
    environment = isolated_environment()
    with tempfile.TemporaryDirectory(prefix="ct-legacy-upgrade-") as directory:
        work = Path(directory)
        mods = work / "mods"
        mods.mkdir()
        old = mods / "construction-train"
        old.mkdir()
        archive_path = work / "legacy-source.tar"
        subprocess.run(["git", "-C", str(ROOT), "archive", "--format=tar", "-o", str(archive_path), COMMIT], check=True)
        with tarfile.open(archive_path) as archive:
            archive.extractall(old, filter="data")
        instrument(old, "fixture")
        old_info = json.loads((old / "info.json").read_text())
        (mods / "mod-list.json").write_text(json.dumps({"mods": [
            {"name": name, "enabled": name in ("base", "quality", "recycler", "construction-train")}
            for name in ("base", "quality", "recycler", "construction-train", "space-age", "elevated-rails")]}))
        write = work / "write"
        write.mkdir()
        config = work / "config.ini"
        config.write_text(f"[path]\nread-data={binary.parents[2] / 'data'}\nwrite-data={write}\n[other]\ncheck-updates=false\n")
        settings = work / "server-settings.json"
        settings.write_text(json.dumps({"name": "CT legacy isolated", "description": "Isolated migration test", "visibility": {"public": False, "lan": False},
                                       "require_user_verification": False, "auto_pause": False, "autosave_interval": 0}))
        base = [str(binary), "--config", str(config), "--mod-directory", str(mods)]
        seed = work / "seed.zip"
        run(base + ["--create", str(seed)], environment)
        fixture = server(base, seed, settings, write, work, "fixture", environment, "ct-legacy-fixture")
        # Only the disposable source copy is replaced; the save is never rewritten.
        shutil.rmtree(old)
        shutil.copytree(ROOT, old, ignore=shutil.ignore_patterns(
            ".git", ".tools", ".agents", ".codex", ".aws", "dist", "__pycache__", "*.log"))
        current_info = json.loads((old / "info.json").read_text())
        # The repository currently shares 0.1.0 with the fixture. Force a real
        # configuration event with a metadata-only version bump in this copy.
        version = max(tuple(map(int, info["version"].split("."))) for info in (old_info, current_info))
        current_info["version"] = ".".join(map(str, (*version[:2], version[2] + 1)))
        (old / "info.json").write_text(json.dumps(current_info))
        instrument(old, "upgrade")
        current = server(base, fixture, settings, write, work, "upgrade", environment, "ct-legacy-current")
        server(base, current, settings, write, work, "reload", environment)
        print(f"CT_LEGACY SUCCESS migration {COMMIT[:7]} et rechargement courant", flush=True)


if __name__ == "__main__":
    main()
