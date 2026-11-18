#!/usr/bin/env python3
"""010-AC1..AC5: real engine blueprint roundtrip, builds, copy and mutation."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from factorio_test_engine import executable, isolated_environment


def run(binary, project, work, record_contract, mutation=None):
    mods, write = work / "mods", work / "write"
    mods.mkdir(parents=True)
    write.mkdir()
    info = json.loads((project / "info.json").read_text())
    subprocess.run([str(project / "build.sh"), "package"], cwd=project,
                   capture_output=True, text=True, check=True)
    with zipfile.ZipFile(project / "dist" / f"{info['name']}_{info['version']}.zip") as archive:
        archive.extractall(mods)
    mod = mods / f"{info['name']}_{info['version']}"
    if mutation:
        path, hook, replacement = {
            "restoration": ("scripts/runtime.lua", "   Settings.restore(depot,event.tags)\n", ""),
            "record-contract": ("scripts/depot-settings.lua", 'event.record.type=="blueprint"',
                                "event.record.is_blueprint"),
            "clone": ("scripts/runtime.lua", "   Settings.cloned(depot,event.source)\n", ""),
        }[mutation]
        target = mod / path
        source = target.read_text()
        assert source.count(hook) == 1, f"Mutation hook changed: {mutation}"
        target.write_text(source.replace(hook, replacement))
    with (mod / "control.lua").open("a") as output:
        fields = ",".join(f'[{json.dumps(name)}]=true' for name in sorted(record_contract))
        output.write("\nlocal record_contract={" + fields + "}\n" + (ROOT / "tests/depot_settings.lua").read_text())
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
    try:
        for command in (["--create", str(work / "test.zip")],
                        ["--test-save", str(work / "test.zip"), "--test-ticks", "4000"]):
            result = subprocess.run(base + command, capture_output=True, text=True,
                                    env=isolated_environment(), timeout=90)
            logs.append(result.stdout + result.stderr)
            print("\n".join(line for line in logs[-1].splitlines() if "CT_SETTINGS" in line), flush=True)
            if mutation and result.returncode != 0:
                expected = {"restoration": "CT_SETTINGS restoration mismatch",
                            "record-contract": "CT_SETTINGS LuaRecord unsupported member is_blueprint",
                            "clone": "CT_SETTINGS native clone settings mismatch"}[mutation]
                assert expected in logs[-1], logs[-1][-12000:]
                print(f"CT_SETTINGS MUTATION rejected {mutation}", flush=True)
                return
            assert result.returncode == 0, logs[-1][-12000:]
        assert not mutation, f"Mutation survived: {mutation}"
        assert "CT_SETTINGS ALL SUCCESS" in logs[-1], logs[-1][-12000:]
        assert (write / "script-output/ct-settings-success.txt").exists(), "Suite did not finish"
    finally:
        # Preserve evidence outside the disposable mod without touching parent
        # archives, shared locks or test logs owned by another running suite.
        label = mutation or "normal"
        with tempfile.NamedTemporaryFile(mode="w", prefix=f"ct-depot-settings-{label}-",
                                         suffix=".log", delete=False) as evidence:
            evidence.write("\n".join(logs))
            print(f"CT_SETTINGS journal : {evidence.name}", flush=True)
        durable = ROOT / "tests" / f"last-depot-settings-{'mutation' if mutation else 'normal'}.log"
        with durable.open("a" if mutation else "w") as output:
            output.write(f"CT_SETTINGS CASE {label}\n" + "\n".join(logs) + "\n")
        print(f"CT_SETTINGS journal durable : {durable}", flush=True)


def main():
    api = json.loads((ROOT / "tests/fixtures/lua-record-contract-2.1.24.json").read_text())
    assert api["application_version"] == "2.1.24" and api["class"] == "LuaRecord"
    record_contract = set(api["members"])
    assert "type" in record_contract and "is_blueprint" not in record_contract
    binary = executable()
    (ROOT / "tests/last-depot-settings-mutation.log").write_text("")
    with tempfile.TemporaryDirectory(prefix="ct-depot-settings-") as directory:
        work = Path(directory)
        project = work / "project"
        project.mkdir()
        for name in ("build.sh", "info.json", "data.lua", "data-updates.lua", "data-final-fixes.lua",
                     "control.lua", "README.md", "changelog.txt", "LICENSE", "thumbnail.png"):
            if (ROOT / name).exists():
                shutil.copy2(ROOT / name, project / name)
        for name in ("scripts", "prototypes", "locale", "graphics"):
            shutil.copytree(ROOT / name, project / name)
        (project / "tools").mkdir()
        shutil.copy2(ROOT / "tools/build.py", project / "tools/build.py")
        run(binary, project, work / "normal", record_contract)
        for mutation in ("restoration", "record-contract", "clone"):
            run(binary, project, work / mutation, record_contract, mutation=mutation)


if __name__ == "__main__":
    main()
