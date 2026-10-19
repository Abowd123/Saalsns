extends MiniGame
## Pipes and current: tap a tile to rotate it 90°. Connect the green source to the gold target.
## Levels come from tools/pipes_gen.py: a guaranteed path, a scrambled start, and `par`
## (rotations needed for the reference solution). Connectivity is a flood fill.

## Base tile shapes as open directions. Rotation r turns (x, y) -> (-y, x) r times.
const SHAPES := {
	0: [Vector2i(0, -1), Vector2i(0, 1)],
	1: [Vector2i(-1, 0), Vector2i(1, 0)],
	2: [Vector2i(0, -1), Vector2i(1, 0)],
	3: [Vector2i(1, 0), Vector2i(0, 1)],
	4: [Vector2i(0, 1), Vector2i(-1, 0)],
	5: [Vector2i(-1, 0), Vector2i(0, -1)],
}

var defs: Array = []
var lv: Dictionary = {}
var size_n := 4
var layout: Array = []
var rotations: Array = []
var source := Vector2i.ZERO
var target := Vector2i.ZERO
var flow := {}
var board: Control
var info: Label
var par_chip: Label
var vis_angle := {}     # tile -> visual rotation lag (radians), animates to 0
var _time := 0.0
var _tile_style: StyleBoxFlat
var moves := 0
var hints := 0
var solved := false


