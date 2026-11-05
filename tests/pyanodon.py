#!/usr/bin/env python3
"""Run isolated native crafting checks against the installed real Py archives."""
import argparse
import fcntl
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from factorio_test_engine import executable, isolated_environment

PROFILES = {
    "vanilla": (),
    "coal": ("pycoalprocessing",),
    "industry": ("pyindustry",),
    "fullPy": ("pycoalprocessing", "pyindustry", "pyfusionenergy", "pyrawores",
               "pypetroleumhandling", "pyhightech", "pyalienlife", "pyalternativeenergy"),
}
DEPENDENCY = re.compile(r"^\s*(\(\?\)|[?!~+])?\s*([\w-]+)(?:\s*(>=|<=|=|>|<)\s*([\d.]+))?\s*$")


def version(value):
    return tuple(int(part) for part in value.split("."))


def archives():
    result = {}
    for path in (Path.home() / ".factorio/mods").glob("*.zip"):
        match = re.fullmatch(r"(.+)_(\d+\.\d+\.\d+)\.zip", path.name)
        if match:
            name, number = match.groups()
            if name not in result or version(number) > version(result[name][0]):
                result[name] = (number, path)
    return result


def resolve(seeds, available, binary):
    selected = {}
    builtin = {}
    for path in (binary.parents[2] / "data").glob("*/info.json"):
        info = json.loads(path.read_text())
        builtin[info["name"]] = info

    def visit(name, operator=None, minimum=None):
        if name in builtin:
            info = builtin[name]
        else:
            if name not in available:
                raise RuntimeError(f"Missing required mod archive: {name}")
            number, path = available[name]
            with zipfile.ZipFile(path) as archive:
                roots = [member for member in archive.namelist()
                         if member.count("/") == 1 and member.endswith("/info.json")]
                if len(roots) != 1:
                    raise RuntimeError(f"Ambiguous mod metadata in {path}")
                info = json.loads(archive.read(roots[0]))
            if info["name"] != name or info["version"] != number:
                raise RuntimeError(f"Archive filename/metadata mismatch: {path}")
            source = ROOT / ".tools/py-sources" / name / "info.json"
            if source.exists():
                extracted = json.loads(source.read_text())
                if extracted != info:
                    raise RuntimeError(f"Extracted source metadata differs from latest archive: {name}")
                info = extracted
        if operator:
            actual, expected = version(info["version"]), version(minimum)
            valid = {">=": actual >= expected, "<=": actual <= expected,
                     "=": actual == expected, ">": actual > expected, "<": actual < expected}
            if not valid[operator]:
                raise RuntimeError(f"Unsatisfied dependency: {name} {operator} {minimum} (installed {info['version']})")
        if name in selected:
            return
        selected[name] = None if name in builtin else available[name][1]
        for dependency in info.get("dependencies", ["base"]):
            match = DEPENDENCY.fullmatch(dependency)
            if not match:
                raise RuntimeError(f"Unsupported dependency: {dependency}")
            prefix, child, comparison, required = match.groups()
            if prefix not in ("?", "(?)", "!"):
                visit(child, comparison, required)

    visit("base")
    for seed in seeds:
        visit(seed)
    return selected


def run_profile(profile, selected, binary):
    started = time.monotonic()
    print(f"CT_PY START {profile}: {', '.join(selected)}", flush=True)
    with tempfile.TemporaryDirectory(prefix=f"ct-py-{profile}-") as directory:
        work = Path(directory)
        mods, write = work / "mods", work / "write"
        mods.mkdir(); write.mkdir()
        with (ROOT / ".tools/engine-package.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            subprocess.run([str(ROOT / "build.sh"), "package", "beta"], check=True, capture_output=True, text=True)
            info = json.loads((ROOT / "info.json").read_text())
            with zipfile.ZipFile(ROOT / "dist" / f"train-construct_{info['version']}.zip") as archive:
                archive.extractall(mods)
        mod = mods / f"train-construct_{info['version']}"
        with (mod / "control.lua").open("a") as output:
            output.write("\n" + (ROOT / "tests/pyanodon.lua").read_text())
        for name, path in selected.items():
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
        logs = []
        try:
            for command in (["--create", str(work / "test.zip")],
                            ["--test-save", str(work / "test.zip"), "--test-ticks", "3600"]):
                result = subprocess.run(base + command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                        text=True, timeout=600, env=isolated_environment())
                logs.append(result.stdout)
                if result.returncode:
                    raise RuntimeError(f"{profile}: engine failed\n{result.stdout[-10000:]}")
            marker = write / "script-output/ct-py-result.txt"
            if not marker.exists() or "CT_PY SUCCESS" not in logs[-1]:
                raise RuntimeError(f"{profile}: native crafting did not finish\n{logs[-1][-10000:]}")
            print("\n".join(line for line in logs[-1].splitlines() if "CT_PY" in line), flush=True)
            print(f"CT_PY PASS {profile} ({time.monotonic() - started:.1f}s)", flush=True)
        except subprocess.TimeoutExpired as error:
            logs.append((error.stdout or b"").decode() if isinstance(error.stdout, bytes) else error.stdout or "")
            raise
        finally:
            (ROOT / "tests" / f"last-py-{profile}.log").write_text("\n".join(logs))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=tuple(PROFILES), action="append")
    args = parser.parse_args()
    binary = executable()
    required = (ROOT / ".tools/factorio-headless/bin/x64/factorio").resolve()
    if binary != required:
        parser.error(f"This harness requires {required}")
    available = archives()
    failures = []
    for profile in args.profile or PROFILES:
        try:
            run_profile(profile, resolve(PROFILES[profile], available, binary), binary)
        except (RuntimeError, subprocess.SubprocessError) as error:
            failures.append(profile)
            print(f"CT_PY FAIL {profile}: {error}", file=sys.stderr, flush=True)
    if failures:
        raise SystemExit("Failed profiles: " + ", ".join(failures))


if __name__ == "__main__":
    main()
