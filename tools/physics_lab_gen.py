"""Physics lab levels: drop a ball, change ramp angles, move pegs, so gravity and bounces
carry the ball into the basket.
  python tools/physics_lab_gen.py          -> searches layouts, writes content/physics_lab/levels.json
  python tools/physics_lab_gen.py --check  -> re-verifies the file (exit 0 = OK)
The simulation uses only + - * / and sqrt on 64-bit floats (ramp angles are stored as
endpoints, no trig at runtime), in exactly the order of games/physics_lab/physics_lab_game.gd,
so it gives the same result in Godot. For every level the check simulates EVERY combination
of the controls and reports how many win; the start setting must fail and the stored
solution must win, also with small perturbations (drop x +/-0.3, gravity +/-1%), so it does
not depend on the last decimal."""
import json, math, random, sys, itertools, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "content/physics_lab/levels.json"
W, H = 100.0, 140.0
R = 3.2
G = 160.0
DT = 1.0 / 120.0
STEPS = 1200
E_NORMAL = 0.35
E_BOUNCY = 0.9
FRICTION = 0.998
WIN_TIME = 0.25


def seg_collide(s, b, e):
    ax, ay, bx, by = s
    px, py = b[0], b[1]
    dx = bx - ax; dy = by - ay
    L2 = dx * dx + dy * dy
    t = ((px - ax) * dx + (py - ay) * dy) / L2
    if t < 0.0: t = 0.0
    if t > 1.0: t = 1.0
    qx = ax + t * dx; qy = ay + t * dy
    nx = px - qx; ny = py - qy
    d2 = nx * nx + ny * ny
    if d2 >= R * R or d2 < 1e-12: return
    d = math.sqrt(d2)
    nx = nx / d; ny = ny / d
    b[0] = qx + nx * R; b[1] = qy + ny * R
    vn = b[2] * nx + b[3] * ny
    if vn < 0.0:
        b[2] = b[2] - (1.0 + e) * vn * nx
        b[3] = b[3] - (1.0 + e) * vn * ny
    b[2] = b[2] * FRICTION; b[3] = b[3] * FRICTION


def peg_collide(p, b):
    cx, cy, pr = p
    nx = b[0] - cx; ny = b[1] - cy
    d2 = nx * nx + ny * ny
    rr = pr + R
    if d2 >= rr * rr or d2 < 1e-12: return
    d = math.sqrt(d2)
    nx = nx / d; ny = ny / d
    b[0] = cx + nx * rr; b[1] = cy + ny * rr
    vn = b[2] * nx + b[3] * ny
    if vn < 0.0:
        b[2] = b[2] - (1.0 + 0.5) * vn * nx
        b[3] = b[3] - (1.0 + 0.5) * vn * ny


def world(lv, choice):
    """Segments in collision order: walls, static, ramps (chosen), basket. Pegs separately."""
    segs = [([0.0, -40.0, 0.0, H], E_NORMAL), ([W, -40.0, W, H], E_NORMAL)]
    for s in lv["static"]: segs.append((s, E_NORMAL))
    for i, rp in enumerate(lv["ramps"]):
        segs.append((rp["options"][choice["ramps"][i]], E_BOUNCY if rp.get("bouncy") else E_NORMAL))
    bx, by, bw, bh = lv["basket"]
    segs.append(([bx, by, bx, by + bh], E_NORMAL)); segs.append(([bx, by + bh, bx + bw, by + bh], 0.1)); segs.append(([bx + bw, by + bh, bx + bw, by], E_NORMAL))
    pegs = [[pg["options"][choice["pegs"][i]][0], pg["options"][choice["pegs"][i]][1], pg["r"]] for i, pg in enumerate(lv["pegs"])]
    return segs, pegs


