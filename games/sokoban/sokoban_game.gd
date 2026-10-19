extends MiniGame
## Sokoban with undo, restart, swipe and a D-pad. Deadlock guard rejects pushes into
## non-goal corners. Every level is proven solvable by tools/sokoban_solver.py, which
## also stores `par` (minimum moves, same rules) used for the stars.

const SWIPE_MIN := 40.0

var levels: Array = []
var rec: Dictionary = {}
var player := Vector2i.ZERO
var boxes: Array[Vector2i] = []
var goals: Array[Vector2i] = []
var walls: Array[Vector2i] = []
var moves := 0
var pushes := 0
var history: Array = []
var board: Control
var info: Label
var level_title: Label
var won := false
var goal_chip: Label
# animation: where things were before the last step (drawn with lerp while anim_t < 1)
var anim_t := 1.0
var from_player := Vector2i.ZERO
var from_boxes: Array[Vector2i] = []
var facing := Vector2i(0, 1)
var bump_dir := Vector2.ZERO
var bump_t := 1.0
var _drag_from := Vector2.ZERO
var _dragging := false


func _on_start() -> void:
	var v := frame("الصناديق")
	level_title = title_label
	info = chip("", "")
	goal_chip = chip("", "check", Tokens.COIN)
	board = Control.new()
	board.custom_minimum_size = Vector2(0, 520)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	board.draw.connect(_paint)
	board.resized.connect(board.queue_redraw)
	board.gui_input.connect(_on_board_input)
	v.add_child(board)
	v.add_child(_dpad())
	var undo := UiKit.icon_button("undo", "تراجع", UiKit.Variant.SECONDARY, accent)
	undo.pressed.connect(_undo)
	var restart := UiKit.icon_button("restart", "إعادة", UiKit.Variant.GHOST)
	restart.pressed.connect(_restart)
	v.add_child(action_bar([undo, restart]))
	var help := UiKit.label("اسحب على الرقعة في اتجاه الحركة أو استخدم الأسهم. ادفع كل صندوق إلى هدف.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/sokoban_levels.json"))
	if parsed is Dictionary:
		levels = parsed["levels"]
	if levels.is_empty():
		level_title.text = "تعذّر تحميل المراحل"
		return
	_load_level(level_id)


## Cross-shaped pad, laid out left-to-right so "يمين" really is on the right.
func _dpad() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.layout_direction = Control.LAYOUT_DIRECTION_LTR
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", Tokens.SP_S)
	grid.add_theme_constant_override("v_separation", Tokens.SP_XS)
	var cells := [["", Vector2i.ZERO], ["arrow_up", Vector2i(0, -1)], ["", Vector2i.ZERO],
		["arrow_left", Vector2i(-1, 0)], ["arrow_down", Vector2i(0, 1)], ["arrow_right", Vector2i(1, 0)]]
	for c in cells:
		if str(c[0]) == "":
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(120, 72)
			grid.add_child(sp)
			continue
		var b := UiKit.icon_button(str(c[0]), "", UiKit.Variant.SECONDARY, accent)
		b.custom_minimum_size = Vector2(120, 72)
		var dir: Vector2i = c[1]
		b.pressed.connect(func(): _move(dir))
		grid.add_child(b)
	return grid


func _load_level(id: int) -> void:
	rec = levels[clampi(id - 1, 0, levels.size() - 1)]
	level_title.text = "الصناديق · %s" % rec["name"]
	anim_t = 1.0
	bump_t = 1.0
	walls.clear()
	goals.clear()
	boxes.clear()
	history.clear()
	moves = 0
	pushes = 0
	won = false
	for y in rec["map"].size():
		var row: String = rec["map"][y]
		for x in row.length():
			var ch := row[x]
			var pos := Vector2i(x, y)
			match ch:
				"#":
					walls.append(pos)
				".":
					goals.append(pos)
				"$":
					boxes.append(pos)
				"*":
					boxes.append(pos)
					goals.append(pos)
				"@":
					player = pos
				"+":
					player = pos
					goals.append(pos)
	_update_info()
	board.queue_redraw()


