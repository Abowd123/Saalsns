extends MiniGame
## Physics lab: set up the lab (drop point, ramp angles, peg positions), then launch the
## ball. Gravity and bounces must carry it into the basket. 6 different challenges
## (content/physics_lab/levels.json): drop point, one ramp, two ramps, a movable peg, a
## bouncy board, and a machine that combines them.
## The simulation (class Sim) uses only + - * / and sqrt on 64-bit floats, in the same
## order as tools/physics_lab_gen.py, which simulates every combination of every level.
## Stars by launches: the lab is free to change between launches.

## Deterministic ball simulation shared by the game and the test runner.
class Sim:
	var segs: Array = []      # [ax, ay, bx, by, e]
	var pegs: Array = []      # [cx, cy, r]
	var bx := 0.0
	var by := 0.0
	var vx := 0.0
	var vy := 0.0
	var r := 3.2
	var g := 160.0
	var dt := 1.0 / 120.0
	var friction := 0.998
	var win_time := 0.25
	var basket := [0.0, 0.0, 1.0, 1.0]
	var floor_y := 150.0
	var inside := 0.0
	var steps := 0
	var max_steps := 1200

	func _init(data: Dictionary, lv: Dictionary, choice: Dictionary, dx := 0.0, gs := 1.0) -> void:
		r = float(data["ball_r"])
		g = float(data["gravity"]) * gs
		dt = float(data["dt"])
		friction = float(data["friction"])
		win_time = float(data["win_time"])
		max_steps = int(data["steps"])
		var w := float(data["world"][0])
		var h := float(data["world"][1])
		floor_y = h + 10.0
		var en := float(data["e_normal"])
		segs.append([0.0, -40.0, 0.0, h, en])
		segs.append([w, -40.0, w, h, en])
		for s in lv["static"]:
			segs.append([float(s[0]), float(s[1]), float(s[2]), float(s[3]), en])
		var ramps: Array = lv["ramps"]
		for i in ramps.size():
			var o: Array = ramps[i]["options"][int(choice["ramps"][i])]
			var e := float(data["e_bouncy"]) if bool(ramps[i].get("bouncy", false)) else en
			segs.append([float(o[0]), float(o[1]), float(o[2]), float(o[3]), e])
		var b: Array = lv["basket"]
		basket = [float(b[0]), float(b[1]), float(b[2]), float(b[3])]
		var x0: float = basket[0]
		var y0: float = basket[1]
		var bw: float = basket[2]
		var bh: float = basket[3]
		segs.append([x0, y0, x0, y0 + bh, en])
		segs.append([x0, y0 + bh, x0 + bw, y0 + bh, 0.1])
		segs.append([x0 + bw, y0 + bh, x0 + bw, y0, en])
		var pl: Array = lv["pegs"]
		for i in pl.size():
			var po: Array = pl[i]["options"][int(choice["pegs"][i])]
			pegs.append([float(po[0]), float(po[1]), float(pl[i]["r"])])
		bx = float(lv["drops"][int(choice["drop"])]) + dx
		by = 6.0

	func _seg(s: Array) -> void:
		var ax: float = s[0]
		var ay: float = s[1]
		var dx: float = s[2] - ax
		var dy: float = s[3] - ay
		var l2 := dx * dx + dy * dy
		var t := ((bx - ax) * dx + (by - ay) * dy) / l2
		if t < 0.0:
			t = 0.0
		if t > 1.0:
			t = 1.0
		var qx := ax + t * dx
		var qy := ay + t * dy
		var nx := bx - qx
		var ny := by - qy
		var d2 := nx * nx + ny * ny
		if d2 >= r * r or d2 < 1e-12:
			return
		var d := sqrt(d2)
		nx = nx / d
		ny = ny / d
		bx = qx + nx * r
		by = qy + ny * r
		var vn := vx * nx + vy * ny
		if vn < 0.0:
			var e: float = s[4]
			vx = vx - (1.0 + e) * vn * nx
			vy = vy - (1.0 + e) * vn * ny
		vx = vx * friction
		vy = vy * friction

	func _peg(p: Array) -> void:
		var cx: float = p[0]
		var cy: float = p[1]
		var nx := bx - cx
		var ny := by - cy
		var d2 := nx * nx + ny * ny
		var rr: float = p[2] + r
		if d2 >= rr * rr or d2 < 1e-12:
			return
		var d := sqrt(d2)
		nx = nx / d
		ny = ny / d
		bx = cx + nx * rr
		by = cy + ny * rr
		var vn := vx * nx + vy * ny
		if vn < 0.0:
			vx = vx - (1.0 + 0.5) * vn * nx
			vy = vy - (1.0 + 0.5) * vn * ny

	## One fixed step. Returns 1 won, -1 lost, 0 still running.
	func step() -> int:
		vy = vy + g * dt
		bx = bx + vx * dt
		by = by + vy * dt
		for s in segs:
			_seg(s)
		for p in pegs:
			_peg(p)
		steps += 1
		var x0: float = basket[0]
		var y0: float = basket[1]
		if bx > x0 and bx < x0 + basket[2] and by > y0 and by < y0 + basket[3]:
			inside = inside + dt
			if inside >= win_time:
				return 1
		else:
			inside = 0.0
		if by > floor_y or steps >= max_steps:
			return -1
		return 0


