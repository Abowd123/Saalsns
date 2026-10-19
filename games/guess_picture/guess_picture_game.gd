extends KnowledgeRound
## Guess the picture: a code-drawn picture (vector SVG text or a geometric flag) and four
## names; pick the right one. 10 levels by category (content/guess_picture/levels.json),
## 152 items (items.json), 10 questions per level, least-seen first. The 3 wrong answers
## always come from the same category, so the picture has to be recognised.
## No image files: SVG text is rasterised at the exact size needed (only the 10 of the round).
## Content checked by tools/guess_check.py.

const PIC_H := 300.0

var items: Array = []
var lv: Dictionary = {}
var questions := {}
var flags := {}


func _load() -> void:
	if not items.is_empty():
		return
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/guess_picture/items.json"))
	var l = JSON.parse_string(FileAccess.get_file_as_string("res://content/guess_picture/levels.json"))
	if not (p is Dictionary) or not (l is Dictionary):
		return
	items = p["items"]
	questions = l["questions"]
	var all: Array = l["levels"]
	lv = all[clampi(level_id - 1, 0, all.size() - 1)]
	var f = JSON.parse_string(FileAccess.get_file_as_string("res://content/knowledge/flags.json"))
	if f is Dictionary:
		for s in f["flags"]:
			flags[s["id"]] = s


func title_text() -> String:
	_load()
	return "خمّن الصورة · %s" % str(lv.get("name", ""))


## Builds MCQ questions for this level's categories.
func pick_round() -> Array:
	_load()
	var pool := build_pool(items, lv.get("cats", []), questions, rng)
	return least_seen(pool, ROUND, "guess_picture")


static func build_pool(p_items: Array, cats: Array, p_questions: Dictionary, r: RandomNumberGenerator) -> Array:
	var by_cat := {}
	for it in p_items:
		if not by_cat.has(it["cat"]):
			by_cat[it["cat"]] = []
		by_cat[it["cat"]].append(it)
	var pool := []
	for it in p_items:
		if not (str(it["cat"]) in cats):
			continue
		var others: Array = []
		for o in by_cat[it["cat"]]:
			if o["id"] != it["id"]:
				others.append(str(o["name"]))
		var picks: Array = []
		while picks.size() < 3 and not others.is_empty():
			picks.append(others.pop_at(r.randi_range(0, others.size() - 1)))
		pool.append({"id": it["id"], "question": str(p_questions.get(it["cat"], "ما هذا؟")),
			"answers": [str(it["name"])] + picks, "correct": 0,
			"explanation": "الجواب: %s" % it["name"], "item": it})
	return pool


func visual_for(q: Dictionary) -> Control:
	var it: Dictionary = q.get("item", {})
	if it.has("svg"):
		var tr := TextureRect.new()
		tr.texture = svg_texture(str(it["svg"]), int(PIC_H))
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_on_enter(tr)
		return tr
	var fv := FlagView.new()
	fv.set_spec(it["spec"] if it.has("spec") else flags.get(str(it.get("flag", "")), {}))
	_fade_on_enter(fv)
	return fv


func _fade_on_enter(c: Control) -> void:
	if Motion.reduce_motion:
		return
	c.tree_entered.connect(func(): Motion.fade_in(c, Motion.BASE), CONNECT_ONE_SHOT)


func visual_height(_q: Dictionary) -> float:
	return PIC_H


static func svg_texture(body: String, px: int) -> Texture2D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">%s</svg>' % body
	var img := Image.new()
	if img.load_svg_from_string(svg, float(px) / 100.0) != OK:
		Log.warn("guess_picture: svg failed")
		return null
	return ImageTexture.create_from_image(img)
