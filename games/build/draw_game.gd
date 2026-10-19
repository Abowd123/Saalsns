extends MiniGame
## Draw the solution: draw lines with your finger, then release the ball.
## Lines become static ramps (deterministic). Ink is limited. Ball must rest in the goal.
## Each level ships a reference solution; the dev test replays it to prove solvability.

const DESIGN := Vector2(600, 900)
const MIN_SEG := 14.0
const BALL_R := 22.0
const GOAL_HOLD := 0.8
const TIMEOUT := 9.0

var defs: Array = []
var lv: Dictionary = {}
var arena: Control
var world: Node2D
var info: Label
var ink_bar: ProgressBar
var go_btn: Button
var ball: RigidBody2D
var lines_body: StaticBody2D
var current_line: Line2D
var current_pts: PackedVector2Array = PackedVector2Array()
var ink_used := 0.0
var drawing := false
var running := false
var run_time := 0.0
var in_goal_time := 0.0
var attempts := 0
var solved := false
var scale_f := 1.0
var offset := Vector2.ZERO
var goal_rect := Rect2()
var trail: Line2D
var autoplay := false   # set by verifier


func _on_start() -> void:
	var v := frame("ارسم الحل")
	info = chip()
	ink_bar = ProgressBar.new()
	ink_bar.show_percentage = false
	ink_bar.custom_minimum_size = Vector2(0, 12)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Tokens.SURFACE_2
	bgs.set_corner_radius_all(6)
	var fills := StyleBoxFlat.new()
	fills.bg_color = accent
	fills.set_corner_radius_all(6)
	ink_bar.add_theme_stylebox_override("background", bgs)
	ink_bar.add_theme_stylebox_override("fill", fills)
	v.add_child(ink_bar)
	arena = Control.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.custom_minimum_size = Vector2(0, 900)
	arena.clip_contents = true
	arena.layout_direction = Control.LAYOUT_DIRECTION_LTR
	arena.gui_input.connect(_on_input)
	var arena_bg := Panel.new()
	arena_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_bg.add_theme_stylebox_override("panel", UiKit.card_style(Color(Tokens.SURFACE_1, 0.6), Tokens.RADIUS_CARD, 0))
	arena.add_child(arena_bg)
	v.add_child(arena)
	var h := UiKit.hbox(Tokens.SP_S)
	go_btn = UiKit.icon_button("play", "أطلق الكرة", UiKit.Variant.PRIMARY, accent)
	go_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go_btn.pressed.connect(_release)
	var clear := UiKit.icon_button("close", "امسح", UiKit.Variant.GHOST)
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(_clear_lines)
	h.add_child(go_btn)
	h.add_child(clear)
	v.add_child(h)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/build/draw_levels.json"))
	if parsed is Dictionary:
		defs = parsed["levels"]
	lv = defs[clampi(level_id - 1, 0, defs.size() - 1)]
	await get_tree().process_frame
	_build_level()
	if autoplay:
		_play_reference()


func _to_screen(p: Vector2) -> Vector2:
	return offset + p * scale_f


func _build_level() -> void:
	scale_f = minf(arena.size.x / DESIGN.x, arena.size.y / DESIGN.y)
	offset = (arena.size - DESIGN * scale_f) / 2.0
	world = Node2D.new()
	arena.add_child(world)
	for w in lv["walls"]:
		var body := StaticBody2D.new()
		var sz := Vector2(w[2], w[3]) * scale_f
		body.position = _to_screen(Vector2(w[0], w[1])) + sz / 2.0
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = sz
		cs.shape = r
		body.add_child(cs)
		var vis := Polygon2D.new()
		var hs := sz / 2.0
		vis.polygon = PackedVector2Array([-hs, Vector2(hs.x, -hs.y), hs, Vector2(-hs.x, hs.y)])
		vis.color = Tokens.SURFACE_2
		body.add_child(vis)
		world.add_child(body)
	var g: Array = lv["goal"]
	goal_rect = Rect2(_to_screen(Vector2(g[0], g[1])), Vector2(g[2], g[3]) * scale_f)
	_build_goal()
	lines_body = StaticBody2D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 0.4
	pm.bounce = 0.1
	lines_body.physics_material_override = pm
	world.add_child(lines_body)
	_spawn_ball()
	_update_info()


func _build_goal() -> void:
	# basket: floor + two short side walls so the ball can rest
	var r := goal_rect
	var parts := [
		[Rect2(r.position.x, r.end.y - 10, r.size.x, 10)],
		[Rect2(r.position.x, r.position.y + r.size.y * 0.35, 10, r.size.y * 0.65)],
		[Rect2(r.end.x - 10, r.position.y + r.size.y * 0.35, 10, r.size.y * 0.65)],
	]
	for part in parts:
		var rr: Rect2 = part[0]
		var body := StaticBody2D.new()
		body.position = rr.get_center()
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rr.size
		cs.shape = shape
		body.add_child(cs)
		var vis := Polygon2D.new()
		var hs := rr.size / 2.0
		vis.polygon = PackedVector2Array([-hs, Vector2(hs.x, -hs.y), hs, Vector2(-hs.x, hs.y)])
		vis.color = Tokens.COIN
		body.add_child(vis)
		world.add_child(body)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	glow.color = Color(Tokens.COIN, 0.12)
	world.add_child(glow)


