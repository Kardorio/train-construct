#!/usr/bin/env python3
"""012-AC1..AC5: isolated real-engine obstruction, robots, reload and mutants."""
import argparse
import json
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "tools"))
from factorio_test_engine import executable, isolated_environment


def copy_project(project):
    project.mkdir()
    for name in ("build.sh", "info.json", "data.lua", "data-updates.lua",
                 "data-final-fixes.lua", "control.lua", "README.md", "changelog.txt",
                 "LICENSE", "thumbnail.png"):
        if (ROOT / name).exists():
            shutil.copy2(ROOT / name, project / name)
    for name in ("scripts", "prototypes", "locale", "graphics"):
        shutil.copytree(ROOT / name, project / name)
    (project / "tools").mkdir()
    shutil.copy2(ROOT / "tools/build.py", project / "tools/build.py")


def mutate(mod, mutation):
    if mutation == "collision":
        path = mod / "scripts/obstacles.lua"
        path.write_text("return {can_place=function() return true end}\n")
        return
    path = mod / "scripts/worker.lua"
    source = path.read_text()
    if mutation == "motion":
        start = source.index("function W.motion(d)")
        old = "if option and not Obstacles.can_place(d,option.record.entity) then W.obstructed(d);return end"
        assert source[start:].count(old) == 1, "Motion mutation hook changed"
        source = source[:start] + source[start:].replace(old, "", 1)
    elif mutation == "payment":
        start, end = source.index("local function build(d)"), source.index("finish_accessory=function")
        old = "if not Obstacles.can_place(d,option.record.entity) then W.obstructed(d);return end"
        assert source[start:end].count(old) == 1, "Payment mutation hook changed"
        source = source[:start] + source[start:end].replace(old, "", 1) + source[end:]
    elif mutation == "stop":
        old = "if t.valid then t.speed=0 end"
        assert source.count(old) == 1, "Stop mutation hook changed"
        source = source.replace(old, "")
    path.write_text(source)


def run(binary, project, work, case, mutation=None, persistence=False):
    work.mkdir()
    mods, write = work / "mods", work / "write"
    mods.mkdir(); write.mkdir()
    info = json.loads((project / "info.json").read_text())
    with zipfile.ZipFile(project / "dist" / f"{info['name']}_{info['version']}.zip") as archive:
        archive.extractall(mods)
    mod = mods / f"{info['name']}_{info['version']}"
    if mutation:
        mutate(mod, mutation)
    with (mod / "control.lua").open("a") as output:
        output.write(f"\nlocal obstacles_case={json.dumps(case)}\n"
                     f"local obstacles_server={str(persistence).lower()}\n")
        output.write((ROOT / "tests/obstacles.lua").read_text())
    entries = [{"name": "base", "enabled": True}, {"name": info["name"], "enabled": True}]
    for path in (binary.parents[2] / "data").glob("*/info.json"):
        name = json.loads(path.read_text())["name"]
        if name != "base":
            entries.append({"name": name, "enabled": False})
    (mods / "mod-list.json").write_text(json.dumps({"mods": entries}))
    config = work / "config.ini"
    config.write_text(f"[path]\nread-data={binary.parents[2] / 'data'}\nwrite-data={write}\n"
                      "[other]\ncheck-updates=false\n")
    base = [str(binary), "--config", str(config), "--mod-directory", str(mods)]
    logs = []

    def command(arguments):
        try:
            result = subprocess.run(base + arguments, capture_output=True, text=True,
                                    env=isolated_environment(), timeout=120)
        except subprocess.TimeoutExpired as error:
            partial = error.stdout or b""
            logs.append(partial.decode(errors="replace") if isinstance(partial, bytes) else partial)
            raise
        logs.append(result.stdout + result.stderr)
        print("\n".join(line for line in logs[-1].splitlines() if "CT_OBSTACLES" in line), flush=True)
        return result

    try:
        created = command(["--create", str(work / "test.zip")])
        assert created.returncode == 0, logs[-1][-10000:]
        if persistence:
            settings = work / "server-settings.json"
            settings.write_text(json.dumps({"name": "CT obstacles isolated test",
                "description": "Local obstruction persistence test",
                "visibility": {"public": False, "lan": False}, "auto_pause": False,
                "require_user_verification": False, "autosave_interval": 0}))
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as listener:
                listener.bind(("127.0.0.1", 0)); port = listener.getsockname()[1]
            live = work / "live.log"
            marker = write / "script-output/ct-obstacles-success.txt"
            with live.open("w") as output:
                process = subprocess.Popen(base + ["--start-server", str(work / "test.zip"),
                    "--server-settings", str(settings), "--bind", "127.0.0.1", "--port", str(port)],
                    stdout=output, stderr=subprocess.STDOUT, env=isolated_environment())
                try:
                    deadline = time.monotonic() + 100
                    while time.monotonic() < deadline:
                        if marker.exists() or process.poll() is not None or "Error while running event" in live.read_text():
                            break
                        time.sleep(.1)
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill(); process.wait(timeout=5)
            logs.append(live.read_text())
            assert marker.exists(), logs[-1][-10000:]
            saves = list(write.rglob("*ct-obstacles-blocked*.zip"))
            assert len(saves) == 1, "Missing unique real obstruction checkpoint"
            marker.unlink()
            result = command(["--test-save", str(saves[0]), "--test-ticks", "15000"])
            assert result.returncode == 0 and "CT_OBSTACLES RELOADED blocked" in logs[-1], logs[-1][-10000:]
        else:
            result = command(["--test-save", str(work / "test.zip"), "--test-ticks", "40000"])
            if mutation:
                expected = {"collision": "blocked approach moved", "motion": "dynamic stop was not immediate",
                            "stop": "dynamic stop was not immediate", "payment": "payment attempted while obstructed"}[mutation]
                assert result.returncode != 0 and "CT_OBSTACLES " + expected in logs[-1], logs[-1][-10000:]
                print(f"CT_OBSTACLES MUTATION REJECTED {mutation}", flush=True)
                return
            assert result.returncode == 0, logs[-1][-10000:]
        assert "CT_OBSTACLES ALL SUCCESS" in logs[-1], logs[-1][-10000:]
        assert (write / "script-output/ct-obstacles-success.txt").exists(), "Suite did not finish"
    finally:
        label = mutation or ("reload" if persistence else case)
        (ROOT / "tests" / f"last-obstacles-{label}.log").write_text("\n".join(logs))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=("all", "static", "dynamic", "payment", "fork", "neighbor", "guards"), default="all")
    parser.add_argument("--mutation", action="store_true", help="also require rejection of four private mutants")
    parser.add_argument("--reload", action="store_true", help="also produce and reload a real blocked save")
    args = parser.parse_args()
    binary = executable()
    version = subprocess.run([str(binary), "--version"], capture_output=True, text=True,
                             env=isolated_environment(), timeout=10, check=True).stdout
    assert "headless" in version.lower(), "Official headless engine required"
    with tempfile.TemporaryDirectory(prefix="ct-obstacles-") as directory:
        work = Path(directory)
        project = work / "project"
        copy_project(project)
        subprocess.run([str(project / "build.sh"), "package"], cwd=project,
                       capture_output=True, text=True, check=True)
        run(binary, project, work / "normal", args.case)
        if args.reload:
            run(binary, project, work / "reload", "static", persistence=True)
        if args.mutation:
            for mutation, case in (("collision", "static"), ("motion", "dynamic"),
                                   ("stop", "dynamic"), ("payment", "payment")):
                run(binary, project, work / mutation, case, mutation=mutation)


if __name__ == "__main__":
    main()
