extends MiniGame
## Lightning reflex: wait for the green bolt, then tap as fast as you can. Tapping before
## it (or on a decoy) is a false start: the round is replayed and counts as a mistake.
## 10 rounds; the average and best reaction times are reported. Levels add aimed targets,
## a moving target and decoys (content/lightning/levels.json).
## Rounds come from the LCG below. tools/speed_check.py ports it 1:1 and verifies 500 seeds
## per level; each level stores a fingerprint that test_runner recomputes here.

const MAX_MISTAKES := 6
const SHOW_TIME := 0.9

## Tiny deterministic RNG shared with tools/speed_check.py (same constants, same order).
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
var decoy_time := 0.35
var rng: Lcg
var plan: Dictionary = {}
var state := "idle"            # idle, wait, go, show, done
var t_round := 0.0
var go_usec := 0
var decoy_on := -1
var times: Array[int] = []
var mistakes := 0
var flash_bad := false
var tpos := Vector2.ZERO       # target centre in arena pixels (spot modes)
var tvel := Vector2.ZERO
var _paused_go := false
var _pop := 1.0               # signal pop-in (visual only; timing starts when it appears)
var arena: Control
var big: Label
var round_chip: Label
var best_chip: Label
var miss_chip: Label
var _bg: StyleBoxFlat


