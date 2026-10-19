"""Levels for the two batch-2 speed games, and their verification.
  python tools/speed_check.py          -> writes content/lightning/levels.json and content/hunter/levels.json
  python tools/speed_check.py --check  -> verifies both files (exit 0 = OK)

Both games build their rounds/spawns at runtime from a tiny LCG that is ported here
line by line (same constants, same call order). Each level stores a `fingerprint` of the
plan for seed 2026; devtools/test_runner.gd recomputes it with the GDScript code, so a
match proves this script verifies the exact generator the game runs.

Lightning: for 500 seeds x 10 rounds per level, checks delay range, decoy timing
(first decoy >= 0.3 s, decoys >= 0.45 s apart, last decoy ends before the signal and
starts >= 0.45 s before it, so a reflex tap on a decoy lands before the real signal),
target inside the arena, and that star thresholds are not below plausible human times.
Hunter: every play of a level has the same number of good and wrong targets (only order,
positions and timing change). For 300 seeds per level simulates two bots (no aiming model, only reaction time
and taps per second; they never tap a wrong target). The 3-star goal must be reached by
the "skilled" bot on EVERY seed and the 1-star goal by the "average" bot on every seed."""
import json, math, sys, pathlib, statistics
ROOT = pathlib.Path(__file__).resolve().parents[1]
L_PATH = ROOT / "content/lightning/levels.json"
H_PATH = ROOT / "content/hunter/levels.json"
M = 2147483648
FP_SEED = 2026
DECOY_TIME = 0.35
ROUNDS = 10


class Lcg:
    def __init__(self, seed):
        self.s = seed % M
        if self.s == 0:
            self.s = 1

    def next(self):
        self.s = (self.s * 1103515245 + 12345) % M
        return self.s / 2147483648.0


# ---------------- lightning ----------------
def l_plan_round(rng, lv):
    dmin, dmax = float(lv["dmin"]), float(lv["dmax"])
    delay = dmin + rng.next() * (dmax - dmin)
    maxd = int(lv["decoys"])
    count = int(rng.next() * (maxd + 1))
    times = []
    for _ in range(count):
        times.append(0.3 + rng.next() * max(delay - 0.75, 0.0))
    times.sort()
    decoys = []
    last = -10.0
    for t in times:
        x = 0.12 + rng.next() * 0.76
        y = 0.12 + rng.next() * 0.76
        if t - last >= 0.45:
            decoys.append({"t": t, "x": x, "y": y})
            last = t
    tx = 0.12 + rng.next() * 0.76
    ty = 0.12 + rng.next() * 0.76
    ang = rng.next() * math.tau
    return {"delay": delay, "decoys": decoys, "x": tx, "y": ty, "angle": ang}


def l_fingerprint(lv, seed=FP_SEED):
    rng = Lcg(seed); fp = 0
    for _ in range(ROUNDS):
        p = l_plan_round(rng, lv)
        fp += int(p["delay"] * 1000) + int(p["x"] * 1000) + int(p["y"] * 1000) + int(p["angle"] * 1000)
        for d in p["decoys"]:
            fp += int(d["t"] * 1000)
    return fp


LIGHTNING = [
    dict(name="البداية", mode="full", decoy="none", decoys=0, dmin=1.2, dmax=3.0, window=1.5, size=0.0, move=0.0, t3=330, t2=450),
    dict(name="الصبر", mode="full", decoy="none", decoys=0, dmin=0.8, dmax=5.0, window=1.5, size=0.0, move=0.0, t3=330, t2=450),
    dict(name="الهدف", mode="spot", decoy="none", decoys=0, dmin=1.0, dmax=3.0, window=1.6, size=0.11, move=0.0, t3=480, t2=650),
    dict(name="الهدف الصغير", mode="spot", decoy="none", decoys=0, dmin=1.0, dmax=3.5, window=1.6, size=0.075, move=0.0, t3=520, t2=700),
    dict(name="الألوان الخادعة", mode="full", decoy="color", decoys=2, dmin=1.5, dmax=4.5, window=1.5, size=0.0, move=0.0, t3=360, t2=500),
    dict(name="الهدف المتحرك", mode="spot", decoy="none", decoys=0, dmin=1.0, dmax=3.5, window=1.8, size=0.1, move=0.35, t3=560, t2=760),
    dict(name="الأهداف الخادعة", mode="spot", decoy="shape", decoys=3, dmin=1.5, dmax=4.5, window=1.6, size=0.1, move=0.0, t3=520, t2=700),
    dict(name="عاصفة البرق", mode="spot", decoy="shape", decoys=3, dmin=1.5, dmax=4.5, window=1.5, size=0.085, move=0.45, t3=600, t2=800),
]
# plausible fastest human touch times (ms) per kind: full-screen tap, aimed tap, aimed moving
HUMAN_MIN = {"full": 250, "spot": 380, "move": 430}


