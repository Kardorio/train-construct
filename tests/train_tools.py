#!/usr/bin/env python3
"""Run actual north/south missions with rendering assertions, in disposable copies."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from factorio_test_engine import executable, isolated_environment


def main():
    binary = executable()
    environment = isolated_environment()
    environment["FACTORIO_BIN"] = str(binary)
    with tempfile.TemporaryDirectory(prefix="ct-train-tools-") as directory:
        project = Path(directory)
        # Build through the standard packager, without rewriting the parent's archives.
        for name in ("build.sh", "info.json", "data.lua", "data-updates.lua",
                     "data-final-fixes.lua", "control.lua", "README.md", "changelog.txt", "LICENSE"):
            if (ROOT / name).exists():
                shutil.copy2(ROOT / name, project / name)
        for name in ("scripts", "prototypes", "locale", "graphics"):
            shutil.copytree(ROOT / name, project / name)
        (project / ".tools").mkdir()
        (project / "tools").mkdir()
        for name in ("build.py", "factorio_test_engine.py"):
            shutil.copy2(ROOT / "tools" / name, project / "tools" / name)
        tests = project / "tests"
        tests.mkdir()
        shutil.copytree(ROOT / "tests/fixtures", tests / "fixtures")
        for name in ("engine.py", "circuit_stock.lua"):
            shutil.copy2(ROOT / "tests" / name, tests / name)
        engine = tests / "engine.py"
        source = engine.read_text()
        old = 'checkpoints=list(write.rglob("*ct-midmission*.zip"))'
        assert old in source, "Engine checkpoint hook changed"
        engine.write_text(source.replace(old, 'checkpoints=list(write.rglob("*ct-midmission-tools*.zip"))'))
        fixture = (ROOT / "tests/train_tools.lua").read_text()
        (tests / "engine.lua").write_text(fixture + "\n" + (ROOT / "tests/engine.lua").read_text())
        data = project / "data.lua"
        if 'require("prototypes.train-tools")' not in data.read_text():
            with data.open("a") as stream:
                stream.write('\nrequire("prototypes.train-tools")\n')
        heads = set()
        for scenario in ("engine", "engine-north"):
            result = subprocess.run([sys.executable, str(tests / "engine.py"), "--scenario", scenario],
                                    env=environment, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=180)
            print(result.stdout, end="", flush=True)
            log = (tests / f"last-{scenario}.log").read_text()
            (ROOT / f"tests/last-train-tools-{scenario}.log").write_text(log)
            if result.returncode:
                raise RuntimeError(log[-12000:] + result.stdout[-4000:])
            assert "CT_TOOLS SUCCESS" in log, log[-8000:]
            assert "CT_TOOLS saved LuaRenderObjects restored" in log, "Active visual save was not reloaded"
            for head in ("head", "rear"):
                if f'"{head}":true' in log:
                    heads.add(head)
            print("\n".join(line for line in log.splitlines() if "CT_TOOLS" in line), flush=True)
        assert heads == {"head", "rear"}, f"Both native construction heads were not exercised: {heads}"
        # Restore a single defect in this disposable source copy only.
        worker = project / "scripts/worker.lua"
        source = worker.read_text()
        hook = " Tools.pulse(d,contact)\n"
        assert source.count(hook) == 1, "Worker pulse hook changed"
        worker.write_text(source.replace(hook, ""))
        result = subprocess.run([sys.executable, str(tests / "engine.py"), "--scenario", "engine"],
                                env=environment, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=180)
        log = (tests / "last-engine.log").read_text()
        (ROOT / "tests/last-train-tools-mutation.log").write_text(log)
        expected = "Paid rail did not trigger tool pulse"
        assert result.returncode != 0 and expected in log, log[-8000:] + result.stdout[-4000:]
        assert "CT_TOOLS SUCCESS" not in log, "Fixture accepted the missing-pulse mutation"
        print("CT_TOOLS MUTATION rejected missing worker Tools.pulse", flush=True)


if __name__ == "__main__":
    main()