func _geom() -> Array:
	var min_x := 999
	var max_x := 0
	var min_y := 999
	var max_y := 0
	for p in walls:
		min_x = mini(min_x, p.x)
		max_x = maxi(max_x, p.x)
		min_y = mini(min_y, p.y)
		max_y = maxi(max_y, p.y)
	var cols := max_x - min_x + 1
	var rows := max_y - min_y + 1
	var tile := clampf(minf((board.size.x - 12) / maxf(cols, 1), (board.size.y - 12) / maxf(rows, 1)), 30.0, 96.0)
	var o := Vector2((board.size.x - cols * tile) / 2.0 - min_x * tile, (board.size.y - rows * tile) / 2.0 - min_y * tile)
	return [tile, o]


## Slides the player and any pushed box from their old cells (one quick tween).
func _start_anim(p_from: Vector2i, b_from: Array) -> void:
	from_player = p_from
	from_boxes.assign(b_from)
	if Motion.reduce_motion:
		anim_t = 1.0
		return
	anim_t = 0.0
	var tw := create_tween()
	tw.tween_method(func(t: float):
		anim_t = t
		board.queue_redraw(), 0.0, 1.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Small nudge toward a wall when a move is blocked.
func _bump(dir: Vector2i) -> void:
	if Motion.reduce_motion:
		return
	bump_dir = Vector2(dir)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		bump_t = t
		board.queue_redraw(), 0.0, 1.0, 0.16)


func _paint() -> void:
	if board.size.x < 60.0 or board.size.y < 60.0:
		return   # not laid out yet (first frame): avoid negative sizes
	if levels.is_empty():
		return
	var g := _geom()
	var tile: float = g[0]
	var o: Vector2 = g[1]
	# floor under the playable area
	for y in rec["map"].size():
		var row: String = rec["map"][y]
		for x in row.length():
			if row[x] != "#":
				board.draw_rect(Rect2(o + Vector2(x, y) * tile, Vector2(tile, tile)), Color(Tokens.SURFACE_1, 0.55 if (x + y) % 2 == 0 else 0.4))
	for p in walls:
		var r := Rect2(o + Vector2(p) * tile + Vector2(1, 1), Vector2(tile - 2, tile - 2))
		board.draw_rect(r, Tokens.SURFACE_2)
		board.draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Tokens.LINE.lightened(0.15))
		board.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 5), Vector2(r.size.x, 5)), Color(0, 0, 0, 0.3))
	for p in goals:
		var c := o + (Vector2(p) + Vector2(0.5, 0.5)) * tile
		board.draw_circle(c, tile * 0.3, Color(accent, 0.16))
		board.draw_arc(c, tile * 0.22, 0, TAU, 28, Color(accent, 0.8), 3.0, true)
		board.draw_circle(c, tile * 0.07, Color(accent, 0.8))
	for i in boxes.size():
		var bp := Vector2(boxes[i])
		if anim_t < 1.0 and i < from_boxes.size():
			bp = Vector2(from_boxes[i]).lerp(bp, anim_t)
		var on_goal := boxes[i] in goals
		var col := Tokens.COIN if on_goal else Color("#C9894B")
		var r := Rect2(o + bp * tile + Vector2(5, 5), Vector2(tile - 10, tile - 10))
		board.draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.3))
		board.draw_rect(r, col)
		var dark := col.darkened(0.35)
		board.draw_rect(r, dark, false, 3.0)
		board.draw_line(r.position + Vector2(6, 6), r.end - Vector2(6, 6), dark, 3.0, true)
		board.draw_line(Vector2(r.end.x - 6, r.position.y + 6), Vector2(r.position.x + 6, r.end.y - 6), dark, 3.0, true)
		board.draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), col.lightened(0.25))
	var pp := Vector2(player)
	var squash := 0.0
	if anim_t < 1.0:
		pp = Vector2(from_player).lerp(pp, anim_t)
		squash = sin(anim_t * PI) * 0.12
	if bump_t < 1.0:
		pp += bump_dir * sin(bump_t * PI) * 0.12
	var pc := o + (pp + Vector2(0.5, 0.5)) * tile
	var rad := tile * 0.32
	board.draw_circle(pc + Vector2(2, 5), rad, Color(0, 0, 0, 0.3))
	board.draw_set_transform(pc, 0.0, Vector2(1.0 + squash, 1.0 - squash))
	board.draw_circle(Vector2.ZERO, rad, Tokens.TEXT)
	board.draw_circle(Vector2(-rad * 0.3, -rad * 0.35), rad * 0.28, Color(1, 1, 1, 0.6))
	var look := Vector2(facing) * rad * 0.25
	board.draw_circle(look + Vector2(-rad * 0.32, -rad * 0.1), rad * 0.13, Tokens.BG)
	board.draw_circle(look + Vector2(rad * 0.32, -rad * 0.1), rad * 0.13, Tokens.BG)
	board.draw_set_transform(Vector2.ZERO)