func _on_start() -> void:
	var v := frame("سرعة البرق")
	round_chip = chip("", "bolt", Tokens.COIN)
	best_chip = chip("", "star", Tokens.COIN)
	miss_chip = chip("", "close", Tokens.ERROR)
	arena = Control.new()
	arena.custom_minimum_size = Vector2(0, 680)
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.layout_direction = Control.LAYOUT_DIRECTION_LTR
	arena.clip_contents = true
	arena.draw.connect(_paint)
	arena.resized.connect(arena.queue_redraw)
	arena.gui_input.connect(_on_arena_input)
	v.add_child(arena)
	big = UiKit.heading("", Tokens.FS_H1, Tokens.TEXT)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var help := UiKit.label("", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	_bg = UiKit.card_style(Color(Tokens.SURFACE_1, 0.7), Tokens.RADIUS_CARD, 0)
	lv = _read_level(level_id)
	if lv.is_empty():
		title_label.text = "تعذّر تحميل المرحلة"
		return
	title_label.text = "سرعة البرق · %s" % lv["name"]
	help.text = _help_text()
	rng = Lcg.new(Time.get_ticks_usec())
	_update_hud()
	big.text = "استعد..."
	await wait(0.8)
	_begin_round()


func _read_level(id: int) -> Dictionary:
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/lightning/levels.json"))
	if not (p is Dictionary) or (p.get("levels", []) as Array).is_empty():
		return {}
	decoy_time = float(p.get("decoy_time", 0.35))
	var all: Array = p["levels"]
	return all[clampi(id - 1, 0, all.size() - 1)]


func _help_text() -> String:
	var t := "انتظر البرق الأخضر ثم اضغط فورًا. الضغط قبله خطأ."
	if str(lv["mode"]) == "spot":
		t = "انتظر البرق الأخضر ثم اضغطه هو. الضغط قبله أو خارجه خطأ."
	if str(lv["decoy"]) != "none":
		t += " احذر: إشارات حمراء وصفراء مضللة."
	if float(lv["move"]) > 0.0:
		t += " الهدف يتحرك."
	return t


## One round: random delay, optional decoys before it, target position and heading.
static func plan_round(r: Lcg, p_lv: Dictionary) -> Dictionary:
	var dmin := float(p_lv["dmin"])
	var dmax := float(p_lv["dmax"])
	var delay := dmin + r.next() * (dmax - dmin)
	var maxd := int(p_lv["decoys"])
	var count := int(r.next() * (maxd + 1))
	var cand: Array[float] = []
	for i in count:
		cand.append(0.3 + r.next() * maxf(delay - 0.75, 0.0))
	cand.sort()
	var decoys: Array = []
	var last := -10.0
	for t in cand:
		var x := 0.12 + r.next() * 0.76   # drawn for every candidate: keeps the Python port in step
		var y := 0.12 + r.next() * 0.76
		if t - last >= 0.45:
			decoys.append({"t": t, "x": x, "y": y})
			last = t
	var tx := 0.12 + r.next() * 0.76
	var ty := 0.12 + r.next() * 0.76
	var ang := r.next() * TAU
	return {"delay": delay, "decoys": decoys, "x": tx, "y": ty, "angle": ang}


static func fingerprint(p_lv: Dictionary, seed_value: int) -> int:
	var r := Lcg.new(seed_value)
	var fp := 0
	for i in int(p_lv.get("rounds", 10)):
		var p := plan_round(r, p_lv)
		fp += int(float(p["delay"]) * 1000) + int(float(p["x"]) * 1000) + int(float(p["y"]) * 1000) + int(float(p["angle"]) * 1000)
		for d in p["decoys"]:
			fp += int(float(d["t"]) * 1000)
	return fp


static func stars_for(avg_ms: float, p_mistakes: int, p_lv: Dictionary) -> int:
	if p_mistakes >= MAX_MISTAKES:
		return 0
	var s := 1
	if avg_ms <= float(p_lv["t3"]):
		s = 3
	elif avg_ms <= float(p_lv["t2"]):
		s = 2
	if p_mistakes >= 3:
		s = maxi(1, s - 1)
	return s


func _rounds() -> int:
	return int(lv.get("rounds", 10))


func _update_hud() -> void:
	UiKit.set_chip(round_chip, "الجولة %d/%d" % [mini(times.size() + 1, _rounds()), _rounds()], false)
	var best := "—"
	if not times.is_empty():
		best = "%d ms" % times.min()
	UiKit.set_chip(best_chip, "أفضل " + best)
	UiKit.set_chip(miss_chip, "%d/%d" % [mistakes, MAX_MISTAKES])


func _begin_round() -> void:
	if _finished or lv.is_empty():
		return
	plan = plan_round(rng, lv)
	if str(lv["decoy"]) == "none":
		plan["decoys"] = []
	t_round = 0.0
	decoy_on = -1
	flash_bad = false
	state = "wait"
	big.text = "انتظر..."
	big.add_theme_color_override("font_color", Tokens.TEXT_MUTED)
	arena.queue_redraw()


func _process(delta: float) -> void:
	if state == "wait":
		t_round += delta
		var on := -1
		var ds: Array = plan["decoys"]
		for i in ds.size():
			var dt := float(ds[i]["t"])
			if t_round >= dt and t_round < dt + decoy_time:
				on = i
		if on != decoy_on:
			decoy_on = on
			arena.queue_redraw()
		if t_round >= float(plan["delay"]):
			_go()
	elif state == "go":
		var el := (Time.get_ticks_usec() - go_usec) / 1000000.0
		if float(lv["move"]) > 0.0:
			_move_target(delta)
			arena.queue_redraw()
		if el >= float(lv["window"]):
			_record(int(float(lv["window"]) * 1000), "بطيء!")


func _target_r() -> float:
	return maxf(float(lv["size"]) * arena.size.x, Tokens.TOUCH_MIN / 2.0)


func _go() -> void:
	state = "go"
	decoy_on = -1
	tpos = Vector2(float(plan["x"]) * arena.size.x, float(plan["y"]) * arena.size.y)
	var r := _target_r()
	tpos = tpos.clamp(Vector2(r, r), arena.size - Vector2(r, r))
	var a := float(plan["angle"])
	tvel = Vector2(cos(a), sin(a)) * float(lv["move"]) * arena.size.x
	go_usec = Time.get_ticks_usec()
	_pop = 1.0
	if Quality.fancy():
		_pop = 0.0
		create_tween().tween_method(func(v: float):
			_pop = v
			arena.queue_redraw(), 0.0, 1.0, Motion.FAST).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	big.text = "الآن!"
	big.add_theme_color_override("font_color", Tokens.SUCCESS)
	arena.queue_redraw()


## Bounces inside the arena (gameplay motion: it runs on every quality setting).
func _move_target(delta: float) -> void:
	var r := _target_r()
	tpos += tvel * delta
	if tpos.x < r or tpos.x > arena.size.x - r:
		tvel.x = -tvel.x
		tpos.x = clampf(tpos.x, r, arena.size.x - r)
	if tpos.y < r or tpos.y > arena.size.y - r:
		tvel.y = -tvel.y
		tpos.y = clampf(tpos.y, r, arena.size.y - r)


func _on_arena_input(e: InputEvent) -> void:
	# Touch arrives as emulated mouse too; reading only mouse avoids double taps.
	var mb := e as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var now := Time.get_ticks_usec()
	if state == "wait":
		_mistake("خدعة! ليست الإشارة" if decoy_on >= 0 else "مبكر!")
	elif state == "go":
		if str(lv["mode"]) == "spot" and mb.position.distance_to(tpos) > _target_r() + 14.0:
			mistakes += 1
			Sfx.play("wrong")
			Settings.vibrate(20)
			_update_hud()
			if mistakes >= MAX_MISTAKES:
				_lose()
			return
		var ms := int((now - go_usec) / 1000)
		_record(ms, "%d ms" % ms)


func _record(ms: int, text: String) -> void:
	state = "show"
	times.append(ms)
	Sfx.play("pop", clampf(1.4 - ms / 1000.0, 0.8, 1.3))
	Settings.vibrate(12)
	big.text = text
	var good := ms <= int(lv["t3"])
	big.add_theme_color_override("font_color", Tokens.SUCCESS if good else (Tokens.COIN if ms <= int(lv["t2"]) else Tokens.TEXT))
	var at := tpos if str(lv["mode"]) == "spot" else arena.size / 2.0
	UiKit.ring(arena, at, Tokens.SUCCESS if good else Tokens.TEXT_MUTED, _target_r() * 2.0 if str(lv["mode"]) == "spot" else 160.0)
	if good:
		UiKit.burst(arena, at, Tokens.SUCCESS, 40)
	Motion.bump(big)
	_update_hud()
	arena.queue_redraw()
	await wait(SHOW_TIME)
	if times.size() >= _rounds():
		_end()
	else:
		_begin_round()


func _mistake(text: String) -> void:
	state = "show"
	mistakes += 1
	flash_bad = true
	Sfx.play("wrong")
	Settings.vibrate(30)
	Motion.shake(arena)
	UiKit.ring(arena, arena.size / 2.0, Tokens.ERROR, 180.0)
	big.text = text
	big.add_theme_color_override("font_color", Tokens.ERROR)
	_update_hud()
	arena.queue_redraw()
	if mistakes >= MAX_MISTAKES:
		_lose()
		return
	await wait(SHOW_TIME)
	_begin_round()   # the round is replayed with a new delay


func _lose() -> void:
	state = "done"
	await wait(SHOW_TIME)
	finish(0, 0, "%d أخطاء: الضغط قبل الإشارة أو على إشارة مضللة." % mistakes)


func _end() -> void:
	state = "done"
	var sum := 0
	for t in times:
		sum += t
	var avg := float(sum) / maxi(times.size(), 1)
	var best: int = times.min()
	var stars := stars_for(avg, mistakes, lv)
	Sfx.play("win")
	await wait(Motion.NEXT_BUTTON_MAX_DELAY)
	var score := maxi(100, 2000 - int(avg) * 2 - mistakes * 60)
	finish(stars, score, "المتوسط %d ms · الأفضل %d ms · %d أخطاء\n3 نجوم: متوسط %d ms أو أقل" % [int(avg), best, mistakes, int(lv["t3"])])


## Pausing during "go" would add the menu time to the reaction: replay that round.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and state == "go":
		_paused_go = true
		state = "show"
	elif what == NOTIFICATION_UNPAUSED and _paused_go:
		_paused_go = false
		_begin_round()


# ---------------- drawing ----------------
func _paint() -> void:
	if arena.size.x < 60.0 or arena.size.y < 60.0 or lv.is_empty():
		return
	var full := Rect2(Vector2.ZERO, arena.size)
	arena.draw_style_box(_bg, full)
	var c := arena.size / 2.0
	var spot := str(lv["mode"]) == "spot"
	var big_r := minf(arena.size.x, arena.size.y) * 0.22
	if state == "wait" and decoy_on >= 0:
		var d: Dictionary = plan["decoys"][decoy_on]
		var col := Tokens.ERROR if decoy_on % 2 == 0 else Tokens.COIN
		if str(lv["decoy"]) == "color":
			arena.draw_rect(full.grow(-6), Color(col, 0.85))
			_decoy_mark(c, big_r, decoy_on)
		else:
			var p := Vector2(float(d["x"]) * arena.size.x, float(d["y"]) * arena.size.y)
			var r := _target_r()
			p = p.clamp(Vector2(r, r), arena.size - Vector2(r, r))
			arena.draw_circle(p, r, col)
			_decoy_mark(p, r, decoy_on)
	elif state == "go" or (state == "show" and not flash_bad):
		var grow := 0.7 + 0.3 * _pop
		if spot:
			var r2 := _target_r() * grow
			if Quality.fancy():
				arena.draw_circle(tpos, r2 * 1.35, Color(Tokens.SUCCESS, 0.18))
			arena.draw_circle(tpos, r2, Tokens.SUCCESS)
			_bolt(tpos, r2 * 0.75, Tokens.BG)
		else:
			arena.draw_rect(full.grow(-6), Color(Tokens.SUCCESS, 0.9))
			_bolt(c, big_r * grow, Tokens.BG)
	elif state == "show" and flash_bad:
		arena.draw_rect(full.grow(-6), Color(Tokens.ERROR, 0.25))
		_decoy_mark(c, big_r * 0.6, 0)
	else:
		# waiting: calm ring in the middle (no hint about when)
		arena.draw_arc(c, big_r, 0, TAU, 48, Color(Tokens.TEXT_MUTED, 0.35), 4.0, true)
		arena.draw_circle(c, 6.0, Color(Tokens.TEXT_MUTED, 0.5))


## Decoys carry a different shape (X or ring), so they never rely on colour alone.
func _decoy_mark(p: Vector2, r: float, k: int) -> void:
	if k % 2 == 0:
		var a := r * 0.45
		arena.draw_line(p + Vector2(-a, -a), p + Vector2(a, a), Tokens.BG, maxf(4.0, r * 0.14), true)
		arena.draw_line(p + Vector2(a, -a), p + Vector2(-a, a), Tokens.BG, maxf(4.0, r * 0.14), true)
	else:
		arena.draw_arc(p, r * 0.45, 0, TAU, 32, Tokens.BG, maxf(4.0, r * 0.14), true)


func _bolt(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		p + Vector2(0.15, -1.0) * r, p + Vector2(-0.55, 0.12) * r, p + Vector2(-0.05, 0.12) * r,
		p + Vector2(-0.2, 1.0) * r, p + Vector2(0.55, -0.2) * r, p + Vector2(0.05, -0.2) * r])
	arena.draw_colored_polygon(pts, col)
