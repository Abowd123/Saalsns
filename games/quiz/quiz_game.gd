extends KnowledgeRound
## تحدي المعرفة: 7 categories rotate by level, difficulty rises every few levels.
## Flagged questions are never shown. Geography lives in its own game.

const CATS := ["culture", "history", "physics", "chemistry", "biology", "english", "football"]
const CAT_NAMES := {"culture": "ثقافة عامة", "history": "تاريخ وحضارات", "physics": "فيزياء", "chemistry": "كيمياء", "biology": "أحياء", "english": "إنجليزي", "football": "كرة القدم"}


func _category() -> String:
	return CATS[(level_id - 1) % CATS.size()]


func _max_difficulty() -> int:
	return clampi(1 + int((level_id - 1) / 7.0), 1, 3)


func title_text() -> String:
	return "تحدي المعرفة · %s" % CAT_NAMES[_category()]


func pick_round() -> Array:
	var reviews := ContentLab.load_reviews()
	var all := ContentLab.load_questions()
	var max_d := _max_difficulty()
	var pool := []
	# Small categories: widen difficulty until a full round of 10 is possible.
	while true:
		pool.clear()
		for q in all:
			if q["category"] == _category() and int(q["difficulty"]) <= max_d and not ContentLab.is_flagged(q, reviews):
				pool.append(q)
		if pool.size() >= ROUND or max_d >= 3:
			break
		max_d += 1
	return least_seen(pool, ROUND, "quiz")
