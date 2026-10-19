"""Bridge engineer levels.
  python tools/bridge_gen.py          -> writes content/bridge/levels.json
  python tools/bridge_gen.py --check  -> re-verifies (exit 0 = OK)
Physics: position-based Verlet truss (nodes with gravity, beams as length constraints,
20 solver passes per frame, a beam breaks above 0.12% strain). The car is a moving load on
the two nodes of the road beam under it; the car falls if that beam is missing or broken,
or if the road sags more than 8 units. Only + - * / sqrt / floor on 64-bit floats, in the
same order as games/bridge/bridge_game.gd.
For each level the check proves: the road alone FAILS (also with a 20% lighter car), the
stored best design PASSES (also with a 20% heavier car), it fits the budget, and it costs
what is stored. `best` comes from pruning several classic trusses beam by beam while they
still pass: a good cheap design, NOT a proven optimum (3 stars = this cost or cheaper)."""
import json, math, sys, itertools, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "content/bridge/levels.json"
PHYS = {"g": 40.0, "dt": 1.0 / 60.0, "iters": 20, "limit": 0.0012, "damp": 0.98, "speed": 15.0, "settle": 60, "sag": 8.0}
YS = (-20, -10, 0, 10, 20)
SPEC = [("الجدول", 30, 3.0, []), ("النهر", 40, 3.0, []), ("الوادي", 50, 4.0, []),
        ("الركيزة", 60, 4.0, [(30, 20), (30, 10)]), ("الشاحنة", 60, 9.0, []), ("الهوة الكبرى", 70, 5.0, [])]
SP = 10.0
def sim(lv, beams, mass_scale=1.0, trace=None, P=None):
    """beams: list of (i, j) node ids. Node id = index into lv['nodes'] list of [x,y,fixed]."""
    P = P or lv["phys"]
    g = P["g"]; dt = P["dt"]; it = P["iters"]; lim = P["limit"]; damp = P["damp"]
    nodes = lv["nodes"]
    px = [float(n[0]) for n in nodes]; py = [float(n[1]) for n in nodes]
    ox = px[:]; oy = py[:]
    fixed = [bool(n[2]) for n in nodes]
    bl = []
    for (i, j) in beams:
        dx = px[j] - px[i]; dy = py[j] - py[i]
        bl.append([i, j, math.sqrt(dx * dx + dy * dy), True])
    road = {}
    for k, b in enumerate(bl):
        i, j = b[0], b[1]
        if py[i] == 0.0 and py[j] == 0.0 and abs(px[i] - px[j]) == SP:
            a = min(px[i], px[j]); road[a] = k
    gap = lv["gap"]; mcar = lv["car_mass"] * mass_scale
    car = -12.0; speed = P["speed"]
    load = [0.0] * len(nodes)
    total = P["settle"] + int((gap + 24.0) / speed / dt) + 1
    for step in range(total):
        for k in range(len(load)): load[k] = 0.0
        on_bridge = step >= P["settle"]
        cy = 0.0
        if on_bridge:
            car = car + speed * dt
            if car > 0.0 and car < gap:
                a = math.floor(car / SP) * SP
                k = road.get(a)
                if k is None or not bl[k][3]: return False, "fell", step
                i, j = bl[k][0], bl[k][1]
                if px[i] > px[j]: i, j = j, i
                t = (car - a) / SP
                load[i] = mcar * (1.0 - t); load[j] = mcar * t
                cy = py[i] + (py[j] - py[i]) * t
                if cy > P["sag"]: return False, "sag", step
            if car >= gap + 12.0: return True, "ok", step
        for k in range(len(nodes)):
            if fixed[k]: continue
            vx = (px[k] - ox[k]) * damp; vy = (py[k] - oy[k]) * damp
            ox[k] = px[k]; oy[k] = py[k]
            px[k] = px[k] + vx
            py[k] = py[k] + vy + g * (1.0 + load[k]) * dt * dt
        for _ in range(it):
            for b in bl:
                if not b[3]: continue
                i, j, L = b[0], b[1], b[2]
                dx = px[j] - px[i]; dy = py[j] - py[i]
                d = math.sqrt(dx * dx + dy * dy)
                if d < 1e-9: continue
                diff = (d - L) / d
                fi = fixed[i]; fj = fixed[j]
                if fi and fj: continue
                if fi:
                    px[j] = px[j] - dx * diff; py[j] = py[j] - dy * diff
                elif fj:
                    px[i] = px[i] + dx * diff; py[i] = py[i] + dy * diff
                else:
                    px[i] = px[i] + dx * diff * 0.5; py[i] = py[i] + dy * diff * 0.5
                    px[j] = px[j] - dx * diff * 0.5; py[j] = py[j] - dy * diff * 0.5
        mx = 0.0
        for b in bl:
            if not b[3]: continue
            dx = px[b[1]] - px[b[0]]; dy = py[b[1]] - py[b[0]]
            s = (math.sqrt(dx * dx + dy * dy) - b[2]) / b[2]
            if s < 0: s = -s
            if s > mx: mx = s
            if s > lim: b[3] = False
        if trace is not None: trace.append(mx)
    return False, "timeout", total


