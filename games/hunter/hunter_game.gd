extends MiniGame
## Target hunter: moving targets drift and bounce around the arena. Tap the round targets,
## avoid the red square ones (each wrong tap costs time and breaks the streak). A target
## that escapes also breaks the streak. Stars by hits against goals in
## content/hunter/levels.json. Spawns come from the LCG below; tools/speed_check.py ports it
## 1:1 and proves with bots that every goal is reachable on 300 seeds per level. Every play
## of a level has the same number of good and wrong targets.
## (Replaces the dev-only demo_tap as the real tap game; demo_tap stays hidden as before.)

const FADE := 0.45   # last part of a target's life: it fades out as a warning


## Same RNG as lightning_game.gd and tools/speed_check.py.
class Lcg:
	var s := 1

	func _init(seed_value: int) -> void:
		s = posmod(seed_value, 2147483648)
		if s == 0:
			s = 1

	func next() -> float:
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648.0


var lv: Dictionary = {}
var plan: Array = []
var next_i := 0
var live: Array = []           # {pos, vel, r, good, born, life}
var elapsed := 0.0
var penalty := 0.0
var duration := 30.0
var running := false
var hits := 0
var wrong := 0
var escaped := 0
var combo := 0
var best_combo := 0
var score := 0
var goals: Array = [1, 2, 3]
var arena: Control
var status: Label
var time_chip: Label
var hits_chip: Label
var combo_chip: Label
var _bg: StyleBoxFlat


func _on_start() -> void:
	var v := frame("صائد الأهداف")
	time_chip = chip("", "flame", Tokens.ERROR)
	hits_chip = chip("", "check", Tokens.COIN)
	combo_chip = chip("", "bolt", Tokens.COIN)
	arena = Control.new()
	arena.custom_minimum_size = Vector2(0, 720)
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.layout_direction = Control.LAYOUT_DIRECTION_LTR
	arena.clip_contents = true
	arena.draw.connect(_paint)
	arena.resized.connect(arena.queue_redraw)
	arena.gui_input.connect(_on_arena_input)
	v.add_child(arena)
	status = UiKit.label("", Tokens.FS_BODY, Tokens.TEXT, Tokens.font_bold)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status)
	var help := UiKit.label("اضغط الأهداف الدائرية، وتجنب المربعات الحمراء (الخطأ يخصم %s ثوانٍ ويكسر السلسلة)." % "3", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	_bg = UiKit.card_style(Color(Tokens.SURFACE_1, 0.6), Tokens.RADIUS_CARD, 0)
	lv = _read_level(level_id)
	if lv.is_empty():
		title_label.text = "تعذّر تحميل المرحلة"
		return
	title_label.text = "صائد الأهداف · %s" % lv["name"]
	duration = float(lv["duration"])
	goals = lv["goals"]
	help.text = "اضغط الأهداف الدائرية، وتجنب المربعات الحمراء (الخطأ يخصم %d ثوانٍ ويكسر السلسلة). نجمة: %d · نجمتان: %d · 3 نجوم: %d" % [int(lv["penalty"]), int(goals[0]), int(goals[1]), int(goals[2])]
	plan = make_plan(lv, Time.get_ticks_usec())
	_update_hud()
	status.text = "استعد..."
	await wait(0.8)
	if _finished:
		return
	status.text = ""
	running = true


func _read_level(id: int) -> Dictionary:
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/hunter/levels.json"))
	if not (p is Dictionary) or (p.get("levels", []) as Array).is_empty():
		return {}
	var all: Array = p["levels"]
	return all[clampi(id - 1, 0, all.size() - 1)]


## Fixed counts per level, shuffled order, evenly spread spawn times with jitter.
static func make_plan(p_lv: Dictionary, seed_value: int) -> Array:
	var r := Lcg.new(seed_value)
	var n := int(p_lv["count"])
	var g := int(p_lv["goods"])
	var dur := float(p_lv["duration"])
	var kinds: Array[bool] = []
	for i in n:
		kinds.append(i < g)
	for i in range(n - 1, 0, -1):
		var j := int(r.next() * (i + 1))
		var tmp := kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	var gap := (dur - 1.6) / (n - 1)
	var out: Array = []
	for k in n:
		var t := 0.6 + k * gap + (r.next() - 0.5) * gap * 0.6
		var x := 0.1 + r.next() * 0.8
		var y := 0.1 + r.next() * 0.8
		var ang := r.next() * TAU
		var spd := float(p_lv["smin"]) + r.next() * (float(p_lv["smax"]) - float(p_lv["smin"]))
		var life := float(p_lv["lmin"]) + r.next() * (float(p_lv["lmax"]) - float(p_lv["lmin"]))
		out.append({"t": t, "good": kinds[k], "x": x, "y": y, "angle": ang, "speed": spd, "life": life})
	return out


static func fingerprint(p_lv: Dictionary, seed_value: int) -> int:
	var fp := 0
	for s in make_plan(p_lv, seed_value):
		fp += int(float(s["t"]) * 1000) + int(float(s["life"]) * 1000) + (1000 if bool(s["good"]) else 0) + int(float(s["x"]) * 1000)
	return fp


static func stars_for(p_hits: int, p_goals: Array) -> int:
	var s := 0
	for gl in p_goals:
		if p_hits >= int(gl):
			s += 1
	return s


func _time_left() -> float:
	return maxf(duration - elapsed - penalty, 0.0)


func _update_hud() -> void:
	UiKit.set_chip(time_chip, "%d ث" % ceili(_time_left()), false)
	var next_goal := int(goals[mini(stars_for(hits, goals), goals.size() - 1)])
	UiKit.set_chip(hits_chip, "%d/%d" % [hits, next_goal])
	UiKit.set_chip(combo_chip, "×%d" % combo)


func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	var w := arena.size.x
	while next_i < plan.size() and float(plan[next_i]["t"]) <= elapsed:
		var sp: Dictionary = plan[next_i]
		next_i += 1
		var r := maxf(float(lv["size"]) * w, Tokens.TOUCH_MIN / 2.0)
		var pos := Vector2(float(sp["x"]) * w, float(sp["y"]) * arena.size.y).clamp(Vector2(r, r), arena.size - Vector2(r, r))
		var a := float(sp["angle"])
		live.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * float(sp["speed"]) * w, "r": r, "good": bool(sp["good"]), "born": elapsed, "life": float(sp["life"])})
	for i in range(live.size() - 1, -1, -1):
		var o: Dictionary = live[i]
		var p: Vector2 = o["pos"] + o["vel"] * delta
		var v: Vector2 = o["vel"]
		var r2: float = o["r"]
		if p.x < r2 or p.x > arena.size.x - r2:
			v.x = -v.x
		if p.y < r2 or p.y > arena.size.y - r2:
			v.y = -v.y
		o["pos"] = p.clamp(Vector2(r2, r2), arena.size - Vector2(r2, r2))
		o["vel"] = v
		if elapsed - float(o["born"]) >= float(o["life"]):
			live.remove_at(i)
			if bool(o["good"]):
				escaped += 1
				if combo > 0:
					combo = 0
					status.text = "هرب هدف! انكسرت السلسلة"
					status.add_theme_color_override("font_color", Tokens.TEXT_MUTED)
	_update_hud()
	arena.queue_redraw()   # the targets are moving: redraw every frame while playing
	if _time_left() <= 0.0:
		_end()