def simulate(lv, choice, dx=0.0, gs=1.0, trace=None):
    segs, pegs = world(lv, choice)
    b = [lv["drops"][choice["drop"]] + dx, 6.0, 0.0, 0.0]
    g = G * gs
    bx, by, bw, bh = lv["basket"]
    inside = 0.0
    for step in range(STEPS):
        b[3] = b[3] + g * DT
        b[0] = b[0] + b[2] * DT
        b[1] = b[1] + b[3] * DT
        for s, e in segs: seg_collide(s, b, e)
        for p in pegs: peg_collide(p, b)
        if trace is not None and step % 6 == 0: trace.append((b[0], b[1]))
        if b[0] > bx and b[0] < bx + bw and b[1] > by and b[1] < by + bh:
            inside = inside + DT
            if inside >= WIN_TIME: return True, step
        else:
            inside = 0.0
        if b[1] > H + 10.0: return False, step
    return False, STEPS


def combos(lv):
    a = [range(len(lv["drops"]))] + [range(len(r["options"])) for r in lv["ramps"]] + [range(len(p["options"])) for p in lv["pegs"]]
    nr = len(lv["ramps"])
    for t in itertools.product(*a):
        yield {"drop": t[0], "ramps": list(t[1:1 + nr]), "pegs": list(t[1 + nr:])}


def robust(lv, c):
    return all(simulate(lv, c, dx, gs)[0] for dx, gs in ((0, 1), (0.3, 1), (-0.3, 1), (0, 1.01), (0, 0.99)))


def ramp(px, py, L, angles):
    out = []
    for a in angles:
        r = math.radians(a)
        out.append([round(px - L / 2 * math.cos(r), 2), round(py - L / 2 * math.sin(r), 2), round(px + L / 2 * math.cos(r), 2), round(py + L / 2 * math.sin(r), 2)])
    return out


def rseg(rng, x0, x1, y0, y1):
    px = rng.uniform(x0, x1); py = rng.uniform(y0, y1); L = rng.uniform(18, 30)
    a = rng.choice([-1, 1]) * rng.uniform(12, 32)
    return ramp(px, py, L, [a])[0]


ANG = [-30, -15, 0, 15, 30]
def candidate(kind, rng):
    bx = rng.choice([10, 30, 50, 70]) + rng.uniform(-4, 4)
    lv = {"basket": [round(bx, 1), 118.0, 18.0, 14.0], "static": [], "ramps": [], "pegs": [], "drops": [50.0]}
    if kind == "drop":
        lv["drops"] = [12.0, 27.0, 42.0, 57.0, 72.0, 87.0]
        lv["static"] = [rseg(rng, 10, 90, 30, 95) for _ in range(4)]
    elif kind == "ramp":
        lv["drops"] = [round(rng.uniform(20, 80), 1)]
        lv["ramps"] = [{"options": ramp(lv["drops"][0] + rng.uniform(-6, 6), rng.uniform(40, 60), 30, ANG), "start": 2}]
        lv["static"] = [rseg(rng, 10, 90, 70, 100) for _ in range(2)]
    elif kind == "ramps":
        d = round(rng.uniform(25, 75), 1); lv["drops"] = [d]
        lv["ramps"] = [{"options": ramp(d + rng.uniform(-4, 4), rng.uniform(30, 45), 26, ANG), "start": 2},
                       {"options": ramp(rng.uniform(20, 80), rng.uniform(70, 92), 26, ANG), "start": 2}]
        lv["static"] = [rseg(rng, 10, 90, 55, 65)]
    elif kind == "peg":
        d = round(rng.uniform(25, 75), 1); lv["drops"] = [d]
        lv["pegs"] = [{"r": 4.5, "options": [[round(d + o, 1), round(rng.uniform(35, 50), 1)] for o in (-9, -5, -2, 2, 5, 9)], "start": 0}]
        lv["static"] = [rseg(rng, 10, 90, 65, 100) for _ in range(3)]
    elif kind == "bounce":
        d = round(rng.uniform(25, 75), 1); lv["drops"] = [d]
        lv["ramps"] = [{"options": ramp(d, rng.uniform(80, 96), 22, [-40, -28, -16, 0, 16, 28, 40]), "start": 3, "bouncy": True}]
        wx = lv["basket"][0] - 6 if lv["basket"][0] > 40 else lv["basket"][0] + 24
        lv["static"] = [[round(wx, 1), 92.0, round(wx, 1), 132.0]]
    else:  # machine
        lv["drops"] = [20.0, 40.0, 60.0, 80.0]
        lv["ramps"] = [{"options": ramp(rng.uniform(30, 70), rng.uniform(40, 55), 28, ANG), "start": 2}]
        lv["pegs"] = [{"r": 4.5, "options": [[round(rng.uniform(15, 85), 1), round(rng.uniform(70, 95), 1)] for _ in range(4)], "start": 0}]
        lv["static"] = [rseg(rng, 10, 90, 60, 100) for _ in range(2)]
    return lv