func _on_start() -> void:
	var v := frame("الأنابيب والتيار")
	info = chip("", "restart")
	par_chip = chip("", "star", Tokens.COIN)
	board = Control.new()
	board.custom_minimum_size = Vector2(0, 620)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	board.draw.connect(_paint)
	board.resized.connect(board.queue_redraw)
	board.gui_input.connect(_on_board_input)
	v.add_child(board)
	var r := UiKit.icon_button("restart", "إعادة", UiKit.Variant.GHOST)
	r.pressed.connect(_restart)
	var n := UiKit.icon_button("hint", "تلميح", UiKit.Variant.SECONDARY, accent)
	n.pressed.connect(_hint)
	v.add_child(action_bar([r, n]))
	v.add_child(UiKit.label("اضغط القطعة لتدويرها. أوصل التيار من الدائرة الخضراء إلى الدائرة الذهبية. التلميح يخفض النجوم إلى نجمتين.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	_tile_style = StyleBoxFlat.new()
	_tile_style.set_corner_radius_all(14)
	_tile_style.border_width_top = 2
	_tile_style.border_width_bottom = 3
	_tile_style.anti_aliasing = true
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/pipes/levels.json"))
	if p is Dictionary:
		defs = p["levels"]
	if defs.is_empty():
		info.text = "تعذّر تحميل المراحل"
		return
	_load_level(level_id)


func _load_level(id: int) -> void:
	lv = defs[clampi(id - 1, 0, defs.size() - 1)]
	size_n = int(lv["size"])
	layout = lv["layout"]
	source = Vector2i(int(lv["source"][0]), int(lv["source"][1]))
	target = Vector2i(int(lv["target"][0]), int(lv["target"][1]))
	rotations = []
	for y in size_n:
		var row := []
		for x in size_n:
			row.append(int(lv["start"][y][x]))
		rotations.append(row)
	moves = 0
	hints = 0
	solved = false
	_refresh()


func _shape(p: Vector2i) -> Array:
	var out := []
	for d in SHAPES.get(int(layout[p.y][p.x]), []):
		var q: Vector2i = d
		for i in int(rotations[p.y][p.x]):
			q = Vector2i(-q.y, q.x)
		out.append(q)
	return out


func _inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < size_n and p.y < size_n


func _connected() -> Dictionary:
	var seen := {source: 0}   # tile -> distance from the source (drives the flow pulse)
	var q: Array[Vector2i] = [source]
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		for d in _shape(p):
			var n: Vector2i = p + d
			if _inside(n) and not seen.has(n) and (-d) in _shape(n):
				seen[n] = int(seen[p]) + 1
				q.append(n)
	return seen


func _refresh() -> void:
	flow = _connected()
	UiKit.set_chip(info, "%d" % moves)
	UiKit.set_chip(par_chip, "الأفضل %d" % int(lv.get("par", 0)), false)
	board.queue_redraw()


func _geom() -> Array:
	var cell := minf((board.size.x - 8.0) / size_n, (board.size.y - 8.0) / size_n)
	var origin := (board.size - Vector2(cell, cell) * size_n) / 2.0
	return [cell, origin]


func _on_board_input(e: InputEvent) -> void:
	# Touch arrives as emulated mouse too; reading only mouse avoids double rotations.
	var pressed: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
	if not pressed or solved or defs.is_empty():
		return
	var g := _geom()
	var cell: float = g[0]
	var rel: Vector2 = (e.position - g[1]) / cell
	var p := Vector2i(floori(rel.x), floori(rel.y))
	if _inside(p):
		_rotate(p)


func _rotate(p: Vector2i) -> void:
	rotations[p.y][p.x] = (int(rotations[p.y][p.x]) + 1) % 4
	moves += 1
	if not Motion.reduce_motion:
		vis_angle[p] = -PI / 2.0
		var tw := create_tween()
		tw.tween_method(func(a: float):
			vis_angle[p] = a
			board.queue_redraw(), -PI / 2.0, 0.0, Motion.FAST * 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("tap")
	Settings.vibrate(8)
	_refresh()
	_check()


func _check() -> void:
	if solved or not flow.has(target):
		return
	solved = true
	Sfx.play("win")
	var g := _geom()
	UiKit.burst(board, g[1] + (Vector2(target) + Vector2(0.5, 0.5)) * float(g[0]), Tokens.SUCCESS, 70)
	var par := int(lv.get("par", moves))
	var stars := 3 if moves <= par + 2 else (2 if moves <= par * 2 + 4 else 1)
	if hints > 0:
		stars = mini(stars, 2)
	await wait(1.0)
	finish(stars, maxi(100, 1000 - maxi(moves - par, 0) * 25 - hints * 100), "وصل التيار في %d تدويرة (الأفضل %d)" % [moves, par])


## Rotates one tile of the reference path toward its solution.
func _hint() -> void:
	if solved or defs.is_empty():
		return
	var sol: Array = lv["solution"]
	for y in size_n:
		for x in size_n:
			var want := int(sol[y][x])
			if want < 0:
				continue
			var p := Vector2i(x, y)
			if not _tile_ok(p, want):
				hints += 1
				Sfx.play("pop")
				_rotate(p)
				return


## A path tile is fine if it already opens the same directions as the solution rotation.
func _tile_ok(p: Vector2i, want: int) -> bool:
	var cur := int(rotations[p.y][p.x])
	rotations[p.y][p.x] = want
	var need := _shape(p)
	rotations[p.y][p.x] = cur
	var have := _shape(p)
	for d in need:
		if not (d in have):
			return false
	return true


func _restart() -> void:
	_load_level(level_id)
	Sfx.play("whoosh")


func _process(delta: float) -> void:
	_time += delta
	if flow.size() > 1 and Quality.fancy():
		board.queue_redraw()   # current pulse runs along the connected pipes


func _paint() -> void:
	if board.size.x < 60.0 or board.size.y < 60.0:
		return   # not laid out yet (first frame): avoid negative sizes
	if defs.is_empty():
		return
	var g := _geom()
	var cell: float = g[0]
	var origin: Vector2 = g[1]
	var w := maxf(cell * 0.2, 8.0)
	for y in size_n:
		for x in size_n:
			var p := Vector2i(x, y)
			var r := Rect2(origin + Vector2(x, y) * cell + Vector2(4, 4), Vector2(cell - 8, cell - 8))
			var lit := flow.has(p)
			_tile_style.bg_color = Tokens.SURFACE_1.lerp(Tokens.SUCCESS, 0.10) if lit else Tokens.SURFACE_1
			_tile_style.border_color = Color(1, 1, 1, 0.06)
			_tile_style.border_color = Tokens.HIGHLIGHT
			board.draw_style_box(_tile_style, r)
			var c := r.get_center()
			var ang := float(vis_angle.get(p, 0.0))
			var col := Tokens.TEXT_MUTED.darkened(0.25)
			if lit:
				var pulse := 0.5 + 0.5 * sin(_time * 5.0 - float(flow[p]) * 0.9)
				col = Tokens.SUCCESS.lerp(Color.WHITE, 0.35 * pulse if not Motion.reduce_motion else 0.0)
			for d in _shape(p):
				var tip: Vector2 = c + Vector2(d).rotated(ang) * (cell / 2.0 - 4.0)
				board.draw_line(c, tip, Color(0, 0, 0, 0.35), w + 7.0, true)
			for d in _shape(p):
				var tip: Vector2 = c + Vector2(d).rotated(ang) * (cell / 2.0 - 4.0)
				board.draw_line(c, tip, col, w, true)
			board.draw_circle(c, w * 0.62, col)
	var sc := origin + (Vector2(source) + Vector2(0.5, 0.5)) * cell
	var tc := origin + (Vector2(target) + Vector2(0.5, 0.5)) * cell
	var glow := 0.5 + 0.5 * sin(_time * 3.0)
	board.draw_circle(sc, cell * 0.24, Color(Tokens.SUCCESS, 0.25))
	board.draw_circle(sc, cell * 0.17, Tokens.SUCCESS)
	var done := flow.has(target)
	board.draw_circle(tc, cell * (0.22 + 0.04 * glow), Color(Tokens.COIN, 0.22))
	board.draw_circle(tc, cell * 0.17, Tokens.SUCCESS if done else Tokens.COIN)
