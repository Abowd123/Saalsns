"""Pipe engineer (lowest-cost network) levels.
  python tools/pipe_cost_gen.py          -> writes content/pipe_cost/levels.json
  python tools/pipe_cost_gen.py --check  -> re-verifies (exit 0 = OK)
Grid: '.' ground (cost 1), '~' mud (2), '^' rock (3), '#' blocked, 'S' source, 'A'..'D' houses.
A pipe goes on a cell; water flows between 4-neighbour pipe/source/house cells. All houses
must be connected to the source. The minimum cost is the node-weighted Steiner tree,
computed EXACTLY with the Dreyfus-Wagner dynamic programme (all subsets of terminals x all
cells, Dijkstra per subset), so the stored `optimal` is proven minimal, and the stored
solution is checked to reach that cost. Also reports how much a naive plan (separate
shortest path to each house) costs, to show that sharing pipes matters."""
import json, random, sys, heapq, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "content/pipe_cost/levels.json"
COST = {".": 1, "~": 2, "^": 3}
SPEC = [(6, 2, "القرية"), (7, 2, "الحي"), (7, 3, "المزرعة"), (8, 3, "الوادي"), (8, 4, "البلدة"), (9, 4, "المدينة")]
NAMES = ["الينبوع", "البئر", "النهر", "السد", "الخزان", "النبع الكبير"]


def parse(rows):
    n = len(rows); cells = {}; term = []
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == "#": continue
            if ch in COST: cells[(x, y)] = COST[ch]
            else:
                cells[(x, y)] = 0
                term.append((ch, (x, y)))
    term.sort(key=lambda t: (t[0] != "S", t[0]))
    return n, cells, [p for _, p in term]


def nbrs(p, cells):
    x, y = p
    for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if q in cells: yield q


def steiner(cells, terms):
    """Dreyfus-Wagner, node weights. Returns (cost, set of pipe cells)."""
    k = len(terms); full = (1 << k) - 1
    INF = float("inf")
    dp = [dict() for _ in range(full + 1)]
    back = [dict() for _ in range(full + 1)]
    for i, t in enumerate(terms):
        dp[1 << i][t] = cells[t]; back[1 << i][t] = None
    for S in range(1, full + 1):
        d = dp[S]
        sub = (S - 1) & S
        while sub > 0:
            other = S ^ sub
            if sub < other:
                for v in cells:
                    a = dp[sub].get(v); b = dp[other].get(v)
                    if a is not None and b is not None:
                        c = a + b - cells[v]
                        if c < d.get(v, INF): d[v] = c; back[S][v] = ("m", sub)
            sub = (sub - 1) & S
        pq = [(c, v) for v, c in d.items()]; heapq.heapify(pq)
        while pq:
            c, v = heapq.heappop(pq)
            if c > d.get(v, INF): continue
            for u in nbrs(v, cells):
                nc = c + cells[u]
                if nc < d.get(u, INF): d[u] = nc; back[S][u] = ("e", v); heapq.heappush(pq, (nc, u))
    root = terms[0]
    if root not in dp[full]: return None, None
    used = set()
    def build(S, v):
        used.add(v)
        b = back[S][v]
        if b is None: return
        if b[0] == "e": build(S, b[1])
        else: build(b[1], v); build(S ^ b[1], v)
    build(full, root)
    pipes = {p for p in used if cells[p] > 0}
    return dp[full][root], pipes


def connected(cells, terms, pipes):
    ok = set(pipes) | set(terms)
    seen = {terms[0]}; st = [terms[0]]
    while st:
        p = st.pop()
        for q in nbrs(p, cells):
            if q in ok and q not in seen: seen.add(q); st.append(q)
    return all(t in seen for t in terms)


def naive(cells, terms):
    tot = set()
    for t in terms[1:]:
        _, p = steiner(cells, [terms[0], t]); tot |= p
    return sum(cells[p] for p in tot)


def generate():
    levels = []
    for i, (n, k, name) in enumerate(SPEC):
        best = None
        for s in range(300):
            rng = random.Random(4400 + i * 131 + s)
            g = [["."] * n for _ in range(n)]
            for y in range(n):
                for x in range(n):
                    r = rng.random()
                    g[y][x] = "#" if r < 0.10 else ("^" if r < 0.24 else ("~" if r < 0.42 else "."))
            free = [(x, y) for y in range(n) for x in range(n)]
            rng.shuffle(free)
            pts = []
            for p in free:
                if all(abs(p[0] - q[0]) + abs(p[1] - q[1]) >= max(3, n // 2) for q in pts): pts.append(p)
                if len(pts) == k + 1: break
            if len(pts) < k + 1: continue
            for j, (x, y) in enumerate(pts): g[y][x] = "S" if j == 0 else "ABCD"[j - 1]
            rows = ["".join(r) for r in g]
            _, cells, terms = parse(rows)
            opt, pipes = steiner(cells, terms)
            if opt is None: continue
            nv = naive(cells, terms)
            score = (nv - opt) + opt * 0.05      # prefer levels where sharing pipes saves a lot
            if best is None or score > best[0]: best = (score, rows, opt, pipes, nv)
        _, rows, opt, pipes, nv = best
        levels.append({"id": i + 1, "name": NAMES[i], "grid": rows, "optimal": opt, "naive": nv,
                       "solution": sorted([list(p) for p in pipes])})
    OUT.write_text(json.dumps({"version": 1, "costs": COST, "levels": levels}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("wrote", len(levels))


def check():
    ok = True
    for lv in json.loads(OUT.read_text(encoding="utf-8"))["levels"]:
        n, cells, terms = parse(lv["grid"])
        opt, _ = steiner(cells, terms)
        sol = {tuple(p) for p in lv["solution"]}
        sol_cost = sum(cells[p] for p in sol)
        good = opt == lv["optimal"] and connected(cells, terms, sol) and sol_cost == opt and all(cells.get(p, 0) > 0 for p in sol)
        ok = ok and good
        print("%d %-12s %dx%d houses %d  optimal %d (exact DP)  stored solution cost %d connects=%s  naive %d  %s" % (
            lv["id"], lv["name"], n, n, len(terms) - 1, opt, sol_cost, connected(cells, terms, sol), lv["naive"], "OK" if good else "FAIL"))
    print("RESULT:", "ALL OK" if ok else "FAILED")
    return ok


if __name__ == "__main__":
    if "--check" not in sys.argv: generate()
    sys.exit(0 if check() else 1)
