extends KnowledgeRound
## عواصم وأعلام: levels 1-3 capitals, 4-6 country of a capital, 7-9 flags, 10 mixed.

var flags := {}


func _ready_data() -> void:
	var f = JSON.parse_string(FileAccess.get_file_as_string("res://content/knowledge/flags.json"))
	if f is Dictionary:
		for s in f["flags"]:
			flags[s["id"]] = s


func _mode() -> String:
	if level_id <= 3:
		return "cap"
	if level_id <= 6:
		return "ctry"
	if level_id <= 9:
		return "flag"
	return "mix"


func title_text() -> String:
	match _mode():
		"cap":
			return "عواصم الدول"
		"ctry":
			return "عاصمة أي دولة؟"
		"flag":
			return "علم أي دولة؟"
	return "مزيج العواصم والأعلام"


func pick_round() -> Array:
	_ready_data()
	var reviews := ContentLab.load_reviews()
	var all := ContentLab.load_questions()
	var mode := _mode()
	var max_d := 1 + ((level_id - 1) % 3)
	var pool := []
	for q in all:
		if q["category"] != "geography" or ContentLab.is_flagged(q, reviews):
			continue
		var id: String = q["id"]
		if id.begins_with("geo_cap_") and (mode == "cap" or mode == "mix") and int(q["difficulty"]) <= max_d:
			pool.append(q)
		elif id.begins_with("geo_ctry_") and (mode == "ctry" or mode == "mix") and int(q["difficulty"]) <= max_d + 1:
			pool.append(q)
		elif id.begins_with("geo_flag_") and (mode == "flag" or mode == "mix") and flags.has(str(q.get("flag", ""))):
			pool.append(q)
	return least_seen(pool, ROUND, "geo")


func visual_for(q: Dictionary) -> Control:
	if not q.has("flag"):
		return null
	var fv := FlagView.new()
	fv.set_spec(flags.get(q["flag"], {}))
	return fv


func visual_height(q: Dictionary) -> float:
	return 220.0 if q.has("flag") else 0.0
