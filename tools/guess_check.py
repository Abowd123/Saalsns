"""Guess the picture content.
  python tools/guess_check.py          -> builds content/guess_picture/items.json + levels.json
                                          from tools/guess_items_src.py and flags.json
  python tools/guess_check.py --check  -> verifies them (exit 0 = OK)
  python tools/guess_check.py --sheet out.png -> renders every picture on one sheet (needs cairosvg)
Checks: >= 150 items, unique ids, unique names after Arabic normalisation, every SVG is
valid XML and renders with visible pixels (if cairosvg is installed), every flag reference
exists, every level pool has >= 10 items, every category has >= 4 items (3 distractors from
the same category), and every item belongs to at least one level."""
import json, sys, re, pathlib, io
import xml.etree.ElementTree as ET
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "content/guess_picture"
CATS = {"shape": "الأشكال", "fruit": "الفواكه والخضار", "animal": "الحيوانات", "tool": "الأدوات", "landmark": "المعالم", "flag": "الأعلام"}
QUESTION = {"shape": "ما اسم هذا الشكل؟", "fruit": "ما هذا؟", "animal": "ما هذا الحيوان؟", "tool": "ما هذه الأداة؟", "landmark": "ما هذا المعلم؟", "flag": "علم أي دولة؟"}
LEVELS = [
    ("الأشكال", ["shape"]), ("الفواكه والخضار", ["fruit"]), ("الحيوانات", ["animal"]), ("الأدوات", ["tool"]),
    ("الأعلام", ["flag"]), ("المعالم", ["landmark"]), ("حيوانات وفواكه", ["animal", "fruit"]),
    ("أدوات وأشكال", ["tool", "shape"]), ("أعلام ومعالم", ["flag", "landmark"]), ("كل شيء", list(CATS)),
]
SVG_HEAD = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">%s</svg>'


def norm(s):
    s = re.sub("[\u064B-\u0652\u0640]", "", s)
    s = re.sub("[أإآ]", "ا", s).replace("ة", "ه").replace("ى", "ي")
    return re.sub(r"\s+", " ", s).strip()


def build():
    src = {}
    exec((ROOT / "tools/guess_items_src.py").read_text(encoding="utf-8"), src)
    items = []
    for cat, d in [("shape", src["shapes"]), ("fruit", src["fruit"]), ("animal", src["animals"]), ("tool", src["tools"]), ("landmark", src["landmarks"])]:
        for k, (name, body) in d.items():
            items.append({"id": "%s_%s" % (cat, k), "cat": cat, "name": name, "svg": body})
    names = {}
    for line in (ROOT / "content/knowledge/countries.tsv").read_text(encoding="utf-8").splitlines()[1:]:
        c = line.split("\t")
        if len(c) >= 2:
            names[c[0]] = c[1]
    for f in json.loads((ROOT / "content/knowledge/flags.json").read_text(encoding="utf-8"))["flags"]:
        items.append({"id": "flag_" + f["id"], "cat": "flag", "name": names[f["id"]], "flag": f["id"]})
    for f in src["new_flags"]:
        spec = {k: v for k, v in f.items() if k != "name"}
        items.append({"id": "flag_" + f["id"], "cat": "flag", "name": f["name"], "spec": spec})
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "items.json").write_text(json.dumps({"version": 1, "svg_head": SVG_HEAD, "items": items}, ensure_ascii=False, indent=0), encoding="utf-8")
    lv = [{"id": i + 1, "name": n, "cats": c} for i, (n, c) in enumerate(LEVELS)]
    (OUT / "levels.json").write_text(json.dumps({"version": 1, "categories": CATS, "questions": QUESTION, "levels": lv}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("wrote", len(items), "items,", len(lv), "levels")


def render(body, px=100):
    import cairosvg
    from PIL import Image
    png = cairosvg.svg2png(bytestring=(SVG_HEAD % body).encode(), output_width=px, output_height=px)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def check():
    data = json.loads((OUT / "items.json").read_text(encoding="utf-8"))
    L = json.loads((OUT / "levels.json").read_text(encoding="utf-8"))
    flags = {f["id"] for f in json.loads((ROOT / "content/knowledge/flags.json").read_text(encoding="utf-8"))["flags"]}
    items = data["items"]; errs = []
    try:
        import cairosvg  # noqa
        can_render = True
    except ImportError:
        can_render = False
    ids, nm, per = set(), {}, {}
    for it in items:
        if it["id"] in ids: errs.append("duplicate id " + it["id"])
        ids.add(it["id"])
        n = norm(it["name"])
        if n in nm: errs.append("duplicate name %s (%s, %s)" % (it["name"], nm[n], it["id"]))
        nm[n] = it["id"]
        if it["cat"] not in L["categories"]: errs.append("unknown category " + it["cat"])
        per[it["cat"]] = per.get(it["cat"], 0) + 1
        if "svg" in it:
            try:
                ET.fromstring(SVG_HEAD % it["svg"])
            except ET.ParseError as e:
                errs.append("bad svg %s: %s" % (it["id"], e))
                continue
            if can_render:
                a = render(it["svg"], 64).split()[3]
                vis = sum(1 for p in a.getdata() if p > 100) / (64 * 64.0)
                if vis < 0.05: errs.append("picture almost empty: %s (%.0f%%)" % (it["id"], vis * 100))
        elif "flag" in it:
            if it["flag"] not in flags: errs.append("missing flag " + it["flag"])
        elif "spec" not in it:
            errs.append("no picture " + it["id"])
    for c, n in per.items():
        if n < 4: errs.append("category %s has %d items (< 4)" % (c, n))
    covered = set()
    for lv in L["levels"]:
        pool = [it for it in items if it["cat"] in lv["cats"]]
        covered |= {it["id"] for it in pool}
        if len(pool) < 10: errs.append("level %d pool %d < 10" % (lv["id"], len(pool)))
        print("level %2d %-16s pool %d" % (lv["id"], lv["name"], len(pool)))
    if len(covered) != len(items): errs.append("items not used by any level")
    if len(L["levels"]) != 10: errs.append("need 10 levels")
    if len(items) < 150: errs.append("only %d items" % len(items))
    print("items %d (%s)  unique names %d  rendered=%s" % (len(items), ", ".join("%s %d" % (c, n) for c, n in per.items()), len(nm), can_render))
    for e in errs: print("FAIL", e)
    print("RESULT:", "ALL OK" if not errs else "FAILED")
    return not errs


def sheet(path):
    from PIL import Image, ImageDraw
    data = json.loads((OUT / "items.json").read_text(encoding="utf-8"))
    its = [i for i in data["items"] if "svg" in i]
    cols, W = 10, 120
    img = Image.new("RGB", (cols * W, ((len(its) + cols - 1) // cols) * (W + 14)), (30, 40, 67))
    dr = ImageDraw.Draw(img)
    for i, it in enumerate(its):
        im = render(it["svg"], 110)
        x, y = (i % cols) * W, (i // cols) * (W + 14)
        img.paste(im, (x + 5, y + 2), im); dr.text((x + 4, y + 112), it["id"][:18], fill=(220, 220, 220))
    img.save(path)


if __name__ == "__main__":
    if "--sheet" in sys.argv:
        sheet(sys.argv[sys.argv.index("--sheet") + 1]); sys.exit(0)
    if "--check" not in sys.argv:
        build()
    sys.exit(0 if check() else 1)