def cost(lv, beams):
    t = 0
    for i, j in beams:
        a, b = lv["nodes"][i], lv["nodes"][j]
        t += 10 if (a[0] == b[0] or a[1] == b[1]) else 14
    return t


def make(name, gap, car, pillars):
    nodes = []; idx = {}
    for x in range(0, gap + 1, 10):
        for y in YS:
            fx = ((x == 0 or x == gap) and y >= 0) or (x, y) in pillars
            idx[(x, y)] = len(nodes); nodes.append([float(x), float(y), fx])
    return {"name": name, "gap": float(gap), "car_mass": car, "nodes": nodes, "phys": PHYS}, idx


def valid_beam(lv, i, j):
    a, b = lv["nodes"][i], lv["nodes"][j]
    d = math.hypot(a[0] - b[0], a[1] - b[1])
    return i != j and d <= 14.2 and not (a[2] and b[2])


def road(lv, idx):
    g = int(lv["gap"]); return [(idx[(x, 0)], idx[(x + 10, 0)]) for x in range(0, g, 10)]


def band(lv, idx, yset):
    out = []
    for (a, ia), (b, ib) in itertools.combinations(sorted(idx.items()), 2):
        if a[1] in yset and b[1] in yset and valid_beam(lv, ia, ib): out.append((ia, ib))
    return out


def warren(lv, idx, y):
    g = int(lv["gap"]); b = list(road(lv, idx))
    for x in range(0, g, 10):
        for e in ((idx[(x, y)], idx[(x + 10, y)]), (idx[(x, 0)], idx[(x + 10, y)]), (idx[(x, y)], idx[(x + 10, 0)])):
            if valid_beam(lv, *e) and e not in b: b.append(e)
    return b


def passes(lv, beams):
    return sim(lv, beams, 1.0)[0] and sim(lv, beams, 1.2)[0]


def prune(lv, idx, beams):
    rset = set(road(lv, idx)); cur = list(beams)
    changed = True
    while changed:
        changed = False
        order = sorted([b for b in cur if b not in rset], key=lambda e: -cost(lv, [e]))
        for e in order:
            trial = [b for b in cur if b != e]
            if passes(lv, trial): cur = trial; changed = True
    return cur


def generate():
    levels = []
    for i, (name, gap, car, pillars) in enumerate(SPEC):
        lv, idx = make(name, gap, car, pillars)
        bases = [warren(lv, idx, 10), warren(lv, idx, -10), band(lv, idx, {0, 10}), band(lv, idx, {-10, 0}), band(lv, idx, {-10, 0, 10}), band(lv, idx, {0, 10, 20})]
        ok_bases = [b for b in bases if passes(lv, b)]
        if not ok_bases: raise SystemExit("no base passes for " + name)
        best = None
        for b in ok_bases:
            p = prune(lv, idx, b)
            if best is None or cost(lv, p) < cost(lv, best): best = p
        ref = min(ok_bases, key=lambda b: cost(lv, b))
        budget = int(math.ceil(cost(lv, ref) * 1.25 / 10.0) * 10)
        lv.update({"id": i + 1, "budget": budget, "best_cost": cost(lv, best), "best": [list(e) for e in sorted(best)], "road": [list(e) for e in road(lv, idx)]})
        levels.append(lv)
        print("level", i + 1, name, "best", cost(lv, best), "budget", budget)
    # a design found for one level may also be cheaper for another level with the same nodes
    for lv in levels:
        for other in levels:
            if other is lv or other["nodes"] != lv["nodes"]: continue
            cand = [tuple(e) for e in other["best"]]
            if cost(lv, cand) < lv["best_cost"] and passes(lv, cand):
                lv["best"] = [list(e) for e in sorted(cand)]; lv["best_cost"] = cost(lv, cand)
                print("level", lv["id"], "improved to", lv["best_cost"], "with the design of level", other["id"])
    OUT.write_text(json.dumps({"version": 1, "spacing": SP, "levels": levels}, ensure_ascii=False, indent=1), encoding="utf-8")


def check():
    ok = True
    for lv in json.loads(OUT.read_text(encoding="utf-8"))["levels"]:
        best = [tuple(e) for e in lv["best"]]; rd = [tuple(e) for e in lv["road"]]
        r_fail = not sim(lv, rd, 1.0)[0] and not sim(lv, rd, 0.8)[0]
        b_ok = sim(lv, best, 1.0)[0] and sim(lv, best, 1.2)[0]
        valid = all(valid_beam(lv, i, j) for i, j in best)
        good = r_fail and b_ok and valid and cost(lv, best) == lv["best_cost"] <= lv["budget"] and set(rd) <= set(best)
        ok = ok and good
        print("%d %-12s gap %3d car %.0f  road alone fails: %s  best design passes (+20%% load): %s  best cost %d  budget %d  beams %d  %s" % (
            lv["id"], lv["name"], lv["gap"], lv["car_mass"], r_fail, b_ok, cost(lv, best), lv["budget"], len(best), "OK" if good else "FAIL"))
    print("RESULT:", "ALL OK" if ok else "FAILED")
    return ok


if __name__ == "__main__":
    if "--check" not in sys.argv: generate()
    sys.exit(0 if check() else 1)
