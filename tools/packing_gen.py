"""Space challenge (packing) levels: fixed-orientation pieces (no rotation) must fill the
board exactly, without overlap.
  python tools/packing_gen.py          -> writes content/packing/levels.json
  python tools/packing_gen.py --check  -> re-verifies the file (exit 0 = OK)
Each level is built by cutting the board into pieces, so it has a solution by
construction. The check does NOT trust that: it re-solves every level with an exact-cover
search (Algorithm X), verifies the stored solution, and counts all solutions (capped)."""
import json, random, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "content/packing/levels.json"
CAP = 5000
# (w, h, holes, piece size range, name)
SPEC = [
    (4, 3, [], (3, 4), "البداية"), (4, 4, [], (3, 4), "المربع"), (5, 4, [], (3, 5), "الصندوق"),
    (5, 5, [(2, 2)], (3, 5), "الفتحة"), (6, 4, [], (4, 5), "الرف"), (6, 5, [(0, 0), (5, 4)], (4, 5), "الزوايا"),
    (6, 6, [], (4, 5), "الحاوية"), (7, 5, [(3, 2)], (4, 5), "المخزن"), (7, 6, [(0, 5), (6, 0)], (4, 6), "الشاحنة"),
    (8, 6, [(3, 2), (4, 3)], (4, 6), "التحدي الأكبر"),
]


def cut(cells, rng, lo, hi):
    """Random partition of `cells` into connected pieces of size lo..hi (retries until ok)."""
    for _ in range(4000):
        free = set(cells); pieces = []; ok = True
        while free:
            start = min(free, key=lambda p: (p[1], p[0]))
            want = rng.randint(lo, hi)
            pc = [start]; free.discard(start)
            while len(pc) < want:
                fr = [(x + dx, y + dy) for x, y in pc for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if (x + dx, y + dy) in free]
                if not fr: break
                n = rng.choice(fr); pc.append(n); free.discard(n)
            if len(pc) < lo: ok = False; break
            pieces.append(pc)
        if ok:
            return pieces
    return None


def norm(pc):
    mx = min(x for x, _ in pc); my = min(y for _, y in pc)
    return sorted((x - mx, y - my) for x, y in pc)


def solve(w, h, holes, shapes, cap=CAP):
    """Algorithm X: columns = board cells + one per piece. Returns (count, first)."""
    cells = [(x, y) for y in range(h) for x in range(w) if (x, y) not in holes]
    cset = set(cells)
    rows = []
    for pi, sh in enumerate(shapes):
        for oy in range(h):
            for ox in range(w):
                cov = [(x + ox, y + oy) for x, y in sh]
                if all(c in cset for c in cov):
                    rows.append((pi, (ox, oy), cov))
    cols = {("c", c): set() for c in cells}
    for pi in range(len(shapes)): cols[("p", pi)] = set()
    for ri, (pi, _, cov) in enumerate(rows):
        cols[("p", pi)].add(ri)
        for c in cov: cols[("c", c)].add(ri)
    rowcols = [[("p", pi)] + [("c", c) for c in cov] for pi, _, cov in rows]
    res = {"n": 0, "first": None}

    def select(r):
        out = []
        for j in rowcols[r]:
            for i in cols[j]:
                for k in rowcols[i]:
                    if k != j: cols[k].discard(i)
            out.append(cols.pop(j))
        return out

    def deselect(r, saved):
        for j in reversed(rowcols[r]):
            cols[j] = saved.pop()
            for i in cols[j]:
                for k in rowcols[i]:
                    if k != j: cols[k].add(i)

    sol = []
    def rec():
        if res["n"] >= cap: return
        if not cols:
            res["n"] += 1
            if res["first"] is None: res["first"] = list(sol)
            return
        c = min(cols, key=lambda k: len(cols[k]))
        for r in sorted(cols[c]):
            sol.append(r); saved = select(r); rec(); deselect(r, saved); sol.pop()
            if res["n"] >= cap: return
    rec()
    first = None
    if res["first"] is not None:
        first = sorted([[rows[r][0], rows[r][1][0], rows[r][1][1]] for r in res["first"]])
    return res["n"], first


def verify_solution(w, h, holes, shapes, solution):
    seen = set()
    for pi, ox, oy in solution:
        for x, y in shapes[pi]:
            c = (x + ox, y + oy)
            if not (0 <= c[0] < w and 0 <= c[1] < h) or c in holes or c in seen: return False
            seen.add(c)
    return len(seen) == w * h - len(holes) and sorted(p[0] for p in solution) == list(range(len(shapes)))


def generate():
    levels = []
    for i, (w, h, holes, (lo, hi), name) in enumerate(SPEC):
        holes = [tuple(p) for p in holes]
        cells = [(x, y) for y in range(h) for x in range(w) if (x, y) not in holes]
        best = None
        for k in range(60 if i < 9 else 25):
            rng = random.Random(9100 + i * 97 + k)
            pcs = cut(cells, rng, lo, hi)
            if pcs is None: continue
            shapes = [norm(p) for p in pcs]
            if len(set(map(tuple, shapes))) < len(shapes) * 0.6: continue
            n, first = solve(w, h, set(holes), shapes)
            key = (n, -len(shapes))
            if best is None or key < best[0]:
                best = (key, shapes, n, first)
            if n == 1 and i >= 3: break
        _, shapes, n, first = best
        levels.append({"id": i + 1, "name": name, "w": w, "h": h, "holes": [list(p) for p in holes],
                       "pieces": [[list(c) for c in sh] for sh in shapes], "solution": first, "solutions": n})
    OUT.write_text(json.dumps({"version": 1, "levels": levels}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("wrote", len(levels))


def check():
    ok = True
    for lv in json.loads(OUT.read_text(encoding="utf-8"))["levels"]:
        holes = {tuple(p) for p in lv["holes"]}
        shapes = [[tuple(c) for c in sh] for sh in lv["pieces"]]
        area = sum(len(s) for s in shapes)
        n, first = solve(lv["w"], lv["h"], holes, shapes)
        good = verify_solution(lv["w"], lv["h"], holes, shapes, lv["solution"]) and area == lv["w"] * lv["h"] - len(holes) and n >= 1 and n == lv["solutions"]
        ok = ok and good
        print("%2d %-14s %dx%d holes %d pieces %d  solutions %s%s  stored solution valid: %s  %s" % (
            lv["id"], lv["name"], lv["w"], lv["h"], len(holes), len(shapes), (">=%d" % CAP) if n >= CAP else n,
            " (unique)" if n == 1 else "", verify_solution(lv["w"], lv["h"], holes, shapes, lv["solution"]), "OK" if good else "FAIL"))
    print("RESULT:", "ALL OK" if ok else "FAILED")
    return ok


if __name__ == "__main__":
    if "--check" not in sys.argv: generate()
    sys.exit(0 if check() else 1)
