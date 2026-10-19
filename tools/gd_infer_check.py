"""Stricter heuristic for Godot's "Cannot infer the type" parse error.
Flags `var x := EXPR` when EXPR touches something whose static type is Variant:
untyped params/locals, for-loop vars over untyped containers, untyped members, indexing
of untyped containers, .get(), property access on InputEvent params, JSON results.
Heuristic: review every hit; a clean run is not proof."""
import re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
INPUT_PROPS = r"\b(e|event|ev)\.(position|pressed|button_index|relative|keycode|index|global_position|velocity)\b"
hits = 0
for f in sorted(ROOT.rglob("*.gd")):
    rel = f.relative_to(ROOT).as_posix()
    lines = f.read_text(encoding="utf-8").split("\n")
    members_variant = set()
    typed_arrays = set()
    for l in lines:
        m = re.match(r"^(?:static )?var (\w+)\s*(:=|=|:)\s*(.*)", l)
        if m:
            name, op, rest = m.groups()
            if op == "=" : members_variant.add(name)
            if op == ":" and re.match(r"\s*(Array|Dictionary)\b(?!\[)", rest): members_variant.add(name + "[]")
            if op == ":=" and re.match(r"\s*(\[\]|\{\}|\[.*\]$|\{.*\}$)", rest): members_variant.add(name + "[]")
            if op == ":" and re.match(r"\s*Array\[", rest): typed_arrays.add(name)
    local_variant = set(); local_cont = set()
    for i, l in enumerate(lines, 1):
        code = l.split(" #")[0]
        m = re.match(r"^\s*(?:static )?func \w+\((.*?)\)", code)
        if m:
            local_variant = set(); local_cont = set()
            for p in m.group(1).split(","):
                p = p.strip()
                if not p: continue
                nm = re.split(r"[:=]", p)[0].strip()
                if ":" not in p.split("=")[0] and ":=" not in p: local_variant.add(nm)
                if re.search(r":\s*(Array|Dictionary)\b(?!\[)", p): local_cont.add(nm)
        m = re.match(r"^\s*var (\w+)\s*=\s", code)
        if m: local_variant.add(m.group(1))
        m = re.match(r"^\s*var (\w+)\s*:\s*(Array|Dictionary)\b(?!\[)", code)
        if m: local_cont.add(m.group(1))
        m = re.match(r"^\s*var (\w+)\s*:=\s*(\[|\{)", code)
        if m: local_cont.add(m.group(1))
        m = re.match(r"^\s*for (\w+) in (.+):\s*$", code)
        if m:
            src = m.group(2).strip()
            if not re.match(r"(range\(|\d|\w+\.size\(\)|\w+ *$)", src) or (re.match(r"^\w+$", src) and src not in typed_arrays):
                local_variant.add(m.group(1))
        m = re.match(r"^\s*var (\w+) := (.+)$", code)
        if not m: continue
        name, expr = m.groups()
        reasons = []
        if ".get(" in expr: reasons.append(".get()")
        if re.search(INPUT_PROPS, expr): reasons.append("InputEvent property")
        if "JSON.parse" in expr: reasons.append("JSON")
        toks = set(re.findall(r"\b[A-Za-z_]\w*\b", re.sub(r'"[^"]*"', '""', expr)))
        for t in toks:
            if t in local_variant: reasons.append("untyped '%s'" % t)
        for c in list(local_cont) + [x[:-2] for x in members_variant if x.endswith("[]")]:
            if re.search(r"\b%s\[" % re.escape(c), expr): reasons.append("index of untyped '%s'" % c)
        for t in toks:
            if t in members_variant: reasons.append("untyped member '%s'" % t)
        # casts / constructors / typed calls make the whole thing typed
        if re.match(r"^(int|float|str|bool|Vector2i?|Color|Rect2|String|PackedStringArray|PackedVector2Array)\(.*\)$", expr.strip()): continue
        if re.match(r"^\w+\.new\(", expr.strip()): continue
        if re.match(r"^.*\bas \w+\)?$", expr.strip()) and "(" not in expr.split(" as ")[-1]: continue
        if reasons:
            hits += 1
            print("%s:%d  %s  <- %s" % (rel, i, code.strip()[:110], ", ".join(sorted(set(reasons)))))
print("%d candidate(s)" % hits)
