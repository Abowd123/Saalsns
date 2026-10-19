"""Maze levels for games/maze.
  python tools/maze_gen.py          -> regenerates content/maze/levels.json (fixed seeds, deterministic)
  python tools/maze_gen.py --check  -> verifies the file: walls consistent, closed border,
                                       BFS path start->exit exists, stored par == BFS shortest path,
                                       and reports how many shortest paths exist (1 = unique solution).
Cell format: one hex char per cell = open sides bitmask N=1 E=2 S=4 W=8."""
import json, random, sys, pathlib
from collections import deque
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "content/maze/levels.json"
N, E, S, W = 1, 2, 4, 8
D = {N: (0, -1), E: (1, 0), S: (0, 1), W: (-1, 0)}
OPP = {N: S, S: N, E: W, W: E}
SIZES = [5, 5, 6, 7, 7, 8, 9, 9, 10, 11, 11, 12, 13, 14, 15]
NAMES = ["الخطوة الأولى", "منعطفات", "الممر الطويل", "الدوامة", "مفترق الطرق", "الغابة", "الكهف",
         "السرداب", "المدينة القديمة", "القلعة", "الحديقة الملكية", "الأنفاق", "المرصد", "السوق الكبير", "المتاهة العظمى"]
# extra openings (loops) per level: 0 keeps a perfect maze (exactly one path)
LOOPS = [0, 0, 0, 0, 2, 0, 3, 0, 4, 0, 5, 6, 0, 8, 10]


def carve(n, rng):
    g = [[0] * n for _ in range(n)]
    seen = [[False] * n for _ in range(n)]
    st = [(0, 0)]
    seen[0][0] = True
    while st:
        x, y = st[-1]
        opts = [(b, x + dx, y + dy) for b, (dx, dy) in D.items() if 0 <= x + dx < n and 0 <= y + dy < n and not seen[y + dy][x + dx]]
        if not opts:
            st.pop(); continue
        b, nx, ny = rng.choice(opts)
        g[y][x] |= b; g[ny][nx] |= OPP[b]; seen[ny][nx] = True
        st.append((nx, ny))
    return g


def add_loops(g, k, rng):
    n = len(g); done = 0; tries = 0
    while done < k and tries < 5000:
        tries += 1
        x, y = rng.randrange(n), rng.randrange(n)
        b = rng.choice([E, S])
        dx, dy = D[b]
        if not (0 <= x + dx < n and 0 <= y + dy < n) or g[y][x] & b:
            continue
        g[y][x] |= b; g[y + dy][x + dx] |= OPP[b]; done += 1


def bfs(g, s):
    n = len(g); dist = {s: 0}; ways = {s: 1}; q = deque([s])
    while q:
        x, y = q.popleft()
        for b, (dx, dy) in D.items():
            if g[y][x] & b:
                p = (x + dx, y + dy)
                if p not in dist:
                    dist[p] = dist[(x, y)] + 1; ways[p] = ways[(x, y)]; q.append(p)
                elif dist[p] == dist[(x, y)] + 1:
                    ways[p] += ways[(x, y)]
    return dist, ways


def generate():
    levels = []
    prev = 0
    for i, n in enumerate(SIZES):
        # difficulty must grow: try fixed seeds until the shortest path is longer than the
        # previous level's (deterministic: same seeds -> same file).
        for k in range(400):
            rng = random.Random(7000 + i * 1000 + k)
            g = carve(n, rng)
            add_loops(g, LOOPS[i], rng)
            start = (0, 0) if i % 2 == 0 else (n - 1, 0)
            dist, _ = bfs(g, start)
            # exit = farthest cell on the border (feels like a real way out)
            cand = [p for p, d in dist.items() if (p[0] in (0, n - 1) or p[1] in (0, n - 1))]
            ex = max(cand, key=lambda p: (dist[p], -p[0], -p[1]))
            if dist[ex] > prev:
                break
        prev = dist[ex]
        levels.append({"id": i + 1, "name": NAMES[i], "size": n,
                       "cells": ["".join("%x" % c for c in row) for row in g],
                       "start": list(start), "exit": list(ex), "par": dist[ex]})
    OUT.write_text(json.dumps({"version": 1, "levels": levels}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("wrote", OUT, len(levels), "levels")


def check():
    data = json.loads(OUT.read_text(encoding="utf-8"))
    ok = True
    for lv in data["levels"]:
        n = lv["size"]
        g = [[int(ch, 16) for ch in row] for row in lv["cells"]]
        errs = []
        if len(g) != n or any(len(r) != n for r in g):
            errs.append("grid size")
        for y in range(n):
            for x in range(n):
                for b, (dx, dy) in D.items():
                    nx, ny = x + dx, y + dy
                    inside = 0 <= nx < n and 0 <= ny < n
                    if g[y][x] & b and not inside:
                        errs.append("open border at %d,%d" % (x, y))
                    if inside and bool(g[y][x] & b) != bool(g[ny][nx] & OPP[b]):
                        errs.append("one-way wall at %d,%d" % (x, y))
        s, e = tuple(lv["start"]), tuple(lv["exit"])
        dist, ways = bfs(g, s)
        reach = len(dist) == n * n
        if e not in dist:
            errs.append("exit unreachable")
        elif dist[e] != lv["par"]:
            errs.append("par %d != bfs %d" % (lv["par"], dist[e]))
        status = "OK" if not errs else "FAIL " + "; ".join(errs[:3])
        ok = ok and not errs
        print("%2d %-16s %2dx%-2d par=%3d shortest_paths=%s%s all_cells_reachable=%s %s" % (
            lv["id"], lv["name"], n, n, dist.get(e, -1), ways.get(e, 0), " (unique)" if ways.get(e, 0) == 1 else "", reach, status))
    print("RESULT:", "ALL OK" if ok else "FAILED")
    return ok


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(0 if check() else 1)
    generate(); check()
