extends MiniGame
## Maze seen from above. Drag a finger across the board (one cell per tile of travel) or
## hold the arrows to walk. Reach the gold exit. Stars by moves against `par` (the BFS
## shortest path stored by tools/maze_gen.py, which also proves every level is solvable).
## Cell format: one hex char per cell, open sides N=1 E=2 S=4 W=8.

const DIRS := {1: Vector2i(0, -1), 2: Vector2i(1, 0), 4: Vector2i(0, 1), 8: Vector2i(-1, 0)}
const REPEAT := 0.13

var rec: Dictionary = {}
var n := 5
var cells: Array = []        # rows of int masks
var player := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
var par := 1
var moves := 0
var elapsed := 0.0
var won := false
var visited := {}
var board: Control
var moves_chip: Label
var time_chip: Label
var _shown_sec := -1
var anim_t := 1.0
var from_player := Vector2i.ZERO
var facing := Vector2i(1, 0)
var _drag_from := Vector2.ZERO
var _dragging := false
var _held := Vector2i.ZERO
var _held_t := 0.0
var _pulse := 0.0


func _on_start() -> void:
	var v := frame("المتاهة")
	moves_chip = chip("", "")
	time_chip = chip("", "flame", Tokens.COIN)
	board = Control.new()
	board.custom_minimum_size = Vector2(0, 560)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	board.draw.connect(_paint)
	board.resized.connect(board.queue_redraw)
	board.gui_input.connect(_on_board_input)
	v.add_child(board)
	v.add_child(_dpad())
	var restart := UiKit.icon_button("restart", "إعادة", UiKit.Variant.GHOST)
	restart.pressed.connect(_restart)
	v.add_child(action_bar([restart]))
	var help := UiKit.label("اسحب إصبعك على المتاهة أو اضغط الأسهم مطوّلًا. اخرج من الباب الذهبي بأقل الحركات.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	rec = _read_level(level_id)
	if rec.is_empty():
		title_label.text = "تعذّر تحميل المرحلة"
		return
	_load_level()


## Reads only the requested level record (the file is small; nothing else is built).
static func _read_level(id: int) -> Dictionary:
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/maze/levels.json"))
	if not (p is Dictionary) or not p.has("levels"):
		return {}
	var all: Array = p["levels"]
	if all.is_empty():
		return {}
	return all[clampi(id - 1, 0, all.size() - 1)]


## Shortest path length by BFS (also used by the test runner to prove solvability).
static func bfs_steps(rows: Array, from: Vector2i, to: Vector2i) -> int:
	var cnt := rows.size()
	var dist := {from: 0}
	var q: Array[Vector2i] = [from]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if c == to:
			return int(dist[c])
		var mask := str(rows[c.y])[c.x].hex_to_int()
		for b in DIRS:
			if mask & int(b):
				var nx: Vector2i = c + DIRS[b]
				if nx.x >= 0 and nx.y >= 0 and nx.x < cnt and nx.y < cnt and not dist.has(nx):
					dist[nx] = int(dist[c]) + 1
					q.append(nx)
	return -1


func _dpad() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.layout_direction = Control.LAYOUT_DIRECTION_LTR
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", Tokens.SP_S)
	grid.add_theme_constant_override("v_separation", Tokens.SP_XS)
	var spec := [["", Vector2i.ZERO], ["arrow_up", Vector2i(0, -1)], ["", Vector2i.ZERO],
		["arrow_left", Vector2i(-1, 0)], ["arrow_down", Vector2i(0, 1)], ["arrow_right", Vector2i(1, 0)]]
	for c in spec:
		if str(c[0]) == "":
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(120, 72)
			grid.add_child(sp)
			continue
		var b := UiKit.icon_button(str(c[0]), "", UiKit.Variant.SECONDARY, accent)
		b.custom_minimum_size = Vector2(120, 72)
		var dir: Vector2i = c[1]
		b.button_down.connect(_press_dir.bind(dir))
		b.button_up.connect(_release_dir.bind(dir))
		grid.add_child(b)
	return grid


## Holding an arrow keeps walking (first repeat waits a bit longer).
func _press_dir(dir: Vector2i) -> void:
	_held = dir
	_held_t = REPEAT * 2.5
	_step(dir)


func _release_dir(dir: Vector2i) -> void:
	if _held == dir:
		_held = Vector2i.ZERO


## A held arrow must not keep walking after the pause menu (its release is never seen
## while the game is paused).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_held = Vector2i.ZERO
		_dragging = false


func _load_level() -> void:
	n = int(rec["size"])
	cells.clear()
	for row in rec["cells"]:
		var r := []
		for ch in str(row):
			r.append(str(ch).hex_to_int())
		cells.append(r)
	player = Vector2i(int(rec["start"][0]), int(rec["start"][1]))
	exit_cell = Vector2i(int(rec["exit"][0]), int(rec["exit"][1]))
	par = maxi(1, int(rec["par"]))
	title_label.text = "المتاهة · %s" % rec["name"]
	moves = 0
	elapsed = 0.0
	_shown_sec = -1
	won = false
	anim_t = 1.0
	visited = {player: true}
	_update_hud()
	board.queue_redraw()


func _anim_ok() -> bool:
	return not Motion.reduce_motion and Quality.tier() != "low"


func _process(delta: float) -> void:
	if rec.is_empty() or won:
		return
	elapsed += delta
	if int(elapsed) != _shown_sec:
		_shown_sec = int(elapsed)
		UiKit.set_chip(time_chip, "%d ث" % _shown_sec, false)
	if _held != Vector2i.ZERO:
		_held_t -= delta
		if _held_t <= 0.0:
			_held_t = REPEAT
			_step(_held)
	if Quality.fancy():   # exit glow only on fancy quality: no per-frame redraw otherwise
		_pulse = fmod(_pulse + delta, 1.6)
		board.queue_redraw()


func _geom() -> Array:
	var tile := floorf(minf((board.size.x - 12.0) / n, (board.size.y - 12.0) / n))
	tile = clampf(tile, 18.0, 110.0)
	var o := ((board.size - Vector2(n, n) * tile) / 2.0).floor()
	return [tile, o]


func _paint() -> void:
	if board.size.x < 60.0 or board.size.y < 60.0 or cells.is_empty():
		return
	var g := _geom()
	var tile: float = g[0]
	var o: Vector2 = g[1]
	board.draw_rect(Rect2(o - Vector2(6, 6), Vector2(n, n) * tile + Vector2(12, 12)), Color(Tokens.SURFACE_1, 0.85))
	for p in visited:
		var vp: Vector2i = p
		board.draw_rect(Rect2(o + Vector2(vp) * tile + Vector2(2, 2), Vector2(tile - 4, tile - 4)), Color(accent, 0.12))
	# exit
	var ec := o + (Vector2(exit_cell) + Vector2(0.5, 0.5)) * tile
	var glow := 0.25 + 0.2 * sin(_pulse / 1.6 * TAU) if Quality.fancy() else 0.3
	board.draw_circle(ec, tile * 0.46, Color(Tokens.COIN, glow))
	board.draw_rect(Rect2(ec - Vector2(tile * 0.24, tile * 0.3), Vector2(tile * 0.48, tile * 0.6)), Tokens.COIN)
	board.draw_circle(ec + Vector2(tile * 0.12, 0), maxf(2.0, tile * 0.05), Tokens.BG)
	# walls
	var wall_w := clampf(tile * 0.12, 3.0, 8.0)
	var wc := Tokens.LINE.lightened(0.35)
	for y in n:
		for x in n:
			var m: int = cells[y][x]
			var tl := o + Vector2(x, y) * tile
			if not (m & 1):
				board.draw_line(tl, tl + Vector2(tile, 0), wc, wall_w, true)
			if not (m & 8):
				board.draw_line(tl, tl + Vector2(0, tile), wc, wall_w, true)
			if y == n - 1 and not (m & 4):
				board.draw_line(tl + Vector2(0, tile), tl + Vector2(tile, tile), wc, wall_w, true)
			if x == n - 1 and not (m & 2):
				board.draw_line(tl + Vector2(tile, 0), tl + Vector2(tile, tile), wc, wall_w, true)
	# player
	var pp := Vector2(player)
	var squash := 0.0
	if anim_t < 1.0:
		pp = Vector2(from_player).lerp(pp, anim_t)
		squash = sin(anim_t * PI) * 0.12
	var pc := o + (pp + Vector2(0.5, 0.5)) * tile
	var rad := tile * 0.3
	board.draw_circle(pc + Vector2(1, 3), rad, Color(0, 0, 0, 0.3))
	board.draw_set_transform(pc, 0.0, Vector2(1.0 + squash, 1.0 - squash))
	board.draw_circle(Vector2.ZERO, rad, accent)
	board.draw_circle(Vector2(-rad * 0.3, -rad * 0.35), rad * 0.28, Color(1, 1, 1, 0.5))
	var look := Vector2(facing) * rad * 0.25
	board.draw_circle(look + Vector2(-rad * 0.32, -rad * 0.1), rad * 0.13, Tokens.BG)
	board.draw_circle(look + Vector2(rad * 0.32, -rad * 0.1), rad * 0.13, Tokens.BG)
	board.draw_set_transform(Vector2.ZERO)


func _on_board_input(e: InputEvent) -> void:
	# Touch arrives as emulated mouse too; reading only mouse avoids double moves.
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_dragging = e.pressed
		_drag_from = e.position
	elif e is InputEventMouseMotion and _dragging:
		var tile: float = _geom()[0]
		var step_px := clampf(tile * 0.8, 26.0, 70.0)
		var d: Vector2 = e.position - _drag_from
		# one cell per `step_px` of finger travel, so a long drag walks a corridor
		while d.length() >= step_px:
			var dir := Vector2i(1 if d.x > 0 else -1, 0) if absf(d.x) > absf(d.y) else Vector2i(0, 1 if d.y > 0 else -1)
			if not _step(dir):
				_drag_from = e.position
				break
			_drag_from += Vector2(dir) * step_px
			d = e.position - _drag_from


func _unhandled_key_input(e: InputEvent) -> void:   # keyboard on desktop builds
	if not (e is InputEventKey) or not e.pressed:
		return
	match (e as InputEventKey).keycode:
		KEY_UP:
			_step(Vector2i(0, -1))
		KEY_DOWN:
			_step(Vector2i(0, 1))
		KEY_LEFT:
			_step(Vector2i(-1, 0))
		KEY_RIGHT:
			_step(Vector2i(1, 0))


func can_move(from: Vector2i, dir: Vector2i) -> bool:
	for b in DIRS:
		if DIRS[b] == dir:
			return (int(cells[from.y][from.x]) & int(b)) != 0
	return false


func _step(dir: Vector2i) -> bool:
	if won or cells.is_empty():
		return false
	facing = dir
	if not can_move(player, dir):
		Sfx.play("tap", 0.7)
		return false
	from_player = player
	player += dir
	moves += 1
	visited[player] = true
	if _anim_ok():
		anim_t = 0.0
		var tw := create_tween()
		tw.tween_method(func(t: float):
			anim_t = t
			board.queue_redraw(), 0.0, 1.0, Motion.TAP)
	else:
		anim_t = 1.0
	Sfx.play("tap", 1.0 + 0.05 * float(moves % 4))
	board.queue_redraw()
	_update_hud()
	if player == exit_cell:
		_finish_level()
	return true


func _update_hud() -> void:
	UiKit.set_chip(moves_chip, "%d حركة · الأفضل %d" % [moves, par], false)


func _restart() -> void:
	_held = Vector2i.ZERO
	_load_level()
	Sfx.play("whoosh")


static func stars_for(p_moves: int, p_par: int) -> int:
	if p_moves <= p_par + maxi(2, floori(p_par / 10.0)):
		return 3
	if p_moves <= int(p_par * 1.6) + 4:
		return 2
	return 1


func _finish_level() -> void:
	won = true
	_held = Vector2i.ZERO
	var stars := stars_for(moves, par)
	Sfx.play("win")
	var g := _geom()
	var ec: Vector2 = g[1] + (Vector2(exit_cell) + Vector2(0.5, 0.5)) * float(g[0])
	UiKit.burst(board, ec, Tokens.COIN, 80)
	UiKit.ring(board, ec, Tokens.COIN, float(g[0]) * 2.5)
	board.queue_redraw()
	await wait(Motion.NEXT_BUTTON_MAX_DELAY)
	var score := maxi(100, 1000 - maxi(moves - par, 0) * 10 - int(elapsed) * 2)
	finish(stars, score, "خرجت في %d حركة و%d ثانية (أقصر طريق %d)" % [moves, int(elapsed), par])
