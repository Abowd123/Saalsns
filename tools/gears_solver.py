"""Verifies every gears level is solvable and computes the minimum number of placed gears.
Must mirror games/build/gears_game.gd rules exactly."""
import json, itertools, math, sys
R = {1: 40, 2: 70}
TOL = 6

def simulate(pegs, sizes, motor, out, ):
    n = len(pegs)
    def r(i): return R[sizes[i]] if sizes[i] else 0
    # collision check
    for i in range(n):
        for j in range(i+1, n):
            if sizes[i] and sizes[j]:
                d = math.dist(pegs[i], pegs[j])
                if d < r(i) + r(j) - TOL:
                    return None  # jammed by overlap
    dirs = {motor: 1}
    queue = [motor]
    while queue:
        a = queue.pop(0)
        for b in range(n):
            if b == a or not sizes[b]:
                continue
            if abs(math.dist(pegs[a], pegs[b]) - (r(a) + r(b))) <= TOL:
                want = -dirs[a]
                if b in dirs:
                    if dirs[b] != want:
                        return None  # locked loop
                else:
                    dirs[b] = want
                    queue.append(b)
    return dirs.get(out)

def solve(level):
    pegs = level["pegs"]; motor = level["motor"]; out = level["output"]
    free = [i for i in range(len(pegs)) if i not in (motor, out)]
    best = None
    for combo in itertools.product([0, 1, 2], repeat=len(free)):
        sizes = [0] * len(pegs)
        sizes[motor] = level["motor_size"]; sizes[out] = level["output_size"]
        for i, s in zip(free, combo):
            sizes[i] = s
        d = simulate(pegs, sizes, motor, out)
        if d == level["required_dir"]:
            used = sum(1 for s in combo if s)
            if best is None or used < best:
                best = used
    return best

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else str(__import__("pathlib").Path(__file__).resolve().parents[1] / "content/build/gears_levels.json")
    data = json.load(open(path))
    ok = True
    for lv in data["levels"]:
        m = solve(lv)
        print(lv["id"], lv["name"], "min_gears =", m)
        if m is None:
            ok = False
        lv["min_gears"] = m
    json.dump(data, open(path, "w"), ensure_ascii=False, indent=1)
    sys.exit(0 if ok else 1)
