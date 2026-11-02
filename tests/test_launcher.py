"""Keep tests from falling back to the player's Steam installation."""
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from factorio_test_engine import executable, isolated_environment


class LauncherTests(unittest.TestCase):
    def test_known_steam_path_is_rejected_before_execution(self):
        with patch.dict(os.environ, {"FACTORIO_BIN": "/tmp/steamapps/common/Factorio/bin/x64/factorio"}, clear=True), patch("factorio_test_engine.subprocess.run") as run:
            with self.assertRaisesRegex(SystemExit, "Steam refusé"):
                executable()
            run.assert_not_called()

    def test_renamed_steam_build_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / "factorio"
            binary.touch()
            with patch.dict(os.environ, {"FACTORIO_BIN": str(binary)}, clear=True), patch("factorio_test_engine.subprocess.run", return_value=Mock(stdout="Version: 2.1.24 (build 87808, linux64, steam, space-age)")):
                with self.assertRaisesRegex(SystemExit, "Steam ou non reconnu"):
                    executable()

    def test_headless_works_but_cannot_be_used_for_graphics(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / "factorio"
            binary.touch()
            with patch.dict(os.environ, {"FACTORIO_BIN": str(binary)}, clear=True), patch("factorio_test_engine.subprocess.run", return_value=Mock(stdout="Version: 2.1.24 (build 87808, linux64, headless)")):
                self.assertEqual(executable(), binary)
                with self.assertRaisesRegex(SystemExit, "exigent une version autonome"):
                    executable(graphical=True)

    def test_missing_graphical_build_never_falls_back_to_steam(self):
        with patch.dict(os.environ, {"FACTORIO_GUI_BIN": "/tmp/ct-absent-standalone/factorio"}, clear=True), patch("factorio_test_engine.subprocess.run") as run:
            with self.assertRaisesRegex(SystemExit, "Moteur de test absent"):
                executable(graphical=True)
            run.assert_not_called()

    def test_steam_identity_is_not_inherited(self):
        with patch.dict(os.environ, {"SteamAppId": "427520", "SteamGameId": "427520", "SteamOverlayGameId": "427520", "PATH": "/usr/bin"}, clear=True):
            self.assertEqual(isolated_environment(), {"PATH": "/usr/bin"})

    def test_graphical_override_uses_the_standalone_client(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / "factorio"
            binary.touch()
            with patch.dict(os.environ, {"FACTORIO_GUI_BIN": str(binary), "FACTORIO_BIN": "/tmp/steamapps/server/factorio"}, clear=True), patch("factorio_test_engine.subprocess.run", return_value=Mock(stdout="Version: 2.1.24 (build 87808, linux64, full, space-age)")) as run:
                self.assertEqual(executable(graphical=True), binary)
                self.assertEqual(run.call_args.args[0], [str(binary), "--version"])


if __name__ == "__main__":
    unittest.main()