def lightning_check(levels):
    ok = True
    for lv in levels:
        errs = []
        kind = "move" if lv["move"] > 0 else lv["mode"]
        if lv["t3"] < HUMAN_MIN[kind]: errs.append("t3 below human minimum")
        if not lv["t3"] < lv["t2"] < lv["window"] * 1000: errs.append("thresholds order")
        if lv["mode"] == "spot" and not (0.066 <= lv["size"] <= 0.12): errs.append("target size")
        if lv["decoy"] != "none" and lv["dmin"] < 1.5: errs.append("decoy level needs dmin >= 1.5")
        n_decoys = 0; rounds_with = 0
        for seed in range(1, 501):
            rng = Lcg(seed)
            for _ in range(ROUNDS):
                p = l_plan_round(rng, lv)
                if not lv["dmin"] <= p["delay"] <= lv["dmax"]: errs.append("delay out of range")
                if not (0.12 <= p["x"] <= 0.88 and 0.12 <= p["y"] <= 0.88): errs.append("target outside")
                ds = p["decoys"] if lv["decoy"] != "none" else []
                if ds: rounds_with += 1
                n_decoys += len(ds)
                prev = -10
                for d in ds:
                    if d["t"] < 0.3: errs.append("decoy too early")
                    if d["t"] - prev < 0.45: errs.append("decoys too close")
                    if p["delay"] - d["t"] < 0.45 or d["t"] + DECOY_TIME > p["delay"] - 0.05: errs.append("decoy too close to signal")
                    prev = d["t"]
            if len(errs) > 0: break
        if lv["decoy"] != "none" and rounds_with < 0.4 * 500 * ROUNDS: errs.append("too few decoy rounds")
        errs = sorted(set(errs))
        ok = ok and not errs
        extra = (" decoy rounds %.0f%%, avg %.2f decoys/round" % (100.0 * rounds_with / (500 * ROUNDS), n_decoys / (500.0 * ROUNDS))) if lv["decoy"] != "none" else ""
        print("lightning %d %-16s %s/%s%s  3*<=%dms 2*<=%dms fp=%d%s  %s" % (lv["id"], lv["name"], lv["mode"], lv["decoy"], " moving" if lv["move"] > 0 else "",
              lv["t3"], lv["t2"], lv["fingerprint"], extra, "OK" if not errs else "FAIL " + "; ".join(errs)))
        if l_fingerprint(lv) != lv["fingerprint"]:
            print("   FAIL fingerprint changed"); ok = False
    return ok


# ---------------- hunter ----------------
def h_plan(lv, seed):
    """Fixed counts per level (same difficulty every play): `count` spawns, `goods` of them
    good, order shuffled; spawn times evenly spread with jitter."""
    rng = Lcg(seed)
    n = int(lv["count"]); g = int(lv["goods"]); dur = float(lv["duration"])
    kinds = [True] * g + [False] * (n - g)
    for i in range(n - 1, 0, -1):
        j = int(rng.next() * (i + 1))
        kinds[i], kinds[j] = kinds[j], kinds[i]
    gap = (dur - 1.6) / (n - 1)
    out = []
    for k in range(n):
        t = 0.6 + k * gap + (rng.next() - 0.5) * gap * 0.6
        x = 0.1 + rng.next() * 0.8
        y = 0.1 + rng.next() * 0.8
        ang = rng.next() * math.tau
        spd = float(lv["smin"]) + rng.next() * (float(lv["smax"]) - float(lv["smin"]))
        life = float(lv["lmin"]) + rng.next() * (float(lv["lmax"]) - float(lv["lmin"]))
        out.append({"t": t, "good": kinds[k], "x": x, "y": y, "angle": ang, "speed": spd, "life": life})
    return out


def h_fingerprint(lv, seed=FP_SEED):
    fp = 0
    for s in h_plan(lv, seed):
        fp += int(s["t"] * 1000) + int(s["life"] * 1000) + (1000 if s["good"] else 0) + int(s["x"] * 1000)
    return fp


def bot(plan, dur, react, interval):
    """Earliest-deadline greedy. A target can be tapped from t+react until t+life."""
    goods = sorted([(s["t"] + react, s["t"] + s["life"]) for s in plan if s["good"]])
    free = 0.0; hits = 0; pending = []; i = 0
    import heapq
    while i < len(goods) or pending:
        if not pending:
            free = max(free, goods[i][0])
        while i < len(goods) and goods[i][0] <= free:
            heapq.heappush(pending, (goods[i][1], goods[i][0])); i += 1
        while pending and pending[0][0] < free:
            heapq.heappop(pending)
        if not pending:
            continue
        dl, av = heapq.heappop(pending)
        tap = max(free, av)
        if tap <= dl and tap <= dur:
            hits += 1; free = tap + interval
    return hits