## Runs to the end without drawing (test runner).
static func run(data: Dictionary, lv: Dictionary, choice: Dictionary) -> int:
	var s := Sim.new(data, lv, choice)
	while true:
		var st: int = s.step()
		if st != 0:
			return st
	return -1


var data: Dictionary = {}
var lv: Dictionary = {}
var choice := {"drop": 0, "ramps": [], "pegs": []}
var sim: Sim
var flying := false
var won := false
var launches := 0
var trail := PackedVector2Array()
var _acc := 0.0
var arena: Control
var launch_btn: Button
var info: Label
var status: Label


func _on_start() -> void:
	var v := frame("مختبر الفيزياء")
	info = chip("", "play", Tokens.COIN)
	arena = Control.new()
	arena.custom_minimum_size = Vector2(0, 640)
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.layout_direction = Control.LAYOUT_DIRECTION_LTR
	arena.draw.connect(_paint)
	arena.resized.connect(arena.queue_redraw)
	arena.gui_input.connect(_on_input)
	v.add_child(arena)
	status = UiKit.label("", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status)
	var reset := UiKit.icon_button("restart", "أعد الكرة", UiKit.Variant.GHOST)
	reset.pressed.connect(_reset)
	launch_btn = UiKit.icon_button("play", "أطلق الكرة", UiKit.Variant.PRIMARY, accent)
	launch_btn.pressed.connect(_launch)
	v.add_child(action_bar([reset, launch_btn]))
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/physics_lab/levels.json"))
	if not (p is Dictionary) or (p.get("levels", []) as Array).is_empty():
		title_label.text = "تعذّر تحميل المرحلة"
		launch_btn.disabled = true
		return
	data = p
	var all: Array = p["levels"]
	lv = all[clampi(level_id - 1, 0, all.size() - 1)]
	title_label.text = "مختبر الفيزياء · %s" % lv["name"]
	choice = start_choice(lv)
	status.text = str(lv["help"]) + " " + _controls_text()
	_update()


func _controls_text() -> String:
	var parts: Array[String] = []
	if (lv["drops"] as Array).size() > 1:
		parts.append("اضغط سهمًا أحمر لتختار مكان الإسقاط")
	if not (lv["ramps"] as Array).is_empty():
		parts.append("اضغط منتصف المنحدر لتديره")
	if not (lv["pegs"] as Array).is_empty():
		parts.append("اضغط نقطة خضراء لتنقل المرتكز إليها")
	return "، ".join(PackedStringArray(parts)) + "."


static func start_choice(p_lv: Dictionary) -> Dictionary:
	var c := {"drop": 0, "ramps": [], "pegs": []}
	for rp in p_lv["ramps"]:
		c["ramps"].append(int(rp["start"]))
	for pg in p_lv["pegs"]:
		c["pegs"].append(int(pg["start"]))
	return c


func _update() -> void:
	UiKit.set_chip(info, "%d إطلاق" % launches)
	arena.queue_redraw()


# ---------- geometry ----------
func _scale() -> float:
	return minf(arena.size.x / float(data["world"][0]), arena.size.y / float(data["world"][1]))


func _origin() -> Vector2:
	var s := _scale()
	return ((arena.size - Vector2(float(data["world"][0]), float(data["world"][1])) * s) / 2.0).floor()


func _to_px(x: float, y: float) -> Vector2:
	return _origin() + Vector2(x, y) * _scale()


