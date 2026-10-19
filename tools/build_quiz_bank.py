"""Builds content/questions/quiz_ar.json from the TSV banks + countries.tsv.
Every item starts as status "ai_drafted". Only a human review (in-app Review screen)
moves it to "verified". Release builds must contain verified items only (see validate)."""
import csv, json, random, unicodedata, re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
K = ROOT / "content/knowledge"
OUT = ROOT / "content/questions/quiz_ar.json"
rng = random.Random(20261019)

def norm(t):
    t = re.sub(r"[\u064B-\u0652\u0640]", "", t)          # harakat + tatweel
    t = t.replace("أ","ا").replace("إ","ا").replace("آ","ا").replace("ة","ه").replace("ى","ي")
    return re.sub(r"[^\w]+", " ", t).strip().lower()

items = []
def add(cat, diff, q, correct, wrongs, expl, sources, qid=None):
    answers = [correct] + list(wrongs)
    assert len(answers) == 4, q
    items.append({"id": qid or f"{cat}_{len([i for i in items if i['category']==cat])+1:03d}",
                  "category": cat, "difficulty": int(diff), "type": "mcq", "question": q,
                  "answers": answers, "correct": 0, "explanation": expl,
                  "sources_suggested": sources, "status": "ai_drafted", "time_sensitive": False, "added_in": "0.8.0"})

for f in ["bank_science.tsv", "bank_humanities.tsv"]:
    for r in csv.DictReader(open(K / f, encoding="utf-8"), delimiter="\t"):
        add(r["category"], r["difficulty"], r["question"], r["correct"], [r["wrong1"], r["wrong2"], r["wrong3"]], r["explanation"], [r["source1"], r["source2"]])

countries = list(csv.DictReader(open(K / "countries.tsv", encoding="utf-8"), delimiter="\t"))
by_cont = {}
for c in countries:
    by_cont.setdefault(c["continent"], []).append(c)
conts = sorted(by_cont)
for c in countries:
    same = [x for x in by_cont[c["continent"]] if x["id"] != c["id"]]
    pool = same if len(same) >= 3 else [x for x in countries if x["id"] != c["id"]]
    pick = rng.sample(pool, 3)
    src = ["Britannica: " + c["country"], "UN Statistics Division: country profile"]
    if norm(c["capital"]) != norm(c["country"]):
        add("geography", c["difficulty"], f"ما عاصمة {c['country']}؟", c["capital"], [p["capital"] for p in pick], f"عاصمة {c['country']} هي {c['capital']}.", src, f"geo_cap_{c['id']}")
        add("geography", min(3, int(c["difficulty"]) + 1), f"{c['capital']} عاصمة أي دولة؟", c["country"], [p["country"] for p in pick], f"{c['capital']} عاصمة {c['country']}.", src, f"geo_ctry_{c['id']}")
    others = rng.sample([x for x in conts if x != c["continent"]], 3)
    add("geography", c["difficulty"], f"في أي قارة تقع {c['country']}؟", c["continent"], others, f"تقع {c['country']} في {c['continent']}.", src, f"geo_cont_{c['id']}")

flags = json.load(open(K / "flags.json", encoding="utf-8"))["flags"]
cname = {c["id"]: c["country"] for c in countries}
fids = [f["id"] for f in flags if f["id"] in cname]
kind = {f["id"]: f["kind"] for f in flags}
for k in fids:
    others = [o for o in fids if o != k]
    rng.shuffle(others)
    others.sort(key=lambda o: kind[o] != kind[k])   # same layout first = harder distractors
    add("geography", 2, f"علم أي دولة هذا؟ [{k}]", cname[k], [cname[o] for o in others[:3]], f"هذا علم {cname[k]}.", ["Britannica: flag of " + cname[k], "Official government portal of " + cname[k]], f"geo_flag_{k}")
    items[-1]["flag"] = k
    items[-1]["question"] = "علم أي دولة هذا؟"

def validate(items):
    errs = []; seen_q = {}; ids = set()
    for it in items:
        if it["id"] in ids: errs.append("duplicate id " + it["id"])
        ids.add(it["id"])
        n = norm(it["question"]) + ("|" + it["flag"] if "flag" in it else "")
        if n in seen_q: errs.append(f"duplicate question {it['id']} ~ {seen_q[n]}")
        seen_q[n] = it["id"]
        a = [re.sub(r"[\u064B-\u0652]", "", x).strip() for x in it["answers"]]
        if len(set(a)) != 4: errs.append("non-unique answers " + it["id"])
        if not (0 <= it["correct"] < 4): errs.append("bad correct index " + it["id"])
        if len(it["question"]) > 120: errs.append("question too long " + it["id"])
        if any(len(x) > 40 for x in it["answers"]): errs.append("answer too long " + it["id"])
        if len(it["sources_suggested"]) < 2: errs.append("needs 2 sources " + it["id"])
        if not it["explanation"]: errs.append("missing explanation " + it["id"])
    return errs

# Merge human reviews exported from the in-app Review screen (content/reviews/*.json).
# "ok" -> status verified, "flag" -> status flagged (never played). Ids that no longer exist are reported.
REV_DIR = ROOT / "content" / "reviews"
merged = {"ok": 0, "flag": 0, "unknown": 0}
if REV_DIR.exists():
    by_id = {it["id"]: it for it in items}
    for rf in sorted(REV_DIR.glob("*.json")):
        data = json.loads(rf.read_text(encoding="utf-8"))
        for qid, r in data.get("reviews", data).items():
            if qid not in by_id:
                merged["unknown"] += 1; print("review for unknown id:", qid); continue
            v = r.get("verdict")
            if v == "ok": by_id[qid]["status"] = "verified"; merged["ok"] += 1
            elif v == "flag": by_id[qid]["status"] = "flagged"; by_id[qid]["review_note"] = r.get("note", ""); merged["flag"] += 1
print("reviews merged:", merged)

errs = validate(items)
cats = {}
for it in items: cats[it["category"]] = cats.get(it["category"], 0) + 1
print("items:", len(items), cats)
if errs:
    print("\n".join(errs)); sys.exit(1)
OUT.write_text(json.dumps({"version": 2, "generated_by": "tools/build_quiz_bank.py", "questions": items}, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print("written", OUT.relative_to(ROOT))
