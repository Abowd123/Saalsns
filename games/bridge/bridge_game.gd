extends MiniGame
## Bridge engineer: connect joints with beams (limited budget) so the car can cross the
## gap. Beams on the road line are the deck. «اختبر» runs the physics: a Verlet truss
## where beams break when stretched or squeezed too much, with the car as a moving load.
## Stars by cost. Levels: content/bridge/levels.json. tools/bridge_gen.py runs the same
## simulation (same operations, same order) and proves for every level that the road alone
## breaks and a stored design (the 3-star cost) carries a car 20% heavier than the real one.

const SP := 10.0


## Deterministic truss + car simulation, shared with the test runner.
class BridgeSim:
	var px := PackedFloat64Array()
	var py := PackedFloat64Array()
	var ox := PackedFloat64Array()
	var oy := PackedFloat64Array()
	var fixed: Array[bool] = []
	var bl: Array = []            # [i, j, rest length, alive]
	var road := {}                # left x of a road beam -> beam index
	var loads := PackedFloat64Array()
	var g := 40.0
	var dt := 1.0 / 60.0
	var iters := 20
	var limit := 0.0012
	var damp := 0.98
	var speed := 15.0
	var settle := 60
	var sag := 8.0
	var gap := 30.0
	var mcar := 3.0
	var car := -12.0
	var car_y := 0.0
	var step_i := 0
	var total := 0
	var reason := ""
	var strain := PackedFloat64Array()

	func _init(lv: Dictionary, beams: Array, mass_scale := 1.0) -> void:
		var ph: Dictionary = lv["phys"]
		g = float(ph["g"])
		dt = float(ph["dt"])
		iters = int(ph["iters"])
		limit = float(ph["limit"])
		damp = float(ph["damp"])
		speed = float(ph["speed"])
		settle = int(ph["settle"])
		sag = float(ph["sag"])
		gap = float(lv["gap"])
		mcar = float(lv["car_mass"]) * mass_scale
		for n in lv["nodes"]:
			px.append(float(n[0]))
			py.append(float(n[1]))
			fixed.append(bool(n[2]))
		ox = px.duplicate()
		oy = py.duplicate()
		loads.resize(px.size())
		for b in beams:
			var i := int(b[0])
			var j := int(b[1])
			var dx := px[j] - px[i]
			var dy := py[j] - py[i]
			bl.append([i, j, sqrt(dx * dx + dy * dy), true])
		strain.resize(bl.size())
		for k in bl.size():
			var i2: int = bl[k][0]
			var j2: int = bl[k][1]
			if py[i2] == 0.0 and py[j2] == 0.0 and absf(px[i2] - px[j2]) == 10.0:
				road[minf(px[i2], px[j2])] = k
		total = settle + int((gap + 24.0) / speed / dt) + 1

	## One frame. Returns 1 when the car made it, -1 on failure (see `reason`), 0 running.
	func step() -> int:
		if step_i >= total:
			reason = "timeout"
			return -1
		loads.fill(0.0)
		if step_i >= settle:
			car = car + speed * dt
			if car > 0.0 and car < gap:
				var a := floorf(car / 10.0) * 10.0
				if not road.has(a) or not bool(bl[int(road[a])][3]):
					reason = "fell"
					return -1
				var k: int = road[a]
				var i: int = bl[k][0]
				var j: int = bl[k][1]
				if px[i] > px[j]:
					var tmp := i
					i = j
					j = tmp
				var t := (car - a) / 10.0
				loads[i] = mcar * (1.0 - t)
				loads[j] = mcar * t
				car_y = py[i] + (py[j] - py[i]) * t
				if car_y > sag:
					reason = "sag"
					return -1
			else:
				car_y = 0.0
			if car >= gap + 12.0:
				reason = "ok"
				return 1
		for k in px.size():
			if fixed[k]:
				continue
			var vx := (px[k] - ox[k]) * damp
			var vy := (py[k] - oy[k]) * damp
			ox[k] = px[k]
			oy[k] = py[k]
			px[k] = px[k] + vx
			py[k] = py[k] + vy + g * (1.0 + loads[k]) * dt * dt
		for _it in iters:
			for b in bl:
				if not bool(b[3]):
					continue
				var i: int = b[0]
				var j: int = b[1]
				var rest: float = b[2]
				var dx := px[j] - px[i]
				var dy := py[j] - py[i]
				var d := sqrt(dx * dx + dy * dy)
				if d < 1e-9:
					continue
				var diff := (d - rest) / d
				var fi := fixed[i]
				var fj := fixed[j]
				if fi and fj:
					continue
				if fi:
					px[j] = px[j] - dx * diff
					py[j] = py[j] - dy * diff
				elif fj:
					px[i] = px[i] + dx * diff
					py[i] = py[i] + dy * diff
				else:
					px[i] = px[i] + dx * diff * 0.5
					py[i] = py[i] + dy * diff * 0.5
					px[j] = px[j] - dx * diff * 0.5
					py[j] = py[j] - dy * diff * 0.5
		for k in bl.size():
			var b2: Array = bl[k]
			if not bool(b2[3]):
				continue
			var i3: int = b2[0]
			var j3: int = b2[1]
			var dx2 := px[j3] - px[i3]
			var dy2 := py[j3] - py[i3]
			var s := (sqrt(dx2 * dx2 + dy2 * dy2) - float(b2[2])) / float(b2[2])
			if s < 0.0:
				s = -s
			strain[k] = s
			if s > limit:
				b2[3] = false
		step_i += 1
		return 0


