#!/usr/bin/env python3
"""Exercise real Lua sprites, physical clearances and unchanged packaged PNG bytes."""
import ctypes
import ctypes.util
import hashlib
import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile
from unittest.mock import patch

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("prepare_sprites", ROOT / "tools/art/prepare_sprites.py")
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


def sprites(kind="depot"):
    # Execute the actual helper with system Lua, without Docker or the game.
    lib = ctypes.CDLL(ctypes.util.find_library("lua5.4") or "liblua5.4.so.0")
    ptr = ctypes.c_void_p
    lib.luaL_newstate.restype = ptr
    lib.luaL_openlibs.argtypes = [ptr]
    lib.luaL_loadstring.argtypes = [ptr, ctypes.c_char_p]
    lib.lua_pcallk.argtypes = [ptr, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ssize_t, ptr]
    lib.lua_tolstring.argtypes = [ptr, ctypes.c_int, ptr]
    lib.lua_tolstring.restype = ctypes.c_char_p
    lib.lua_close.argtypes = [ptr]
    script = '''
      local helper = require("prototypes.depot-graphics")
      assert(helper.stock == nil, "Stock must have no sprite helper")
      local rows = {}
      local function emit(direction, sprite)
        assert(sprite.width > 0 and sprite.height > 0)
        rows[#rows+1] = table.concat({direction,sprite.filename,sprite.x,sprite.y,
          sprite.width,sprite.height,string.format("%.17g",sprite.scale),
          string.format("%.17g",sprite.shift[1]),string.format("%.17g",sprite.shift[2])},"|")
      end
      local kind="__KIND__"
      local picture = helper[kind]()
      for _, direction in ipairs({"north","east","south","west"}) do
        if kind=="depot" then assert(#picture[direction].layers == 2, "Expected two complete railway-side bands") end
        for _, sprite in ipairs(picture[direction].layers) do emit(direction,sprite) end
      end
      return table.concat(rows,"\\n")
    '''.replace("__KIND__", kind)
    state = lib.luaL_newstate()
    try:
        lib.luaL_openlibs(state)
        result = lib.luaL_loadstring(state, script.encode())
        if not result:
            result = lib.lua_pcallk(state, 0, 1, 0, 0, None)
        output = lib.lua_tolstring(state, -1, None).decode()
        assert not result, output
    finally:
        lib.lua_close(state)
    return [line.split("|") for line in output.splitlines()]


def overlaps(a, b):
    return min(a[2], b[2])-max(a[0], b[0]) > 1e-8 and min(a[3], b[3])-max(a[1], b[1]) > 1e-8


