class_name KnowledgeRound
extends MiniGame
## Shared frame for knowledge games: background, header, McqPanel, 10-question round,
## least-seen selection (per device), stars by accuracy. Subclasses provide the pool.

const ROUND := 10

var panel: McqPanel
var header: Label
var sub: Label
var round_items: Array = []
var idx := 0
var correct := 0
var score := 0
var rng := RandomNumberGenerator.new()


func _on_start() -> void:
	rng.seed = Time.get_ticks_usec()
	var v := frame(title_text())
	header = title_label
	sub = chip()
	panel = McqPanel.new()
	panel.build(accent)
	panel.answered.connect(_on_answered)
	v.add_child(panel)
	round_items = pick_round()
	if round_items.is_empty():
		sub.text = "لا توجد أسئلة"
		v.add_child(UiKit.label("لا توجد أسئلة متاحة لهذه المرحلة.", Tokens.FS_BODY, Tokens.TEXT_MUTED))
		return
	_next()


## Override: header text.
func title_text() -> String:
	return ""


## Override: return up to ROUND question dicts (already shuffled).
func pick_round() -> Array:
	return []


## Override (optional): visual for a question and its height.
func visual_for(_q: Dictionary) -> Control:
	return null


func visual_height(_q: Dictionary) -> float:
	return 0.0


## Least-seen-first selection from a pool. Records seen counts in the save file.
func least_seen(pool: Array, n: int, game_key: String) -> Array:
	var seen: Dictionary = SaveService.section("seen_" + game_key)
	pool = pool.duplicate()
	pool.shuffle()
	pool.sort_custom(func(a, b): return int(seen.get(a["id"], 0)) < int(seen.get(b["id"], 0)))
	var out := []
	for q in pool.slice(0, mini(n, pool.size())):
		seen[q["id"]] = int(seen.get(q["id"], 0)) + 1
		out.append(ContentLab.shuffled(q, rng))
	SaveService.mark_dirty()
	return out


func _next() -> void:
	if idx >= round_items.size():
		var ratio := float(correct) / float(round_items.size())
		var stars := 3 if ratio >= 0.9 else (2 if ratio >= 0.7 else (1 if ratio >= 0.5 else 0))
		finish(stars, score, "%d من %d إجابات صحيحة" % [correct, round_items.size()])
		return
	var q: Dictionary = round_items[idx]
	UiKit.set_chip(sub, "%d/%d  ·  صحيح %d" % [idx + 1, round_items.size(), correct])
	panel.show_question(q, visual_for(q), visual_height(q))


func _on_answered(ok: bool, time_left: float) -> void:
	if ok:
		correct += 1
		score += 100 + int(time_left * 10.0)
	idx += 1
	_next()
