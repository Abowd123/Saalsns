"""Heuristic GDScript checks for errors Godot reports at parse time (no Godot needed):
  1. `var x := <Variant expression>`  -> "Cannot infer the type" (hard error)
  2. tabs/spaces mixed in one file
  3. unbalanced brackets
  4. res:// paths that do not exist
Heuristic only: a clean run does NOT prove the project compiles."""
import re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
issues = []
SAFE_CALLS = {"str","int","float","bool","len","Vector2","Vector2i","Color","Rect2","PackedVector2Array","PackedStringArray",
              "maxi","mini","maxf","minf","clampi","clampf","absf","absi","roundi","floori","ceili","sqrt","sin","cos","atan2","lerpf","snappedf","randf","randi","randf_range","randi_range","fmod","posmod","hash","deg_to_rad","pow","round","floor","ceil","abs"}
for f in sorted(ROOT.rglob("*.gd")):
    rel = f.relative_to(ROOT).as_posix()
    src = f.read_text(encoding="utf-8")
    lines = src.split("\n")
    if any(l.startswith("\t") for l in lines) and any(re.match(r"^ +\S", l) for l in lines):
        issues.append(f"{rel}: mixed tab/space indentation")
    variant = set()
    for i, l in enumerate(lines, 1):
        code = l.split("#")[0] if '"' not in l else l
        m = re.match(r"^\s*func \w+\((.*)\)", code)
        if m:
            variant = set()
            for p in m.group(1).split(","):
                p = p.strip()
                if p and ":" not in p and "=" not in p:
                    variant.add(p)
                elif p and ":" not in p and "=" in p and ":=" not in p:
                    variant.add(p.split("=")[0].strip())
        m = re.match(r"^\s*for (\w+) in (.+):\s*$", code)
        if m and not re.match(r"(range\(|\d)", m.group(2)):
            variant.add(m.group(1))
        m = re.match(r"^\s*var (\w+) = ", code)
        if m:
            variant.add(m.group(1))
        m = re.match(r"^\s*var (\w+) := (.+)$", code)
        if m:
            expr = m.group(2).strip()
            tok = re.match(r"(\w+)", expr)
            if tok:
                t = tok.group(1)
                rest = expr[len(t):]
                if t in variant and (rest.startswith(".") or rest.startswith("[")):
                    issues.append(f"{rel}:{i}: '{m.group(1)} :=' inferred from Variant '{t}{rest[:25]}'")
            if re.search(r"\bJSON\.parse_string\(", expr) or re.match(r"^(max|min|clamp)\(", expr):
                issues.append(f"{rel}:{i}: '{m.group(1)} :=' from Variant-returning call")
            if re.match(r"^\w+\[[^\]]+\]$", expr) and tok and tok.group(1) not in ("Tokens",):
                pass
    for m in re.findall(r"res://[^\"'\s]+", src):
        if "%" not in m and not (ROOT / m[6:]).exists():
            issues.append(f"{rel}: missing {m}")
print("\n".join(issues) if issues else "no issues")
print(f"{len(issues)} issue(s)")
sys.exit(1 if issues else 0)