HUNTER = [
    dict(name="التدريب", duration=30, count=26, goods=22, smin=0.08, smax=0.15, lmin=2.2, lmax=2.8, size=0.095),
    dict(name="الإحماء", duration=30, count=30, goods=24, smin=0.12, smax=0.20, lmin=2.0, lmax=2.6, size=0.09),
    dict(name="الصيد", duration=35, count=38, goods=28, smin=0.15, smax=0.25, lmin=1.9, lmax=2.4, size=0.085),
    dict(name="الفخاخ", duration=35, count=42, goods=30, smin=0.20, smax=0.30, lmin=1.8, lmax=2.2, size=0.08),
    dict(name="الزحام", duration=40, count=52, goods=36, smin=0.22, smax=0.34, lmin=1.7, lmax=2.1, size=0.078),
    dict(name="الرياح", duration=40, count=58, goods=39, smin=0.26, smax=0.38, lmin=1.6, lmax=2.0, size=0.075),
    dict(name="العاصفة", duration=45, count=70, goods=45, smin=0.30, smax=0.42, lmin=1.5, lmax=1.9, size=0.072),
    dict(name="الصياد الخبير", duration=45, count=78, goods=48, smin=0.34, smax=0.48, lmin=1.4, lmax=1.8, size=0.07),
]
SKILLED = (0.30, 0.38)
AVERAGE = (0.50, 0.80)
SEEDS = range(1, 301)


def hunter_stats(lv):
    goods = []; sk = []; av = []
    for seed in SEEDS:
        p = h_plan(lv, seed)
        goods.append(sum(1 for s in p if s["good"]))
        sk.append(bot(p, lv["duration"], *SKILLED))
        av.append(bot(p, lv["duration"], *AVERAGE))
    return goods, sk, av


def hunter_goals(lv):
    g = int(lv["goods"])
    return [math.ceil(g * 0.5), math.ceil(g * 0.7), math.ceil(g * 0.85)]


def hunter_check(levels):
    ok = True
    prev_speed = 0
    for lv in levels:
        errs = []
        goods, sk, av = hunter_stats(lv)
        g1, g2, g3 = lv["goals"]
        if not g1 < g2 < g3: errs.append("goals order")
        if min(sk) < g3: errs.append("skilled bot misses 3 stars on some seed (%d < %d)" % (min(sk), g3))
        if min(av) < g1: errs.append("average bot misses 1 star on some seed")
        if min(goods) != lv["goods"] or max(goods) != lv["goods"]: errs.append("good count differs between plays")
        if lv["count"] <= lv["goods"]: errs.append("no wrong targets")
        if lv["size"] * 672 * 2 < 88: errs.append("target smaller than 88 px on a 720 px screen")
        if lv["smax"] < prev_speed: errs.append("speed decreased")
        prev_speed = lv["smax"]
        if h_fingerprint(lv) != lv["fingerprint"]: errs.append("fingerprint changed")
        ok = ok and not errs
        print("hunter    %d %-14s %ds goods %d/%d  goals %s  skilled bot min %d  average bot min %d (median %d)  fp=%d  %s" % (
            lv["id"], lv["name"], lv["duration"], lv["goods"], lv["count"], lv["goals"], min(sk), min(av), statistics.median(av), lv["fingerprint"],
            "OK" if not errs else "FAIL " + "; ".join(errs)))
    return ok


def generate():
    ll = []
    for i, d in enumerate(LIGHTNING):
        lv = {"id": i + 1, **d, "rounds": ROUNDS}
        lv["fingerprint"] = l_fingerprint(lv)
        ll.append(lv)
    L_PATH.write_text(json.dumps({"version": 1, "decoy_time": DECOY_TIME, "levels": ll}, ensure_ascii=False, indent=1), encoding="utf-8")
    hl = []
    for i, d in enumerate(HUNTER):
        lv = {"id": i + 1, **d, "penalty": 3.0}
        lv["goals"] = hunter_goals(lv)
        lv["fingerprint"] = h_fingerprint(lv)
        hl.append(lv)
    H_PATH.write_text(json.dumps({"version": 1, "levels": hl}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("wrote", L_PATH.name, len(ll), "and", H_PATH.name, len(hl))


def check():
    L = json.loads(L_PATH.read_text(encoding="utf-8"))
    H = json.loads(H_PATH.read_text(encoding="utf-8"))
    ok = abs(L["decoy_time"] - DECOY_TIME) < 1e-9
    ok = lightning_check(L["levels"]) and ok
    ok = hunter_check(H["levels"]) and ok
    print("RESULT:", "ALL OK" if ok else "FAILED")
    return ok


if __name__ == "__main__":
    if "--check" not in sys.argv:
        generate()
    sys.exit(0 if check() else 1)