func _on_board_input(e: InputEvent) -> void:
	# Touch arrives as emulated mouse too; reading only mouse avoids double moves.
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_dragging = true
			_drag_from = e.position
		else:
			_dragging = false
	elif e is InputEventMouseMotion and _dragging:
		var d: Vector2 = e.position - _drag_from
		if d.length() >= SWIPE_MIN:
			_dragging = false
			if absf(d.x) > absf(d.y):
				_move(Vector2i(1 if d.x > 0 else -1, 0))
			else:
				_move(Vector2i(0, 1 if d.y > 0 else -1))


func _update_info() -> void:
	var on := 0
	for p in boxes:
		if p in goals:
			on += 1
	UiKit.set_chip(info, "%d حركة" % moves, false)
	UiKit.set_chip(goal_chip, "%d/%d" % [on, goals.size()])


func _move(dir: Vector2i) -> void:
	if won or levels.is_empty():
		return
	facing = dir
	var next := player + dir
	if next in walls:
		_bump(dir)
		return
	var pushed := false
	var old_boxes := boxes.duplicate()
	if next in boxes:
		var beyond := next + dir
		if beyond in walls or beyond in boxes or _deadlocked(beyond):
			_bump(dir)
			Sfx.play("wrong")
			Settings.vibrate(20)
			return
		boxes[boxes.find(next)] = beyond
		pushed = true
	history.append({"player": player, "boxes": old_boxes, "pushed": pushed})
	_start_anim(player, old_boxes)
	player = next
	moves += 1
	if pushed:
		pushes += 1
	Sfx.play("pop" if pushed else "tap")
	Settings.vibrate(10)
	board.queue_redraw()
	_update_info()
	var all_in := true
	for p in boxes:
		if not (p in goals):
			all_in = false
	if all_in:
		_finish_level()


## A box in a corner that is not a goal can never move again.
func _deadlocked(p: Vector2i) -> bool:
	if p in goals:
		return false
	var up := (p + Vector2i(0, -1)) in walls
	var dn := (p + Vector2i(0, 1)) in walls
	var le := (p + Vector2i(-1, 0)) in walls
	var ri := (p + Vector2i(1, 0)) in walls
	return (up or dn) and (le or ri)


func _undo() -> void:
	if history.is_empty() or won:
		return
	var h: Dictionary = history.pop_back()
	_start_anim(player, boxes.duplicate())
	player = h["player"]
	boxes.assign(h["boxes"])
	moves = maxi(moves - 1, 0)
	if bool(h["pushed"]):
		pushes = maxi(pushes - 1, 0)
	_update_info()
	board.queue_redraw()
	Sfx.play("whoosh")


func _restart() -> void:
	_load_level(level_id)
	Sfx.play("whoosh")


func _finish_level() -> void:
	won = true
	var par := int(rec.get("par", moves))
	var stars := 3 if moves <= par + 2 else (2 if moves <= int(par * 1.6) + 4 else 1)
	Sfx.play("win")
	UiKit.burst(board, board.size / 2.0, Tokens.SUCCESS, 80)
	await wait(0.6)
	finish(stars, maxi(100, 1000 - maxi(moves - par, 0) * 15), "حللت المرحلة في %d حركة (الأفضل %d)" % [moves, par])