def main():
    assert prepare.OUTPUT.read_text() == prepare.content(), "Regenerate sprite metadata"
    metadata = prepare.metadata()
    original_inspect = prepare.inspect
    def resized(path, distort=False):
        value = original_inspect(path)
        if path.name.startswith("depot-"):
            value["size"] = [v*2 for v in value["size"]]
            value["bounds"] = [v*2 for v in value["bounds"]]
            if distort:
                value["size"][0] += 1
        return value
    with patch.object(prepare, "inspect", side_effect=resized):
        scaled = prepare.metadata()
    for direction, art in metadata["depot"].items():
        assert scaled["depot"][direction]["ppu"] == art["ppu"]*2
        assert scaled["depot"][direction]["origin"] == [v*2 for v in art["origin"]]
        assert scaled["depot"][direction]["stock"] == art["stock"]
    with patch.object(prepare, "inspect", side_effect=lambda p: resized(p, distort=True)):
        try:
            prepare.metadata()
        except AssertionError as error:
            assert "aspect ratio changed" in str(error)
        else:
            raise AssertionError("Changed aspect ratio must require recalibration")
    contract = prepare.preview(metadata)
    assert contract["stock"] is False and contract["integrated"] is True
    assert "bay_half" not in metadata and "stock_tiles" not in metadata and "stock" not in metadata
    preview_spec = importlib.util.spec_from_file_location("sprite_preview", ROOT / "tools/art/make_preview.py")
    preview = importlib.util.module_from_spec(preview_spec)
    with patch.dict(sys.modules, {"prepare_sprites": prepare}):
        preview_spec.loader.exec_module(preview)
    with tempfile.TemporaryDirectory(prefix="ct-preview-no-cache-") as directory:
        output = Path(directory)/"preview.html"
        missing = Path(directory)/"absent-cache.json"
        with patch.object(prepare, "PREVIEW", missing), patch.object(preview, "OUTPUT", output):
            preview.main()
        assert output.exists() and "sprite-contract" in output.read_text()
        page = output.read_text()
        assert 'id="stock"' not in page and "model.stock" not in page and "class:'bay'" not in page
        assert "Stock intégré au bâtiment" in page
        assert not missing.exists(), "Preview recreated an unnecessary cache dependency"
    before = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
              for p in (ROOT / "graphics/entity/depot").glob("*.png")}
    groups = {}
    for direction, filename, *numbers in sprites():
        x, y, width, height, scale, sx, sy = map(float, numbers)
        candidates = contract["depot"][direction]["layers"]
        assert any(all(abs(a-b) < 1e-8 for a,b in zip(
            (x,y,width,height,scale,sx,sy),
            (s["x"],s["y"],s["width"],s["height"],s["scale"],*s["shift"])))
                   for s in candidates), "Preview contract differs from actual Lua helper"
        path = ROOT / filename.split("__/", 1)[1]
        assert path.name == f"depot-{direction}.png"
        assert all(v.is_integer() for v in (x, y, width, height)), "Non-integer native crop"
        with Image.open(path) as image:
            assert 0 <= x < x+width <= image.width and 0 <= y < y+height <= image.height
            alpha = image.convert("RGBA").getchannel("A")
            assert alpha.getextrema() == (0, 255)
            assert alpha.crop((x, y, x+width, y+height)).getbbox(), "Empty layer"
        world = (sx-width*scale/64, sy-height*scale/64,
                 sx+width*scale/64, sy+height*scale/64)
        horizontal = direction in ("east", "west")
        # These are module-local physical coordinates, not source-art formulae.
        railway = (-15, -.5, 17, 2.5) if horizontal else (-.5, -15, 2.5, 17)
        assert not overlaps(world, railway), (direction, "railway obscured", world)
        for other in groups.setdefault(direction, []):
            assert not overlaps(world, other), "Duplicate overlapping native layers"
        groups[direction].append(world)
    for direction, rects in groups.items():
        axis = 0 if direction in ("east", "west") else 1
        length = max(r[axis+2] for r in rects)-min(r[axis] for r in rects)
        assert abs(length-32) < .05, (direction, length)
        across = 1-axis
        transverse = (min(r[across] for r in rects), max(r[across+2] for r in rects))
        art = metadata["depot"][direction]
        # Two full-length bands must cover every source pixel outside the track.
        # This geometric contract rejects any artificial stock bay, independently
        # of the preview's rectangle-generation implementation.
        assert len(rects) == 2
        ends = tuple(1+(art["bounds"][i]-art["origin"][axis])/art["ppu"]
                     for i in (axis, axis+2))
        assert all(abs(r[axis]-ends[0]) < 1e-8 and abs(r[axis+2]-ends[1]) < 1e-8
                   for r in rects), (direction, "Incomplete longitudinal band")
        sides = sorted((r[across], r[across+2]) for r in rects)
        # Native integer crop rounding may widen the three-tile corridor by <2 pixels.
        assert 0 <= -.5-sides[0][1] < 1/art["ppu"]
        assert 0 <= sides[1][0]-2.5 < 1/art["ppu"]
        with Image.open(ROOT / f"graphics/entity/depot/depot-{direction}.png") as image:
            alpha = image.convert("RGBA").getchannel("A")
            alpha_bounds = alpha.getbbox()
            solid_bounds = alpha.point(lambda v: 255 if v >= 230 else 0).getbbox()
            # Fixed near-opaque source pixels inside each former 3.5-tile stock bay.
            pixel = {"north": (625,760), "east": (784,656),
                     "south": (404,754), "west": (747,353)}[direction]
            assert alpha.getpixel(pixel) >= 250, (direction, "Stock-bay source fixture changed")
            assert all(abs((pixel[i]-art["origin"][i])/art["ppu"]-art["stock"][i]) < 1.75
                       for i in (0,1)), "Fixture must be inside the former stock bay"
            point = tuple(1+(pixel[i]-art["origin"][i])/art["ppu"] for i in (0,1))
            assert any(r[0] <= point[0] < r[2] and r[1] <= point[1] < r[3] for r in rects), (
                direction, "Building art missing at former stock centre")
        expected = tuple(1+(alpha_bounds[i]-art["origin"][across])/art["ppu"]
                         for i in (across, across+2))
        assert all(abs(a-b) < 1e-8 for a,b in zip(transverse, expected)), "Transverse art clipped"
        width = transverse[1]-transverse[0]
        solid_width = (solid_bounds[across+2]-solid_bounds[across])/art["ppu"]
        assert solid_width <= 13+1e-8, (direction, "Review opaque artistic overhang", solid_width)
        print(f"{direction}: {len(rects)} native layers, length {length:.3f}, opaque width {solid_width:.3f} "
              f"(full alpha {width:.3f}) tiles; railway clear, stock integrated")
    assert set(groups) == {"north", "east", "south", "west"}
    floors={}
    for direction,filename,*numbers in sprites("floor"):
        x,y,width,height,scale,sx,sy=map(float,numbers)
        assert filename.endswith("/platform.png") and y==0
        with Image.open(ROOT/"graphics/entity/depot/platform.png") as image:
            assert image.size==(4096,512) and x+width<=image.width and height<=image.height
        candidates=contract["floor"][direction]["layers"]
        assert any((x,y,width,height,scale,sx,sy)==(s["x"],s["y"],s["width"],s["height"],s["scale"],*s["shift"]) for s in candidates)
        rect=(sx-width*scale/64,sy-height*scale/64,sx+width*scale/64,sy+height*scale/64)
        for other in floors.setdefault(direction,[]): assert not overlaps(rect,other),"Overlapping floor patches"
        floors[direction].append(rect)
    for direction,rects in floors.items():
        expected={"north":(-1,-14,3,17),"south":(-1,-13,3,17),"east":(-14,-1,17,3),"west":(-14,-1,17,3)}[direction]
        assert (min(r[0] for r in rects),min(r[1] for r in rects),max(r[2] for r in rects),max(r[3] for r in rects))==expected
        assert sum((r[2]-r[0])*(r[3]-r[1]) for r in rects)==(expected[2]-expected[0])*(expected[3]-expected[1]),"Metal floor has gaps"
    # Run the real packaging code in a temporary project: leave this tree alone.
    with tempfile.TemporaryDirectory(prefix="ct-graphics-") as tmp:
        project = Path(tmp)
        (project / "tools").mkdir()
        shutil.copy2(ROOT / "tools/build.py", project / "tools/build.py")
        shutil.copy2(ROOT / "info.json", project / "info.json")
        for folder in ("prototypes", "graphics"):
            shutil.copytree(ROOT / folder, project / folder)
        subprocess.run([sys.executable, str(project / "tools/build.py"), "package"],
                       check=True, stdout=subprocess.DEVNULL)
        with zipfile.ZipFile(next((project / "dist").glob("*.zip"))) as archive:
            for name, digest in before.items():
                member = next(n for n in archive.namelist() if n.endswith("/graphics/entity/depot/"+name))
                assert hashlib.sha256(archive.read(member)).hexdigest() == digest
    assert before == {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                      for p in (ROOT / "graphics/entity/depot").glob("*.png")}, "Source PNG changed"
    print(f"OK: Lua helper, real PNG alpha/dimensions, physical rectangles, {len(before)} identical archived PNGs")


if __name__ == "__main__":
    import os
    os.chdir(ROOT)
    main()
