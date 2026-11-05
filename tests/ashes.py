#!/usr/bin/env python3
"""Exercise burnt-fuel handling in isolated official-engine profiles."""
import argparse
import fcntl
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

from pyanodon import ROOT, PROFILES, archives, resolve

sys.path.insert(0, str(ROOT / "tools"))
from factorio_test_engine import executable, isolated_environment


def run_profile(profile, selected, binary, mutation=False):
    print(f"CT_ASHES START {profile}: {', '.join(selected)}", flush=True)
    logs = []
    try:
        with tempfile.TemporaryDirectory(prefix=f"ct-ashes-{profile}-") as directory:
            work = Path(directory)
            mods, write = work / "mods", work / "write"
            mods.mkdir()
            write.mkdir()
            with (ROOT / ".tools/engine-package.lock").open("w") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                subprocess.run([str(ROOT / "build.sh"), "package", "beta"],
                               check=True, capture_output=True, text=True)
                info = json.loads((ROOT / "info.json").read_text())
                with zipfile.ZipFile(ROOT / "dist" / f"train-construct_{info['version']}.zip") as archive:
                    archive.extractall(mods)
            mod = mods / f"train-construct_{info['version']}"
            if mutation:
                worker = mod / "scripts/worker.lua"
                source = worker.read_text()
                guard = "local empty=I.unload_burnt(d)"
                if source.count(guard) != 1:
                    raise RuntimeError("Worker unload call not found unambiguously for mutation")
                worker.write_text(source.replace(guard, "local empty=true"))
            with (mod / "control.lua").open("a") as output:
                output.write("\n" + (ROOT / "tests/ashes.lua").read_text())
            for path in selected.values():
                if path is not None:
                    (mods / path.name).symlink_to(path)
            entries = [{"name": name, "enabled": True} for name in (*selected, "train-construct")]
            for path in (binary.parents[2] / "data").glob("*/info.json"):
                name = json.loads(path.read_text())["name"]
                if name not in selected:
                    entries.append({"name": name, "enabled": False})
            (mods / "mod-list.json").write_text(json.dumps({"mods": entries}))
            config = work / "config.ini"
            config.write_text(f"[path]\nread-data={binary.parents[2] / 'data'}\nwrite-data={write}\n[other]\ncheck-updates=false\n")
            base = [str(binary), "--config", str(config), "--mod-directory", str(mods)]
            for command in (["--create", str(work / "test.zip")],
                            ["--test-save", str(work / "test.zip"), "--test-ticks", "6000"]):
                result = subprocess.run(base + command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                        text=True, timeout=600, env=isolated_environment())
                logs.append(result.stdout)
                if mutation and command[0] == "--test-save":
                    expected = "CT_ASHES idle depot did not block departure"
                    if result.returncode and expected in result.stdout:
                        print(f"CT_ASHES MUTATION REJECTED {profile}: worker unload disabled", flush=True)
                        return
                    raise RuntimeError(f"{profile}: worker mutation not rejected by expected assertion\n{result.stdout[-10000:]}")
                if result.returncode:
                    raise RuntimeError(f"{profile}: engine failed\n{result.stdout[-10000:]}")
            marker = write / "script-output/ct-ashes-result.txt"
            if not marker.exists() or "CT_ASHES SUCCESS" not in logs[-1]:
                raise RuntimeError(f"{profile}: suite did not finish\n{logs[-1][-10000:]}")
            print("\n".join(line for line in logs[-1].splitlines() if "CT_ASHES" in line), flush=True)
    except subprocess.TimeoutExpired as error:
        logs.append((error.stdout or b"").decode() if isinstance(error.stdout, bytes) else error.stdout or "")
        raise
    finally:
        suffix = "-mutation" if mutation else ""
        (ROOT / "tests" / f"last-ashes-{profile}{suffix}.log").write_text("\n".join(logs))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=tuple(PROFILES), action="append")
    parser.add_argument("--mutation", action="store_true",
                        help="require rejection of a temporary worker copy with unloading disabled")
    args = parser.parse_args()
    profiles = args.profile or (("coal",) if args.mutation else ("vanilla", "coal"))
    if args.mutation and any(profile not in ("coal", "fullPy") for profile in profiles):
        parser.error("The worker mutation requires coal or fullPy")
    binary = executable()
    required = (ROOT / ".tools/factorio-headless/bin/x64/factorio").resolve()
    if binary != required:
        parser.error(f"This harness requires {required}")
    available = archives()
    failures = []
    for profile in profiles:
        try:
            selected = resolve((*PROFILES[profile], "quality"), available, binary)
            run_profile(profile, selected, binary, args.mutation)
        except (RuntimeError, subprocess.SubprocessError) as error:
            failures.append(profile)
            print(f"CT_ASHES FAIL {profile}: {error}", file=sys.stderr, flush=True)
    if failures:
        raise SystemExit("Failed profiles: " + ", ".join(failures))


if __name__ == "__main__":
    main()
