extends MiniGame
## Gear factory. Tap an empty peg to cycle: none -> small -> large -> none.
## Rules mirror tools/gears_solver.py exactly (radii, tolerance, jams, loop locks).
## Every shipped level is verified solvable by that solver; min_gears drives the stars.

const RADII := {1: 40.0, 2: 70.0}
const TOL := 6.0
const DESIGN := Vector2(520.0, 560.0)

var defs: Array = []
var lv: Dictionary = {}
var pegs: Array[Vector2] = []
var sizes: Array[int] = []
var gears: Array = []          # GearView or null per peg
var dirs := {}                 # peg -> +1/-1 for driven gears
var speeds := {}               # peg -> angular speed factor
var jam := false
var placed := 0
var taps := 0
var solved := false
var board: Control
var info: Label
var goal_label: Label
var scale_f := 1.0
var offset := Vector2.ZERO


func _on_start() -> void:
	var v := frame("مصنع التروس")
	info = chip()
	goal_label = UiKit.label("", Tokens.FS_BODY, Tokens.TEXT, Tokens.font_bold)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(goal_label)
	board = Control.new()
	board.custom_minimum_size = Vector2(0, 600)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.clip_contents = true
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	v.add_child(board)
	var h := UiKit.hbox(Tokens.SP_S)
	var clear := UiKit.icon_button("close", "إزالة الكل", UiKit.Variant.GHOST)
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(_clear)
	h.add_child(clear)
	v.add_child(h)
	v.add_child(UiKit.label("اضغط النقطة الفارغة: ترس صغير، ثم كبير، ثم إزالة. كل ترس يعكس الاتجاه.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/build/gears_levels.json"))
	if parsed is Dictionary:
		defs = parsed["levels"]
	await get_tree().process_frame
	_load_level(level_id)


func _load_level(id: int) -> void:
	lv = defs[clampi(id - 1, 0, defs.size() - 1)]
	pegs.clear()
	sizes.clear()
	for p in lv["pegs"]:
		pegs.append(Vector2(float(p[0]), float(p[1])))
		sizes.append(0)
	sizes[int(lv["motor"])] = int(lv["motor_size"])
	sizes[int(lv["output"])] = int(lv["output_size"])
	placed = 0
	taps = 0
	solved = false
	scale_f = minf(board.size.x / DESIGN.x, board.size.y / DESIGN.y)
	offset = (board.size - DESIGN * scale_f) / 2.0
	var want := "مع عقارب الساعة" if int(lv["required_dir"]) == 1 else "عكس عقارب الساعة"
	goal_label.text = "%s: أدِر الآلة الذهبية %s" % [lv["name"], want]
	_rebuild()


func _to_screen(p: Vector2) -> Vector2:
	return offset + p * scale_f


func _rebuild() -> void:
	for c in board.get_children():
		c.queue_free()
	gears = []
	for i in pegs.size():
		var pos := _to_screen(pegs[i])
		var is_fixed := i == int(lv["motor"]) or i == int(lv["output"])
		if not is_fixed:
			var hit := Button.new()
			hit.flat = true
			hit.focus_mode = Control.FOCUS_NONE
			hit.size = Vector2(Tokens.TOUCH_MIN, Tokens.TOUCH_MIN)
			hit.position = pos - hit.size / 2.0
			var idx := i
			hit.pressed.connect(func(): _cycle(idx))
			var dot := Panel.new()
			var st := StyleBoxFlat.new()
			st.bg_color = Tokens.LINE
			st.set_corner_radius_all(12)
			dot.add_theme_stylebox_override("panel", st)
			dot.size = Vector2(24, 24)
			dot.position = hit.size / 2.0 - dot.size / 2.0
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hit.add_child(dot)
			board.add_child(hit)
		if sizes[i] > 0:
			var gv := GearView.new()
			var col := accent
			if i == int(lv["motor"]):
				col = Tokens.TEXT
			elif i == int(lv["output"]):
				col = Tokens.COIN
			gv.setup(RADII[sizes[i]] * scale_f, col, is_fixed)
			gv.position = pos - gv.size / 2.0
			board.add_child(gv)
			gears.append(gv)
		else:
			gears.append(null)
	_simulate()
	_update_info()


func _cycle(i: int) -> void:
	if solved:
		return
	sizes[i] = (sizes[i] + 1) % 3
	taps += 1
	Sfx.play("pop" if sizes[i] > 0 else "tap", 1.0 if sizes[i] != 2 else 0.85)
	Settings.vibrate(10)
	_rebuild()
	if gears[i] != null:
		Motion.pop_in(gears[i])
	_check()


func _clear() -> void:
	for i in sizes.size():
		if i != int(lv["motor"]) and i != int(lv["output"]):
			sizes[i] = 0
	Sfx.play("whoosh")
	_rebuild()


func _r(i: int) -> float:
	return RADII.get(sizes[i], 0.0)


## Same algorithm as tools/gears_solver.py simulate().
func _simulate() -> void:
	dirs.clear()
	speeds.clear()
	jam = false
	placed = 0
	for i in sizes.size():
		if sizes[i] > 0 and i != int(lv["motor"]) and i != int(lv["output"]):
			placed += 1
	for i in pegs.size():
		for j in range(i + 1, pegs.size()):
			if sizes[i] > 0 and sizes[j] > 0 and pegs[i].distance_to(pegs[j]) < _r(i) + _r(j) - TOL:
				jam = true
	if jam:
		_mark_jam()
		return
	var m := int(lv["motor"])
	dirs[m] = 1
	speeds[m] = 1.0
	var queue: Array[int] = [m]
	while not queue.is_empty():
		var a: int = queue.pop_front()
		for b in pegs.size():
			if b == a or sizes[b] == 0:
				continue
			if absf(pegs[a].distance_to(pegs[b]) - (_r(a) + _r(b))) <= TOL:
				var want: int = -int(dirs[a])
				if dirs.has(b):
					if int(dirs[b]) != want:
						jam = true
						_mark_jam()
						return
				else:
					dirs[b] = want
					speeds[b] = float(speeds[a]) * _r(a) / _r(b)
					queue.append(b)
	_mark_jam()


func _mark_jam() -> void:
	for i in gears.size():
		if gears[i] != null:
			gears[i].jammed = jam
			gears[i].queue_redraw()


func _check() -> void:
	var o := int(lv["output"])
	if jam:
		Sfx.play("wrong")
		goal_label.add_theme_color_override("font_color", Tokens.ERROR)
		return
	goal_label.add_theme_color_override("font_color", Tokens.TEXT)
	if dirs.has(o) and int(dirs[o]) == int(lv["required_dir"]):
		solved = true
		_celebrate()


func _celebrate() -> void:
	Sfx.play("win")
	Settings.vibrate(30)
	var o := int(lv["output"])
	UiKit.burst(board, _to_screen(pegs[o]), Tokens.COIN, 80)
	var min_g := int(lv.get("min_gears", placed))
	var stars := 3 if placed <= min_g else (2 if placed <= min_g + 1 else 1)
	await wait(1.4)
	finish(stars, maxi(100, 1000 - taps * 15), "%d تروس (الأقل %d)" % [placed, min_g])


func _process(delta: float) -> void:
	if jam or gears.is_empty():
		return
	var spin := 1.6 if not solved else 3.2
	for i in gears.size():
		if gears[i] != null and dirs.has(i):
			gears[i].angle += float(dirs[i]) * float(speeds[i]) * spin * delta
			gears[i].queue_redraw()


func _update_info() -> void:
	UiKit.set_chip(info, "تروس %d" % [placed])