func _on_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or flying or won or lv.is_empty():
		return
	var s := _scale()
	var p := (mb.position - _origin()) / s   # world units
	var reach := maxf(Tokens.TOUCH_MIN / 2.0 / s, 6.0)
	# every tappable thing competes; the nearest one within reach wins
	var best_d := reach
	var best_kind := ""
	var best_a := -1
	var best_b := -1
	var drops: Array = lv["drops"]
	if drops.size() > 1:
		for i in drops.size():
			var d := Vector2(float(drops[i]), 3.0).distance_to(p)
			if d < best_d:
				best_d = d
				best_kind = "drop"
				best_a = i
	var pegs: Array = lv["pegs"]
	for i in pegs.size():
		var opts: Array = pegs[i]["options"]
		for k in opts.size():
			var d2 := Vector2(float(opts[k][0]), float(opts[k][1])).distance_to(p)
			if d2 < best_d:
				best_d = d2
				best_kind = "peg"
				best_a = i
				best_b = k
	var ramps: Array = lv["ramps"]
	for i in ramps.size():
		var o: Array = ramps[i]["options"][0]
		var pivot := Vector2((float(o[0]) + float(o[2])) / 2.0, (float(o[1]) + float(o[3])) / 2.0)
		var d3 := pivot.distance_to(p)
		if d3 < maxf(best_d, 10.0) and (best_kind == "" or d3 < best_d):
			best_d = d3
			best_kind = "ramp"
			best_a = i
	match best_kind:
		"drop":
			choice["drop"] = best_a
		"peg":
			choice["pegs"][best_a] = best_b
		"ramp":
			choice["ramps"][best_a] = (int(choice["ramps"][best_a]) + 1) % (ramps[best_a]["options"] as Array).size()
		_:
			return
	_changed()


func _changed() -> void:
	sim = null
	trail.clear()
	Sfx.play("tap")
	Settings.vibrate(8)
	arena.queue_redraw()


func _reset() -> void:
	if won:
		return
	flying = false
	sim = null
	trail.clear()
	launch_btn.disabled = false
	arena.queue_redraw()


func _launch() -> void:
	if flying or won or lv.is_empty():
		return
	sim = Sim.new(data, lv, choice)
	trail.clear()
	flying = true
	_acc = 0.0
	launches += 1
	launch_btn.disabled = true
	Sfx.play("whoosh")
	UiKit.ring(arena, _to_px(sim.bx, sim.by), Tokens.ERROR, 40.0)
	_update()


func _process(delta: float) -> void:
	if not flying or sim == null:
		return
	_acc += delta
	var n := 0
	while _acc >= sim.dt and n < 8:   # fixed steps: same result as the verified simulation
		_acc -= sim.dt
		n += 1
		var v_before := Vector2(sim.vx, sim.vy)
		var st: int = sim.step()
		# a hard bounce (big change of velocity) gets a small ring at the contact
		if Quality.fancy() and (Vector2(sim.vx, sim.vy) - v_before).length() > 60.0:
			UiKit.ring(arena, _to_px(sim.bx, sim.by), Tokens.TEXT, 26.0)
			Sfx.play("tap", 0.8)
		if Quality.fancy() and sim.steps % 4 == 0:
			trail.append(Vector2(sim.bx, sim.by))
			if trail.size() > 40:
				trail.remove_at(0)
		if st != 0:
			_end_flight(st)
			break
	arena.queue_redraw()


func _end_flight(st: int) -> void:
	flying = false
	if st > 0:
		won = true
		Sfx.play("win")
		UiKit.burst(arena, _to_px(sim.bx, sim.by), Tokens.SUCCESS, 70)
		UiKit.ring(arena, _to_px(sim.bx, sim.by), Tokens.COIN, 90.0)
		var stars := stars_for(launches)
		await wait(Motion.NEXT_BUTTON_MAX_DELAY)
		finish(stars, maxi(100, 1000 - (launches - 1) * 150), "دخلت الكرة السلة بعد %d إطلاق" % launches)
	else:
		Sfx.play("wrong")
		Settings.vibrate(20)
		status.text = "لم تصل الكرة. غيّر الإعداد وأطلق من جديد."
		status.add_theme_color_override("font_color", Tokens.ERROR)
		launch_btn.disabled = false


static func stars_for(p_launches: int) -> int:
	if p_launches <= 2:
		return 3
	if p_launches <= 4:
		return 2
	return 1


