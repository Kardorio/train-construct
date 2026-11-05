#!/usr/bin/env python3
"""Compile Lua and run the actual packaged runtime in isolated Factorio profiles."""
import ast
import ctypes
import ctypes.util
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
def main():
    json.loads((ROOT/"info.json").read_text())
    library=ctypes.CDLL(ctypes.util.find_library("lua5.4") or "liblua5.4.so.0")
    library.luaL_newstate.restype=ctypes.c_void_p
    library.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p]
    library.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p]
    library.lua_tolstring.restype=ctypes.c_char_p
    library.lua_close.argtypes=[ctypes.c_void_p]
    for directory in ("prototypes","scripts","tests"):
        for p in sorted((ROOT/directory).rglob("*.lua")):
            state=library.luaL_newstate()
            try:
                result=library.luaL_loadfilex(state,str(p).encode(),None)
                if result:raise RuntimeError(library.lua_tolstring(state,-1,None).decode())
            finally:library.lua_close(state)
    for p in ROOT.rglob("*.py"):
        if "dist" not in p.parts:ast.parse(p.read_text())
    state=library.luaL_newstate()
    library.luaL_openlibs.argtypes=[ctypes.c_void_p]
    library.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_ssize_t,ctypes.c_void_p]
    try:
        library.luaL_openlibs(state)
        result=library.luaL_loadfilex(state,str(ROOT/"tests/unit.lua").encode(),None)
        if not result:result=library.lua_pcallk(state,0,0,0,0,None)
        if result:raise RuntimeError(library.lua_tolstring(state,-1,None).decode())
    finally:library.lua_close(state)
    print("Syntaxe Lua/Python et métadonnées : OK",flush=True)
    subprocess.run([sys.executable,str(ROOT/"tests/test_launcher.py")],check=True)
    if "--lint" not in sys.argv:
        subprocess.run([sys.executable,str(ROOT/"tests/regressions.py")],check=True)
        subprocess.run([sys.executable,str(ROOT/"tests/graphics.py")],check=True)
        subprocess.run([sys.executable,str(ROOT/"tests/engine.py")],check=True)
        for scenario in ("engine-north","engine-stop","singleton","filters","module-north","module-east","module-south","module-west"):
            subprocess.run([sys.executable,str(ROOT/"tests/engine.py"),"--scenario",scenario],check=True)
        subprocess.run([sys.executable,str(ROOT/"tools/compare_motion.py")],check=True)
        for mutation in ("unpaired-signal","wrong-signal-pair"):
            subprocess.run([sys.executable,str(ROOT/"tests/engine.py"),"--scenario","engine-stop","--mutation",mutation],check=True)
        for mutation in ("module-rollback","module-rollback-borrowed","module-rotation","module-foreign-traffic","module-foreign-borrowed","module-borrowed-rails","module-home-axis","module-damage-stop"):
            subprocess.run([sys.executable,str(ROOT/"tests/engine.py"),"--scenario","module-east","--mutation",mutation],check=True)
        for mutation in ("filters-reservation","filters-load"):
            subprocess.run([sys.executable,str(ROOT/"tests/engine.py"),"--scenario","filters","--mutation",mutation],check=True)
        subprocess.run([sys.executable,str(ROOT/"tests/legacy.py")],check=True)
if __name__=="__main__":main()
