"""Keep the portal package distinct from the installed development prototype."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix="ct-packaging-")
        self.addCleanup(self.temp.cleanup)
        self.project=Path(self.temp.name)
        (self.project/"tools").mkdir()
        shutil.copy2(ROOT/"build.sh",self.project/"build.sh")
        shutil.copy2(ROOT/"tools/build.py",self.project/"tools/build.py")
        self.info={"name":"construction-train","version":"0.1.0","title":"Construction Train","description":"Prototype"}
        (self.project/"info.json").write_text(json.dumps(self.info))
        self.lua='return {filename="__construction-train__/graphics/depot.png", name="ct-construction-locomotive"}\n'
        (self.project/"data.lua").write_text(self.lua)
        (self.project/"changelog.txt").write_text("Version: 0.1.0\n")
        self.final_fixes='require("prototypes.pyanodon")\n'
        (self.project/"data-final-fixes.lua").write_text(self.final_fixes)
        (self.project/"prototypes").mkdir()
        (self.project/"prototypes/pyanodon.lua").write_text('return true\n')

    def build(self,*args):
        return subprocess.run([sys.executable,str(self.project/"tools/build.py"),*args],capture_output=True,text=True)

    def test_clean_checkout_does_not_advertise_missing_local_tools(self):
        command=["bash",str(self.project/"build.sh")]
        usage=subprocess.run(command,capture_output=True,text=True)
        self.assertEqual(usage.returncode,0,usage.stderr)
        for target in ("portal-demo","benchmark-scale","train-preview","sprites-preview"):
            with self.subTest(target=target):
                self.assertNotIn(target,usage.stdout)
                result=subprocess.run([*command,target],capture_output=True,text=True)
                self.assertNotEqual(result.returncode,0)
                self.assertIn("Usage:",result.stdout)
                self.assertNotIn("No such file",result.stderr)

    def test_optional_local_commands_preserve_arguments(self):
        (self.project/"tools/local_commands.sh").write_text('printf "%s\\n" "$@"\n')
        result=subprocess.run(["bash",str(self.project/"build.sh"),"local-check","value with spaces"],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(result.stdout,"local-check\nvalue with spaces\n")

    def test_beta_renames_archive_and_asset_paths_without_changing_sources(self):
        result=self.build("package","beta")
        self.assertEqual(result.returncode,0,result.stderr)
        with zipfile.ZipFile(self.project/"dist/train-construct_0.1.0.zip") as archive:
            self.assertTrue(all(name.startswith("train-construct_0.1.0/") for name in archive.namelist()))
            info=json.loads(archive.read("train-construct_0.1.0/info.json"))
            self.assertEqual(info,{**self.info,"name":"train-construct","title":"Construction Train (Beta)","description":"Beta, do not download"})
            self.assertEqual(archive.read("train-construct_0.1.0/data.lua").decode(),self.lua.replace("__construction-train__","__train-construct__"))
            self.assertEqual(archive.read("train-construct_0.1.0/data-final-fixes.lua").decode(),self.final_fixes)
            self.assertIn("train-construct_0.1.0/prototypes/pyanodon.lua",archive.namelist())
            self.assertEqual(archive.read("train-construct_0.1.0/changelog.txt"),b"Version: 0.1.0\n")
        self.assertEqual(json.loads((self.project/"info.json").read_text()),self.info)
        self.assertEqual((self.project/"data.lua").read_text(),self.lua)

    def test_default_package_keeps_development_identity(self):
        result=self.build("package")
        self.assertEqual(result.returncode,0,result.stderr)
        with zipfile.ZipFile(self.project/"dist/construction-train_0.1.0.zip") as archive:
            self.assertEqual(json.loads(archive.read("construction-train_0.1.0/info.json")),self.info)
            self.assertEqual(archive.read("construction-train_0.1.0/data.lua").decode(),self.lua)
            self.assertEqual(archive.read("construction-train_0.1.0/data-final-fixes.lua").decode(),self.final_fixes)
            self.assertEqual(archive.read("construction-train_0.1.0/changelog.txt"),b"Version: 0.1.0\n")

    def test_invalid_variant_arguments_do_not_create_an_archive(self):
        for args in (("package","unknown"),("package","beta","extra"),("devlink","beta")):
            with self.subTest(args=args):
                self.assertNotEqual(self.build(*args).returncode,0)
        self.assertFalse((self.project/"dist").exists())


if __name__=="__main__":
    unittest.main()
