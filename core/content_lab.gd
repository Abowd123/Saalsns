class_name ContentLab
## Content validation used by tests, the review screen, and the release check.
## Mirrors tools/build_quiz_bank.py validate() so phone-side and build-side agree.

const QUESTIONS_PATH := "res://content/questions/quiz_ar.json"
const REVIEWS_PATH := "user://content_reviews.json"


static func normalize(t: String) -> String:
	var re := RegEx.new()
	re.compile("[\\x{064B}-\\x{0652}\\x{0640}]")
	t = re.sub(t, "", true)
	t = t.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ة", "ه").replace("ى", "ي")
	for ch in ["؟", "?", "!", ".", ",", "،", ":", "؛", ";", "(", ")", "«", "»", "\"", "'", "-"]:
		t = t.replace(ch, " ")
	while t.find("  ") != -1:
		t = t.replace("  ", " ")
	return t.strip_edges().to_lower()


static var _questions: Array = []


## Parsed once per session (the bank is ~250 KB; parsing it every round stalls slow phones).
static func load_questions() -> Array:
	if _questions.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(QUESTIONS_PATH))
		if parsed is Dictionary and parsed.has("questions"):
			_questions = parsed["questions"]
	return _questions


static func validate(items: Array) -> Array[String]:
	var errs: Array[String] = []
	var ids := {}
	var seen := {}
	for it in items:
		var id := str(it.get("id", ""))
		if id == "" or ids.has(id):
			errs.append("bad or duplicate id: " + id)
		ids[id] = true
		var n := normalize(str(it.get("question", ""))) + ("|" + str(it["flag"]) if it.has("flag") else "")
		if seen.has(n):
			errs.append("duplicate question: %s ~ %s" % [id, seen[n]])
		seen[n] = id
		var answers: Array = it.get("answers", [])
		if answers.size() != 4:
			errs.append("needs 4 answers: " + id)
			continue
		var uniq := {}
		for a in answers:
			uniq[str(a).strip_edges()] = true
		if uniq.size() != 4:
			errs.append("non-unique answers: " + id)
		var c := int(it.get("correct", -1))
		if c < 0 or c > 3:
			errs.append("bad correct index: " + id)
		if str(it.get("question", "")).length() > 120:
			errs.append("question too long: " + id)
		if str(it.get("explanation", "")) == "":
			errs.append("missing explanation: " + id)
		if (it.get("sources_suggested", []) as Array).size() < 2:
			errs.append("needs 2 sources: " + id)
	return errs


# ---------- human review ----------
static func load_reviews() -> Dictionary:
	if not FileAccess.file_exists(REVIEWS_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REVIEWS_PATH))
	return parsed if parsed is Dictionary else {}


static func save_reviews(r: Dictionary) -> void:
	var f := FileAccess.open(REVIEWS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(r, "\t"))
		f.close()


## verified in the shipped bank, or approved on this device by the reviewer.
static func is_verified(item: Dictionary, reviews: Dictionary) -> bool:
	if str(item.get("status", "")) == "verified":
		return true
	var r: Dictionary = reviews.get(str(item.get("id", "")), {})
	return str(r.get("verdict", "")) == "ok"


static func is_flagged(item: Dictionary, reviews: Dictionary) -> bool:
	if str(item.get("status", "")) == "flagged":
		return true
	var r: Dictionary = reviews.get(str(item.get("id", "")), {})
	return str(r.get("verdict", "")) == "flag"


## Release gate: every playable question must be verified, flagged ones are excluded.
static func release_report(items: Array, reviews: Dictionary) -> Dictionary:
	var verified := 0
	var flagged := 0
	for it in items:
		if is_flagged(it, reviews):
			flagged += 1
		elif is_verified(it, reviews):
			verified += 1
	return {"total": items.size(), "verified": verified, "flagged": flagged, "pending": items.size() - verified - flagged}


## Returns a copy with the answers shuffled and "correct" remapped.
static func shuffled(item: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var q := item.duplicate(true)
	var order := [0, 1, 2, 3]
	for i in range(3, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var src: Array = item["answers"]
	var out := []
	var correct := 0
	for k in 4:
		out.append(src[order[k]])
		if order[k] == int(item["correct"]):
			correct = k
	q["answers"] = out
	q["correct"] = correct
	return q