func _spawn_ball() -> void:
	if is_instance_valid(ball):
		ball.queue_free()
	ball = RigidBody2D.new()
	ball.freeze = true
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var pm := PhysicsMaterial.new()
	pm.friction = 0.5
	pm.bounce = 0.25
	ball.physics_material_override = pm
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = BALL_R * scale_f
	cs.shape = c
	ball.add_child(cs)
	var vis := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(Vector2(cos(TAU * i / 24.0), sin(TAU * i / 24.0)) * BALL_R * scale_f)
	vis.polygon = pts
	vis.color = Tokens.TEXT
	ball.add_child(vis)
	var dot := Polygon2D.new()
	var dpts := PackedVector2Array()
	for i in 12:
		dpts.append(Vector2(cos(TAU * i / 12.0), sin(TAU * i / 12.0)) * 6.0 * scale_f + Vector2(7, -7) * scale_f)
	dot.polygon = dpts
	dot.color = accent
	ball.add_child(dot)
	var b: Array = lv["ball"]
	ball.position = _to_screen(Vector2(b[0], b[1]))
	if is_instance_valid(trail):
		trail.queue_free()
	trail = Line2D.new()
	trail.width = BALL_R * scale_f * 1.4
	var wc := Curve.new()
	wc.add_point(Vector2(0, 0))
	wc.add_point(Vector2(1, 1))
	trail.width_curve = wc
	var grad := Gradient.new()
	grad.set_color(0, Color(accent, 0.0))
	grad.set_color(1, Color(accent, 0.45))
	trail.gradient = grad
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	world.add_child(trail)
	world.add_child(ball)
	running = false
	run_time = 0.0
	in_goal_time = 0.0
	go_btn.disabled = false


# ---------- drawing ----------
func _on_input(event: InputEvent) -> void:
	if running or solved:
		return
	# Touch arrives as emulated mouse too; reading only mouse avoids starting every line twice.
	var is_press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	var is_move: bool = event is InputEventMouseMotion
	if is_press:
		if event.pressed:
			_begin_line(event.position)
		else:
			_end_line()
	elif is_move and drawing:
		_extend_line(event.position)


func _ink_limit() -> float:
	return float(lv["ink"]) * scale_f


func _begin_line(p: Vector2) -> void:
	if ink_used >= _ink_limit():
		Sfx.play("wrong")
		return
	drawing = true
	current_pts = PackedVector2Array([p])
	current_line = Line2D.new()
	current_line.width = 10.0
	current_line.default_color = accent
	current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	current_line.joint_mode = Line2D.LINE_JOINT_ROUND
	current_line.points = current_pts
	world.add_child(current_line)


func _extend_line(p: Vector2) -> void:
	var last := current_pts[current_pts.size() - 1]
	var d := last.distance_to(p)
	if d < MIN_SEG:
		return
	var remaining := _ink_limit() - ink_used
	if remaining <= 0.0:
		_end_line()
		return
	if d > remaining:
		p = last + (p - last).normalized() * remaining
		d = remaining
	current_pts.append(p)
	current_line.points = current_pts
	ink_used += d
	_add_segment(last, p)
	_update_info()


func _add_segment(a: Vector2, b: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = a
	seg.b = b
	cs.shape = seg
	lines_body.add_child(cs)


func _end_line() -> void:
	drawing = false
	if current_pts.size() < 2 and is_instance_valid(current_line):
		current_line.queue_free()


func _clear_lines() -> void:
	if running:
		_spawn_ball()
	for c in lines_body.get_children():
		c.queue_free()
	for c in world.get_children():
		if c is Line2D:
			c.queue_free()
	ink_used = 0.0
	Sfx.play("whoosh")
	_update_info()


# ---------- run ----------
func _release() -> void:
	if solved:
		return
	if running:
		_spawn_ball()
		return
	attempts += 1
	ball.freeze = false
	running = true
	go_btn.text = "أعد الكرة"
	Sfx.play("whoosh")


func _physics_process(delta: float) -> void:
	if not running or solved or not is_instance_valid(ball):
		return
	run_time += delta
	if is_instance_valid(trail) and not Motion.reduce_motion:
		trail.add_point(ball.position)
		while trail.get_point_count() > 16:
			trail.remove_point(0)
	if goal_rect.has_point(ball.position) and ball.linear_velocity.length() < 40.0:
		in_goal_time += delta
		if in_goal_time >= GOAL_HOLD:
			_win()
			return
	else:
		in_goal_time = 0.0
	if ball.position.y > arena.size.y + 80.0 or run_time > TIMEOUT:
		Sfx.play("wrong")
		_spawn_ball()
		go_btn.text = "أطلق الكرة"


func _win() -> void:
	solved = true
	running = false
	Sfx.play("win")
	Settings.vibrate(30)
	UiKit.burst(world, goal_rect.get_center(), Tokens.COIN, 90)
	var used := ink_used / maxf(_ink_limit(), 1.0)
	var stars := 3 if used <= 0.6 and attempts <= 2 else (2 if used <= 0.85 else 1)
	await wait(1.0)
	finish(stars, int(1000.0 * (1.0 - used * 0.5)) - attempts * 20, "استخدمت %d%% من الحبر في %d محاولة" % [int(used * 100.0), attempts])


func _update_info() -> void:
	UiKit.set_chip(info, "محاولات %d" % [attempts])
	ink_bar.value = 100.0 * (1.0 - ink_used / maxf(_ink_limit(), 1.0))


## Verifier: draws the shipped reference solution and releases the ball.
func _play_reference() -> void:
	var sol: Array = lv.get("solution", [])
	if sol.size() < 2:
		return
	_begin_line(_to_screen(Vector2(sol[0][0], sol[0][1])))
	for i in range(1, sol.size()):
		var a := _to_screen(Vector2(sol[i - 1][0], sol[i - 1][1]))
		var b := _to_screen(Vector2(sol[i][0], sol[i][1]))
		var n := int(ceil(a.distance_to(b) / MIN_SEG))
		for k in range(1, n + 1):
			_extend_line(a.lerp(b, float(k) / float(n)))
	_end_line()
	_release()
