extends MiniGame
## Rush hour: slide the cars (each only along its own direction) until the red car can
## leave through the exit on the right of row 3. A move = one slide of one car, any distance.
## Levels come from tools/rush_gen.py, which stores `par` = proven minimum number of moves.

const N := 6
const EXIT_ROW := 2
const PALETTE := [Color("#2CC9B5"), Color("#F5B33D"), Color("#9BDB4D"), Color("#7AA2FF"), Color("#C38BFF"), Color("#FF9F5A"), Color("#5AD1FF"), Color("#E8E2C8")]

var defs: Array = []
var lv: Dictionary = {}
var pos: Array[Vector2i] = []
var lens: Array[int] = []
var horiz: Array[bool] = []
var vis: Array[Vector2] = []     # drawn position (cells), animates toward pos
var history: Array = []
var moves := 0
var solved := false
var board: Control
var moves_chip: Label
var par_chip: Label
var _drag := -1
var _drag_from := Vector2.ZERO
var _drag_cell := Vector2i.ZERO
var _range := Vector2i.ZERO      # min/max allowed along the axis while dragging
var _car_style: StyleBoxFlat


func _on_start() -> void:
	var v := frame("أزمة مرور")
	moves_chip = chip("", "arrow_right")
	par_chip = chip("", "star", Tokens.COIN)
	board = Control.new()
	board.custom_minimum_size = Vector2(0, 640)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	board.clip_contents = true
	board.draw.connect(_paint)
	board.resized.connect(board.queue_redraw)
	board.gui_input.connect(_on_input)
	v.add_child(board)
	var undo := UiKit.icon_button("undo", "تراجع", UiKit.Variant.SECONDARY, accent)
	undo.pressed.connect(_undo)
	var r := UiKit.icon_button("restart", "إعادة", UiKit.Variant.GHOST)
	r.pressed.connect(_restart)
	v.add_child(action_bar([undo, r]))
	v.add_child(UiKit.label("اسحب كل سيارة في اتجاهها فقط. أخرج السيارة الحمراء من المخرج على اليمين.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	_car_style = StyleBoxFlat.new()
	_car_style.set_corner_radius_all(16)
	_car_style.border_width_bottom = 6
	_car_style.anti_aliasing = true
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/rush/levels.json"))
	if p is Dictionary:
		defs = p["levels"]
	if defs.is_empty():
		title_label.text = "تعذّر تحميل المراحل"
		return
	_load_level(level_id)


func _load_level(id: int) -> void:
	lv = defs[clampi(id - 1, 0, defs.size() - 1)]
	title_label.text = "أزمة مرور · %s" % lv["name"]
	pos.clear()
	lens.clear()
	horiz.clear()
	vis.clear()
	for c in lv["cars"]:
		pos.append(Vector2i(int(c["x"]), int(c["y"])))
		lens.append(int(c["len"]))
		horiz.append(bool(c["h"]))
		vis.append(Vector2(int(c["x"]), int(c["y"])))
	history.clear()
	moves = 0
	solved = false
	_drag = -1
	_refresh()


func _refresh() -> void:
	UiKit.set_chip(moves_chip, str(moves))
	UiKit.set_chip(par_chip, "الأقل %d" % int(lv.get("par", 0)), false)
	board.queue_redraw()


func _geom() -> Array:
	var cell := minf((board.size.x - 60.0) / N, (board.size.y - 20.0) / N)
	var origin := Vector2((board.size.x - cell * N) / 2.0 - 16.0, (board.size.y - cell * N) / 2.0)
	return [cell, origin]


func _car_at(c: Vector2i) -> int:
	for i in pos.size():
		var p := pos[i]
		for k in lens[i]:
			if (p + (Vector2i(k, 0) if horiz[i] else Vector2i(0, k))) == c:
				return i
	return -1


func _free(c: Vector2i, ignore: int) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= N or c.y >= N:
		return false
	var o := _car_at(c)
	return o == -1 or o == ignore


## How far car i can slide: [min, max] of its x (horizontal) or y (vertical).
func _slide_range(i: int) -> Vector2i:
	var p := pos[i]
	var step := Vector2i(1, 0) if horiz[i] else Vector2i(0, 1)
	var lo := p
	while _free(lo - step, i):
		lo -= step
	var hi := p
	while _free(hi + step * lens[i], i):
		hi += step
	return Vector2i(lo.x, hi.x) if horiz[i] else Vector2i(lo.y, hi.y)


func _on_input(e: InputEvent) -> void:
	if solved or defs.is_empty():
		return
	var g := _geom()
	var cell: float = g[0]
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			var rel: Vector2 = (e.position - g[1]) / cell
			var i := _car_at(Vector2i(floori(rel.x), floori(rel.y)))
			if i >= 0:
				_drag = i
				_drag_from = e.position
				_drag_cell = pos[i]
				_range = _slide_range(i)
				Sfx.play("tap")
		elif _drag >= 0:
			_release()
	elif e is InputEventMouseMotion and _drag >= 0:
		var d: Vector2 = (e.position - _drag_from) / cell
		var along := d.x if horiz[_drag] else d.y
		var start := float(_drag_cell.x if horiz[_drag] else _drag_cell.y)
		var t := clampf(start + along, float(_range.x), float(_range.y))
		vis[_drag] = Vector2(t, _drag_cell.y) if horiz[_drag] else Vector2(_drag_cell.x, t)
		board.queue_redraw()


func _release() -> void:
	var i := _drag
	_drag = -1
	var t := roundi(vis[i].x if horiz[i] else vis[i].y)
	var np := Vector2i(t, pos[i].y) if horiz[i] else Vector2i(pos[i].x, t)
	if np != pos[i]:
		history.append([i, pos[i]])
		pos[i] = np
		moves += 1
		Sfx.play("pop")
		Settings.vibrate(10)
	_snap(i)
	_refresh()
	if pos[0].x >= N - lens[0]:
		_win()


func _snap(i: int) -> void:
	var target := Vector2(pos[i])
	if Motion.reduce_motion:
		vis[i] = target
		board.queue_redraw()
		return
	var from := vis[i]
	var tw := create_tween()
	tw.tween_method(func(k: float):
		vis[i] = from.lerp(target, k)
		board.queue_redraw(), 0.0, 1.0, Motion.FAST).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _undo() -> void:
	if solved or history.is_empty():
		return
	var h: Array = history.pop_back()
	pos[int(h[0])] = h[1]
	moves -= 1
	_snap(int(h[0]))
	_refresh()
	Sfx.play("whoosh")


func _restart() -> void:
	_load_level(level_id)
	Sfx.play("whoosh")


func _win() -> void:
	solved = true
	Sfx.play("win")
	var tw := create_tween()
	var from := vis[0]
	tw.tween_method(func(k: float):
		vis[0] = from.lerp(Vector2(N + 1, EXIT_ROW), k)
		board.queue_redraw(), 0.0, 1.0, Motion.BASE * 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var g := _geom()
	UiKit.burst(self, board.get_global_rect().position - global_position + g[1] + Vector2(N, EXIT_ROW + 0.5) * float(g[0]), Tokens.SUCCESS, 70)
	var par := int(lv.get("par", moves))
	var stars := 3 if moves <= par else (2 if moves <= par + ceili(par * 0.5) else 1)
	await wait(1.0)
	finish(stars, maxi(100, 1500 - maxi(moves - par, 0) * 30), "خرجت في %d حركة (الأقل %d)" % [moves, par])


func _paint() -> void:
	if board.size.x < 60.0 or board.size.y < 60.0:
		return   # not laid out yet (first frame): avoid negative sizes
	if defs.is_empty():
		return
	var g := _geom()
	var cell: float = g[0]
	var o: Vector2 = g[1]
	var frame_r := Rect2(o - Vector2(10, 10), Vector2(cell * N + 20, cell * N + 20))
	board.draw_rect(frame_r, Tokens.SURFACE_2)
	board.draw_rect(Rect2(o, Vector2(cell * N, cell * N)), Tokens.SURFACE_1)
	for y in N:
		for x in N:
			board.draw_rect(Rect2(o + Vector2(x, y) * cell + Vector2(2, 2), Vector2(cell - 4, cell - 4)), Color(1, 1, 1, 0.025 if (x + y) % 2 == 0 else 0.0))
	# exit gap + arrow
	var ey := o.y + EXIT_ROW * cell
	board.draw_rect(Rect2(Vector2(o.x + cell * N, ey + 4), Vector2(12, cell - 8)), Tokens.BG)
	var ax := o.x + cell * N + 26
	var ac := Vector2(ax, ey + cell / 2.0)
	board.draw_colored_polygon(PackedVector2Array([ac + Vector2(-8, -16), ac + Vector2(14, 0), ac + Vector2(-8, 16)]), Color(Tokens.SUCCESS, 0.8))
	for i in pos.size():
		var sz := Vector2(lens[i], 1) if horiz[i] else Vector2(1, lens[i])
		var r := Rect2(o + vis[i] * cell + Vector2(6, 6), sz * cell - Vector2(12, 12))
		var col: Color = Tokens.ERROR if i == 0 else PALETTE[(i - 1) % PALETTE.size()]
		if i == _drag:
			col = col.lightened(0.15)
		board.draw_rect(Rect2(r.position + Vector2(3, 6), r.size), Color(0, 0, 0, 0.35))
		_car_style.bg_color = col
		_car_style.border_color = col.darkened(0.35)
		board.draw_style_box(_car_style, r)
		# windshield strips
		var wcol := Color(Tokens.BG, 0.55)
		if horiz[i]:
			board.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.62, 10), Vector2(r.size.x * 0.12, r.size.y - 26)), wcol)
			board.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.18, 10), Vector2(r.size.x * 0.08, r.size.y - 26)), wcol)
		else:
			board.draw_rect(Rect2(r.position + Vector2(10, r.size.y * 0.62), Vector2(r.size.x - 20, r.size.y * 0.12)), wcol)
			board.draw_rect(Rect2(r.position + Vector2(10, r.size.y * 0.18), Vector2(r.size.x - 20, r.size.y * 0.08)), wcol)
		board.draw_rect(Rect2(r.position + Vector2(12, 4), Vector2(r.size.x - 24, 4)), Color(1, 1, 1, 0.25))