## Whole run without drawing (test runner): 1 = crossed, -1 = failed.
static func run(lv: Dictionary, beams: Array, mass_scale := 1.0) -> int:
	var s := BridgeSim.new(lv, beams, mass_scale)
	var st := 0
	while st == 0:
		st = s.step()
	return st


static func beam_cost(lv: Dictionary, i: int, j: int) -> int:
	var a: Array = lv["nodes"][i]
	var b: Array = lv["nodes"][j]
	return 10 if (float(a[0]) == float(b[0]) or float(a[1]) == float(b[1])) else 14


static func valid_beam(lv: Dictionary, i: int, j: int) -> bool:
	var a: Array = lv["nodes"][i]
	var b: Array = lv["nodes"][j]
	var d := Vector2(float(a[0]) - float(b[0]), float(a[1]) - float(b[1])).length()
	return i != j and d <= 14.2 and not (bool(a[2]) and bool(b[2]))


static func stars_for(cost: int, best: int) -> int:
	if cost <= best:
		return 3
	if cost <= ceili(best * 1.3):
		return 2
	return 1


var lv: Dictionary = {}
var beams: Array = []          # [i, j]
var selected := -1
var remove_mode := false
var testing := false
var won := false
var tests := 0
var sim: BridgeSim
var _acc := 0.0
var _frozen := false
var _broken := {}             # beam index -> true once its break was shown
var board: Control
var cost_chip: Label
var goal_chip: Label
var status: Label
var test_btn: Button
var mode_btn: Button
var clear_btn: Button


func _on_start() -> void:
	var v := frame("مهندس الجسور")
	cost_chip = chip("", "coin", Tokens.COIN)
	goal_chip = chip("", "star", Tokens.COIN)
	board = Control.new()
	board.custom_minimum_size = Vector2(0, 600)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	board.draw.connect(_paint)
	board.resized.connect(board.queue_redraw)
	board.gui_input.connect(_on_input)
	v.add_child(board)
	status = UiKit.label("", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status)
	clear_btn = UiKit.icon_button("restart", "امسح", UiKit.Variant.GHOST)
	clear_btn.pressed.connect(_clear)
	mode_btn = UiKit.icon_button("close", "إزالة", UiKit.Variant.SECONDARY, accent)
	mode_btn.pressed.connect(_toggle_mode)
	test_btn = UiKit.icon_button("play", "اختبر", UiKit.Variant.PRIMARY, accent)
	test_btn.pressed.connect(_test)
	v.add_child(action_bar([clear_btn, mode_btn, test_btn]))
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/bridge/levels.json"))
	if not (p is Dictionary) or (p.get("levels", []) as Array).is_empty():
		title_label.text = "تعذّر تحميل المرحلة"
		test_btn.disabled = true
		return
	var all: Array = p["levels"]
	lv = all[clampi(level_id - 1, 0, all.size() - 1)]
	title_label.text = "مهندس الجسور · %s" % lv["name"]
	_say("اضغط نقطة ثم نقطة مجاورة لتضع عارضة. العوارض على خط الطريق هي سطح الجسر. النقاط الحمراء ثابتة.")
	_update()


func _say(t: String, col := Tokens.TEXT_MUTED) -> void:
	status.text = t
	status.add_theme_color_override("font_color", col)


func cost() -> int:
	var c := 0
	for b in beams:
		c += beam_cost(lv, int(b[0]), int(b[1]))
	return c


func _update() -> void:
	UiKit.set_chip(cost_chip, "%d / %d" % [cost(), int(lv["budget"])])
	UiKit.set_chip(goal_chip, "3 نجوم: %d" % int(lv["best_cost"]), false)
	mode_btn.text = "بناء" if remove_mode else "إزالة"
	board.queue_redraw()


# ---------- geometry ----------
func _view() -> Array:
	var gap := float(lv["gap"])
	var wmin := Vector2(-16.0, -30.0)
	var wsize := Vector2(gap + 32.0, 66.0)
	var s := minf(board.size.x / wsize.x, board.size.y / wsize.y)
	var o := (board.size - wsize * s) / 2.0 - wmin * s
	return [s, o]


