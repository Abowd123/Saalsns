"""Verifies content/escape/levels.json (escape rooms).
For every room:
  - schema: unique ids, no overlapping objects, known kinds/actions, rects inside the 100x110 room, items defined.
  - every code/symbol answer is DERIVED again from the clue objects in the same room
    (clock hour, star counts, book heights, numbers on the board...), not trusted.
  - play-through simulation: starting with only visible objects, look/search/use items/enter
    codes as soon as their clue objects have been seen. The door must open.
  - 3..4 puzzles per room (search, item, code, symbols), every item is used, every hidden
    object gets revealed, hints cover every puzzle in solving order.
Exit code 0 = all rooms OK."""
import json, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
PATH = ROOT / "content/escape/levels.json"
KINDS = {"clock", "frame", "door", "plant", "candles", "desk", "note", "safe", "shelf", "sign", "lamps", "chest", "cabinet",
         "board", "flasks", "rug", "vase", "sofa", "vent", "drawing", "pipes", "barrel", "toolbox", "poster", "window"}
ACTIONS = {"look", "search", "item", "code", "symbols"}
PUZZLES = {"search", "item", "code", "symbols"}


def param(o, name):
    if name == "lit_count":
        return sum(1 for x in o["lit"] if x)
    if name == "red_books":
        return sum(1 for b in o["books"] if b["c"] == 0)
    if name == "book_count":
        return len(o["books"])
    return o[name]


def derive(room, a):
    objs = {o["id"]: o for o in room["objects"]}
    if a["type"] == "code":
        if "from" in a:
            return "".join(str(param(objs[i], p)) for i, p in a["from"]), [i for i, _ in a["from"]]
        r = a["rule"]
        if r["by"] == "area_asc":
            ids = sorted(r["objs"], key=lambda i: objs[i]["rect"][2] * objs[i]["rect"][3])
            areas = [objs[i]["rect"][2] * objs[i]["rect"][3] for i in ids]
            assert len(set(areas)) == len(areas), "equal areas make the order ambiguous"
            return "".join(str(objs[i][r["param"]]) for i in ids), list(r["objs"])
    if a["type"] == "symbols":
        r = a["rule"]; src = objs[r["obj"]]
        if r["by"] == "height_asc":
            bs = [b for b in src["books"] if b["sym"]]
            assert len({b["h"] for b in bs}) == len(bs), "equal heights"
            return [b["sym"] for b in sorted(bs, key=lambda b: b["h"])], [r["obj"]]
        if r["by"] == "number_asc":
            assert len({p[1] for p in src["pairs"]}) == len(src["pairs"]), "equal numbers"
            return [p[0] for p in sorted(src["pairs"], key=lambda p: p[1])], [r["obj"]]
        if r["by"] == "count_desc":
            assert len({p[1] for p in src["pairs"]}) == len(src["pairs"]), "equal counts"
            return [p[0] for p in sorted(src["pairs"], key=lambda p: -p[1])], [r["obj"]]
        if r["by"] == "as_listed":
            return list(src["syms"]), [r["obj"]]
    raise ValueError("no derivation rule")


def check_room(room, symbols):
    errs = []
    objs = {}
    for o in room["objects"]:
        if o["id"] in objs: errs.append("duplicate id " + o["id"])
        objs[o["id"]] = o
        x, y, w, h = o["rect"]
        if x < 0 or y < 0 or x + w > 100 or y + h > 110 or w <= 0 or h <= 0: errs.append("rect out of room: " + o["id"])
        if o["kind"] not in KINDS: errs.append("unknown kind " + o["kind"])
        a = o["action"]
        if a["type"] not in ACTIONS: errs.append("unknown action " + a["type"])
        for k in ("gives", "needs"):
            if k in a and a[k] not in room["items"]: errs.append("%s: unknown item %s" % (o["id"], a[k]))
        if a["type"] == "symbols":
            if len(set(a["answer"])) != len(a["answer"]) or any(s not in symbols for s in a["answer"]): errs.append("bad symbol answer " + o["id"])
        if a["type"] == "code" and (len(a["answer"]) != 3 or not a["answer"].isdigit()): errs.append("code must be 3 digits " + o["id"])
    ol = room["objects"]
    for i in range(len(ol)):
        for j in range(i + 1, len(ol)):
            a, b = ol[i]["rect"], ol[j]["rect"]
            if a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]:
                errs.append("objects overlap (ambiguous tap): %s / %s" % (ol[i]["id"], ol[j]["id"]))
    wins = [o for o in room["objects"] if o["action"].get("win")]
    if len(wins) != 1: errs.append("need exactly one exit")
    # derivations
    for o in room["objects"]:
        a = o["action"]
        if a["type"] in ("code", "symbols"):
            try:
                ans, _ = derive(room, a)
                if ans != a["answer"]: errs.append("%s: stored answer %s but clues give %s" % (o["id"], a["answer"], ans))
            except Exception as ex:
                errs.append("%s: %s" % (o["id"], ex))
    # simulation
    visible = {i for i, o in objs.items() if not o.get("hidden")}
    seen, solved, inv, used, order = set(), set(), set(), set(), []
    revealed = set()
    won = False
    changed = True
    while changed and not won:
        changed = False
        for i in list(objs):
            if i not in visible or i in solved: continue
            o = objs[i]; a = o["action"]; t = a["type"]
            if t == "look":
                if i not in seen: seen.add(i); changed = True
                continue
            ok = False
            if t == "search": ok = True
            elif t == "item": ok = a["needs"] in inv
            else:
                _, srcs = derive(room, a)
                ok = all(s in seen for s in srcs + a.get("clues", []))
            if ok:
                if t == "item": used.add(a["needs"])
                solved.add(i); seen.add(i); order.append(i); changed = True
                if "gives" in a: inv.add(a["gives"])
                for r in a.get("reveals", []): visible.add(r); revealed.add(r)
                if a.get("win"): won = True
                break
    if not won: errs.append("door never opens (solved so far: %s)" % order)
    puzzles = [i for i, o in objs.items() if o["action"]["type"] in PUZZLES]
    if not 3 <= len(puzzles) <= 4: errs.append("puzzles %d (want 3..4)" % len(puzzles))
    for it in room["items"]:
        if it not in used: errs.append("item never used: " + it)
    for i, o in objs.items():
        if o.get("hidden") and i not in revealed: errs.append("hidden never revealed: " + i)
    hint_targets = [h["until"] for h in room["hints"]]
    if hint_targets != [i for i in order if i in puzzles]: errs.append("hints %s != solve order %s" % (hint_targets, order))
    return errs, order, len(puzzles)


def main():
    data = json.loads(PATH.read_text(encoding="utf-8"))
    ok = len(data["rooms"]) == 6
    if not ok: print("FAIL: need 6 rooms")
    for room in data["rooms"]:
        errs, order, n = check_room(room, data["symbols"])
        ok = ok and not errs
        print("%d %-12s puzzles=%d solve: %s  %s" % (room["id"], room["name"], n, " > ".join(order), "OK" if not errs else "FAIL " + "; ".join(errs)))
    print("Each code/symbol lock has exactly one accepted answer (exact match), derived from in-room clues.")
    print("RESULT:", "ALL OK" if ok else "FAILED")
    return ok


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