KINDS = [("drop", "الإسقاط", "اختر مكان إسقاط الكرة."), ("ramp", "المنحدر", "غيّر زاوية المنحدر."),
         ("ramps", "منحدران", "اضبط زاويتي المنحدرين."), ("peg", "المرتكز", "حرّك المرتكز ليحرف الكرة."),
         ("bounce", "الارتداد", "اضبط زاوية لوح الارتداد لتقفز الكرة فوق الجدار."), ("machine", "الآلة", "اجمع كل شيء: الإسقاط والمنحدر والمرتكز.")]


def evaluate(lv):
    cs = list(combos(lv))
    start = {"drop": 0, "ramps": [r["start"] for r in lv["ramps"]], "pegs": [p["start"] for p in lv["pegs"]]}
    wins = [c for c in cs if simulate(lv, c)[0]]
    rob = [c for c in wins if robust(lv, c)]
    return cs, start, wins, rob


def generate():
    levels = []
    for i, (kind, name, help_) in enumerate(KINDS):
        found = None
        for k in range(4000):
            rng = random.Random(7700 + i * 1009 + k)
            lv = candidate(kind, rng)
            cs, start, wins, rob = evaluate(lv)
            if not rob or simulate(lv, start)[0]: continue
            if len(wins) > max(1, len(cs) // 6): continue
            if kind == "bounce":  # the ball must actually use the bouncy board
                if all(simulate(dict(lv, ramps=[dict(lv["ramps"][0], bouncy=False)]), c)[0] for c in rob): continue
            found = lv; break
        if found is None: raise SystemExit("no layout for " + kind)
        cs, start, wins, rob = evaluate(found)
        found.update({"id": i + 1, "kind": kind, "name": name, "help": help_, "solution": rob[0], "winning": len(wins), "combos": len(cs)})
        levels.append(found)
        print("level", i + 1, kind, "after", k + 1, "layouts")
    OUT.write_text(json.dumps({"version": 1, "world": [W, H], "ball_r": R, "gravity": G, "dt": DT, "steps": STEPS,
                               "e_normal": E_NORMAL, "e_bouncy": E_BOUNCY, "friction": FRICTION, "win_time": WIN_TIME, "levels": levels}, ensure_ascii=False, indent=1), encoding="utf-8")


def check():
    data = json.loads(OUT.read_text(encoding="utf-8"))
    ok = True
    kinds = set()
    for lv in data["levels"]:
        cs, start, wins, rob = evaluate(lv)
        sol_ok = simulate(lv, lv["solution"])[0] and robust(lv, lv["solution"])
        good = sol_ok and not simulate(lv, start)[0] and len(wins) == lv["winning"] and len(cs) == lv["combos"]
        kinds.add(lv["kind"])
        ok = ok and good
        print("%d %-8s %-7s combos %3d  winning %2d  robust %2d  start fails %s  stored solution wins (robust) %s  steps %d  %s" % (
            lv["id"], lv["name"], lv["kind"], len(cs), len(wins), len(rob), not simulate(lv, start)[0], sol_ok, simulate(lv, lv["solution"])[1], "OK" if good else "FAIL"))
    if len(kinds) != 6: ok = False; print("FAIL need 6 different kinds")
    print("RESULT:", "ALL OK" if ok else "FAILED")
    return ok


if __name__ == "__main__":
    if "--check" not in sys.argv: generate()
    sys.exit(0 if check() else 1)