func _px(x: float, y: float) -> Vector2:
	var vw := _view()
	return vw[1] + Vector2(x, y) * float(vw[0])


func _node_at(p: Vector2) -> int:
	var vw := _view()
	var reach := maxf(Tokens.TOUCH_MIN / 2.0, 5.0 * float(vw[0]))
	var best := -1
	var bd := reach
	var nodes: Array = lv["nodes"]
	for i in nodes.size():
		var d := _px(float(nodes[i][0]), float(nodes[i][1])).distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best


func _beam_at(p: Vector2) -> int:
	var nodes: Array = lv["nodes"]
	var best := -1
	var bd := 26.0
	for k in beams.size():
		var a := _px(float(nodes[beams[k][0]][0]), float(nodes[beams[k][0]][1]))
		var b := _px(float(nodes[beams[k][1]][0]), float(nodes[beams[k][1]][1]))
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if q.distance_to(p) < bd:
			bd = q.distance_to(p)
			best = k
	return best


func _has_beam(i: int, j: int) -> int:
	for k in beams.size():
		if (int(beams[k][0]) == i and int(beams[k][1]) == j) or (int(beams[k][0]) == j and int(beams[k][1]) == i):
			return k
	return -1


func _on_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or testing or won or lv.is_empty():
		return
	if remove_mode:
		var k := _beam_at(mb.position)
		if k >= 0:
			beams.remove_at(k)
			Sfx.play("whoosh")
			_update()
		return
	var n := _node_at(mb.position)
	if n < 0:
		selected = -1
		board.queue_redraw()
		return
	if selected < 0 or selected == n:
		selected = -1 if selected == n else n
		Sfx.play("tap")
		board.queue_redraw()
		return
	if not valid_beam(lv, selected, n):
		_say("العارضة تصل بين نقطتين متجاورتين فقط (أفقيًا أو رأسيًا أو قطريًا)، ولا تصل بين نقطتين ثابتتين.", Tokens.ERROR)
		Sfx.play("wrong")
		selected = n
		board.queue_redraw()
		return
	if _has_beam(selected, n) >= 0:
		selected = n
		board.queue_redraw()
		return
	if cost() + beam_cost(lv, selected, n) > int(lv["budget"]):
		_say("تجاوزت الميزانية. أزل عارضة أو اختر طريقًا أرخص.", Tokens.ERROR)
		Sfx.play("wrong")
		Motion.shake(board)
		return
	beams.append([selected, n])
	selected = n   # keep building from the last joint
	Sfx.play("pop")
	Settings.vibrate(8)
	_say("التكلفة: أفقي ورأسي 10، قطري 14.")
	_update()


func _toggle_mode() -> void:
	if testing or won:
		return
	remove_mode = not remove_mode
	selected = -1
	_say("اضغط عارضة لإزالتها." if remove_mode else "اضغط نقطة ثم نقطة مجاورة لتضع عارضة.")
	_update()


func _clear() -> void:
	if won:
		return
	testing = false
	_frozen = false
	sim = null
	test_btn.text = "اختبر"
	beams.clear()
	selected = -1
	Sfx.play("whoosh")
	_update()


func _test() -> void:
	if won or lv.is_empty():
		return
	if testing:   # second press: back to building
		testing = false
		_frozen = false
		sim = null
		test_btn.text = "اختبر"
		_say("عدّل الجسر ثم اختبر مجددًا.")
		board.queue_redraw()
		return
	sim = BridgeSim.new(lv, beams)
	_broken.clear()
	testing = true
	tests += 1
	selected = -1
	_acc = 0.0
	test_btn.text = "عودة للبناء"
	_say("السيارة تعبر...")
	Sfx.play("whoosh")


func _process(delta: float) -> void:
	if not testing or sim == null or won or _frozen:
		return
	_acc += delta
	var n := 0
	var st := 0
	while _acc >= sim.dt and n < 4 and st == 0:
		_acc -= sim.dt
		n += 1
		st = sim.step()
	# new breaks: sparks at the beam and a short shake
	var fresh := false
	for k in sim.bl.size():
		if not bool(sim.bl[k][3]) and not _broken.has(k):
			_broken[k] = true
			fresh = true
			var i: int = sim.bl[k][0]
			var j: int = sim.bl[k][1]
			UiKit.burst(board, (_px(sim.px[i], sim.py[i]) + _px(sim.px[j], sim.py[j])) / 2.0, Tokens.ERROR, 18)
	if fresh:
		Motion.shake(board, 8.0)
		Sfx.play("pop", 0.6)
	board.queue_redraw()
	if st > 0:
		_win()
	elif st < 0:
		var why := "انكسر الجسر وسقطت السيارة." if sim.reason == "fell" else ("الجسر هبط كثيرًا تحت السيارة." if sim.reason == "sag" else "لم تصل السيارة.")
		_say(why + " اضغط «عودة للبناء» وقوِّ الجسر.", Tokens.ERROR)
		Sfx.play("wrong")
		Settings.vibrate(30)
		_frozen = true   # keep the wreck on screen until «عودة للبناء»


