"""Estimates what the Release preset packs (project files only, before Godot import/compression).
The APK also contains the Godot engine library (the largest part, not controllable without a
custom export template built on a PC)."""
import fnmatch, pathlib, configparser, re
ROOT = pathlib.Path(__file__).resolve().parents[1]
cfg = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
m = re.search(r'name="Android Release".*?exclude_filter="([^"]*)"', cfg, re.S)
excl = [x.strip() for x in m.group(1).split(",")]
groups = {}
total = 0
for f in ROOT.rglob("*"):
    if not f.is_file() or ".godot" in f.parts or "__pycache__" in f.parts or f.name == "export_presets.cfg":
        continue
    rel = f.relative_to(ROOT).as_posix()
    if any(fnmatch.fnmatch(rel, e) for e in excl):
        continue
    g = rel.split("/")[0] if "/" in rel else "(root)"
    if rel.startswith("assets/"):
        g = "/".join(rel.split("/")[:2])
    groups[g] = groups.get(g, 0) + f.stat().st_size
    total += f.stat().st_size
for g, s in sorted(groups.items(), key=lambda x: -x[1]):
    print(f"{s/1024:8.0f} KB  {g}")
print(f"{total/1024:8.0f} KB  TOTAL project files in release")