func _on_arena_input(e: InputEvent) -> void:
	# Touch arrives as emulated mouse too; reading only mouse avoids double taps.
	var mb := e as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed or not running:
		return
	for i in range(live.size() - 1, -1, -1):   # topmost (newest) first
		var o: Dictionary = live[i]
		if mb.position.distance_to(o["pos"]) <= float(o["r"]) + 10.0:
			live.remove_at(i)
			if bool(o["good"]):
				_hit(o)
			else:
				_wrong(o)
			return


func _hit(o: Dictionary) -> void:
	hits += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	var gained := 10 + 2 * mini(combo, 10)
	score += gained
	UiKit.ring(arena, o["pos"], accent, float(o["r"]) * 1.7)
	UiKit.float_text(arena, o["pos"], "+%d" % gained, Tokens.COIN)
	Sfx.play("pop", 1.0 + minf(combo * 0.03, 0.4))
	Settings.vibrate(10)
	UiKit.burst(arena, o["pos"], accent, 30)
	status.text = "سلسلة ×%d" % combo if combo >= 3 else ""
	status.add_theme_color_override("font_color", Tokens.COIN)
	_update_hud()


func _wrong(o: Dictionary) -> void:
	wrong += 1
	combo = 0
	penalty += float(lv["penalty"])
	Sfx.play("wrong")
	Settings.vibrate(30)
	Motion.shake(arena)
	UiKit.burst(arena, o["pos"], Tokens.ERROR, 24)
	UiKit.ring(arena, o["pos"], Tokens.ERROR, float(o["r"]) * 1.7)
	UiKit.float_text(arena, o["pos"], "−%d ث" % int(lv["penalty"]), Tokens.ERROR)
	status.text = "هدف خاطئ! −%d ثوانٍ" % int(lv["penalty"])
	status.add_theme_color_override("font_color", Tokens.ERROR)
	_update_hud()


func _end() -> void:
	running = false
	live.clear()
	arena.queue_redraw()
	var stars := stars_for(hits, goals)
	Sfx.play("win" if stars > 0 else "wrong")
	status.text = "انتهى الوقت"
	await wait(Motion.NEXT_BUTTON_MAX_DELAY)
	finish(stars, score, "أصبت %d هدفًا · أفضل سلسلة %d · %d أهداف خاطئة · هرب %d" % [hits, best_combo, wrong, escaped])


# ---------------- drawing ----------------
func _paint() -> void:
	if arena.size.x < 60.0 or arena.size.y < 60.0:
		return
	arena.draw_style_box(_bg, Rect2(Vector2.ZERO, arena.size))
	var fancy := Quality.fancy()
	for o in live:
		var p: Vector2 = o["pos"]
		var r: float = o["r"]
		var age := elapsed - float(o["born"])
		var left := float(o["life"]) - age
		var alpha := clampf(left / FADE, 0.25, 1.0)
		var sc := 1.0
		if fancy and age < Motion.FAST:
			sc = age / Motion.FAST   # quick pop-in (off on low quality / reduce motion)
		var rr := r * sc
		if bool(o["good"]):
			if fancy:
				arena.draw_circle(p, rr * 1.25, Color(accent, 0.15 * alpha))
			arena.draw_circle(p, rr, Color(accent, alpha))
			arena.draw_circle(p, rr * 0.68, Color(Tokens.TEXT, alpha))
			arena.draw_circle(p, rr * 0.38, Color(accent, alpha))
			arena.draw_circle(p, rr * 0.14, Color(Tokens.TEXT, alpha))
		else:
			var q := Rect2(p - Vector2(rr, rr) * 0.86, Vector2(rr, rr) * 1.72)
			arena.draw_rect(q, Color(Tokens.ERROR, alpha))
			var a := rr * 0.42
			arena.draw_line(p + Vector2(-a, -a), p + Vector2(a, a), Color(Tokens.BG, alpha), maxf(4.0, rr * 0.16), true)
			arena.draw_line(p + Vector2(a, -a), p + Vector2(-a, a), Color(Tokens.BG, alpha), maxf(4.0, rr * 0.16), true)