func _win() -> void:
	won = true
	testing = false
	var c := cost()
	var stars := stars_for(c, int(lv["best_cost"]))
	Sfx.play("win")
	UiKit.burst(board, _px(float(lv["gap"]) + 8.0, -4.0), Tokens.SUCCESS, 80)
	UiKit.ring(board, _px(float(lv["gap"]) + 8.0, -4.0), Tokens.SUCCESS, 90.0)
	_say("عبرت السيارة!", Tokens.SUCCESS)
	await wait(Motion.NEXT_BUTTON_MAX_DELAY)
	finish(stars, maxi(100, 1200 - (c - int(lv["best_cost"])) * 5 - (tests - 1) * 30), "عبرت السيارة بجسر تكلفته %d (هدف 3 نجوم: %d) بعد %d اختبار" % [c, int(lv["best_cost"]), tests])


# ---------- drawing ----------
func _paint() -> void:
	if board.size.x < 60.0 or board.size.y < 60.0 or lv.is_empty():
		return
	var gap := float(lv["gap"])
	var vw := _view()
	var s: float = vw[0]
	# cliffs and the gap
	board.draw_rect(Rect2(_px(-16.0, 0.0), Vector2(16.0, 36.0) * s), Tokens.COIN.darkened(0.6))
	board.draw_rect(Rect2(_px(gap, 0.0), Vector2(16.0, 36.0) * s), Tokens.COIN.darkened(0.6))
	board.draw_rect(Rect2(_px(0.0, 30.0), Vector2(gap, 6.0) * s), Color(accent, 0.25))
	var nodes: Array = lv["nodes"]
	var live := sim != null and (testing or won)
	# beams
	for k in beams.size():
		var i := int(beams[k][0])
		var j := int(beams[k][1])
		var a := _px(sim.px[i], sim.py[i]) if live else _px(float(nodes[i][0]), float(nodes[i][1]))
		var b := _px(sim.px[j], sim.py[j]) if live else _px(float(nodes[j][0]), float(nodes[j][1]))
		var is_road := float(nodes[i][1]) == 0.0 and float(nodes[j][1]) == 0.0
		var col := Tokens.COIN if is_road else Tokens.TEXT
		var width := maxf(4.0, s * (1.4 if is_road else 0.8))
		if live and k < sim.bl.size():
			if not bool(sim.bl[k][3]):
				col = Color(Tokens.ERROR, 0.6)
				width *= 0.6
			else:
				col = col.lerp(Tokens.ERROR, clampf(sim.strain[k] / sim.limit, 0.0, 1.0))
		board.draw_line(a, b, col, width, true)
		if is_road and (not live or bool(sim.bl[k][3])):
			var nrm := (b - a).orthogonal().normalized() * width * 0.5
			for t in 4:
				var q := a.lerp(b, (t + 0.5) / 4.0)
				board.draw_line(q - nrm, q + nrm, col.darkened(0.35), 2.0)
	# joints
	if not live:
		for i in nodes.size():
			var p := _px(float(nodes[i][0]), float(nodes[i][1]))
			var fixed := bool(nodes[i][2])
			var r := maxf(5.0, s * 0.9)
			if i == selected:
				board.draw_circle(p, r * 2.2, Color(accent, 0.35))
			board.draw_circle(p, r, Tokens.ERROR if fixed else Color(Tokens.TEXT_MUTED, 0.7))
	# car
	if live:
		var cx := clampf(sim.car, -14.0, gap + 14.0)
		var cp := _px(cx, sim.car_y)
		var cw := 9.0 * s
		var ch := 4.0 * s
		board.draw_rect(Rect2(cp - Vector2(cw / 2.0, ch + 2.0 * s), Vector2(cw, ch)), accent)
		board.draw_rect(Rect2(cp - Vector2(cw * 0.2, ch + 4.5 * s), Vector2(cw * 0.45, 2.6 * s)), accent.darkened(0.25))
		var spin := sim.car / 1.3   # wheel radius 1.3 units: rolls without slipping
		for wx in [-cw * 0.3, cw * 0.3]:
			var wc: Vector2 = cp + Vector2(float(wx), -s)
			board.draw_circle(wc, s * 1.3, Tokens.BG)
			board.draw_line(wc - Vector2(cos(spin), sin(spin)) * s * 1.1, wc + Vector2(cos(spin), sin(spin)) * s * 1.1, Tokens.TEXT_MUTED, 2.0)