# ---------- drawing ----------
func _paint() -> void:
	if arena.size.x < 60.0 or arena.size.y < 60.0 or lv.is_empty():
		return
	var s := _scale()
	var o := _origin()
	var wpx := Vector2(float(data["world"][0]), float(data["world"][1])) * s
	arena.draw_rect(Rect2(o, wpx), Color(Tokens.SURFACE_1, 0.7))
	var lw := maxf(3.0, s * 1.2)
	for st in lv["static"]:
		arena.draw_line(_to_px(float(st[0]), float(st[1])), _to_px(float(st[2]), float(st[3])), Tokens.TEXT_MUTED, lw, true)
	# ramps: faint ghosts of every angle, the chosen one solid, pivot dot
	var ramps: Array = lv["ramps"]
	for i in ramps.size():
		var opts: Array = ramps[i]["options"]
		var bouncy := bool(ramps[i].get("bouncy", false))
		if not flying:
			for op in opts:
				arena.draw_line(_to_px(float(op[0]), float(op[1])), _to_px(float(op[2]), float(op[3])), Color(Tokens.TEXT_MUTED, 0.15), 2.0, true)
		var c: Array = opts[int(choice["ramps"][i])]
		var a := _to_px(float(c[0]), float(c[1]))
		var b := _to_px(float(c[2]), float(c[3]))
		arena.draw_line(a, b, Tokens.COIN if bouncy else accent, lw * 1.4, true)
		if bouncy:
			var mid := (a + b) / 2.0
			var nrm := (b - a).orthogonal().normalized() * lw * 1.2
			for k in 4:
				var q := a.lerp(b, (k + 0.5) / 4.0)
				arena.draw_line(q, q + nrm, Tokens.COIN.darkened(0.3), 2.0)
			arena.draw_circle(mid, lw * 1.6, Tokens.COIN.darkened(0.4))
		else:
			arena.draw_circle((a + b) / 2.0, lw * 1.6, Tokens.BG)
			arena.draw_arc((a + b) / 2.0, lw * 1.6, 0, TAU, 16, accent, 2.0, true)
	# pegs and their slots
	var pegs: Array = lv["pegs"]
	for i in pegs.size():
		var opts2: Array = pegs[i]["options"]
		if not flying:
			for op in opts2:
				arena.draw_circle(_to_px(float(op[0]), float(op[1])), maxf(5.0, s * 1.4), Color(Tokens.SUCCESS, 0.35))
		var pc: Array = opts2[int(choice["pegs"][i])]
		arena.draw_circle(_to_px(float(pc[0]), float(pc[1])), float(pegs[i]["r"]) * s, Tokens.SUCCESS)
		arena.draw_circle(_to_px(float(pc[0]), float(pc[1])), float(pegs[i]["r"]) * s * 0.4, Tokens.BG)
	# basket
	var bk: Array = lv["basket"]
	var x0 := float(bk[0])
	var y0 := float(bk[1])
	var bw := float(bk[2])
	var bh := float(bk[3])
	var glow := 0.15
	if sim != null and sim.inside > 0.0:
		glow = 0.15 + 0.45 * clampf(sim.inside / sim.win_time, 0.0, 1.0)
	arena.draw_rect(Rect2(_to_px(x0, y0), Vector2(bw, bh) * s), Color(Tokens.COIN, glow))
	arena.draw_polyline(PackedVector2Array([_to_px(x0, y0), _to_px(x0, y0 + bh), _to_px(x0 + bw, y0 + bh), _to_px(x0 + bw, y0)]), Tokens.COIN, lw * 1.2, true)
	# drop markers
	var drops: Array = lv["drops"]
	for i in drops.size():
		var dp := _to_px(float(drops[i]), 3.0)
		var on := i == int(choice["drop"])
		var col := Tokens.ERROR if on else Color(Tokens.ERROR, 0.35)
		var sz := maxf(10.0, s * 3.0)
		arena.draw_colored_polygon(PackedVector2Array([dp + Vector2(-sz, -sz * 0.6), dp + Vector2(sz, -sz * 0.6), dp + Vector2(0, sz * 0.8)]), col)
	# trail + ball
	for k in trail.size():
		arena.draw_circle(_to_px(trail[k].x, trail[k].y), float(data["ball_r"]) * s * 0.5 * (k + 1) / trail.size(), Color(Tokens.TEXT, 0.25))
	var ball := _to_px(sim.bx, sim.by) if sim != null else _to_px(float(drops[int(choice["drop"])]), 6.0)
	var br := float(data["ball_r"]) * s
	arena.draw_circle(ball + Vector2(1, 3), br, Color(0, 0, 0, 0.3))
	arena.draw_circle(ball, br, Tokens.TEXT)
	arena.draw_circle(ball - Vector2(br, br) * 0.3, br * 0.35, Color(1, 1, 1, 0.7))
