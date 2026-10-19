extends MiniGame
## Advanced laser: tap a mirror or splitter to flip it ( / <-> \ ). Every target must be lit
## by a beam of ITS color, and no beam may touch a bomb. Splitters let the beam pass AND
## reflect. Each level has exactly one winning orientation set (tools/laser_gen.py);
## par = flips needed from the start position.

const BEAM := [Color("#FF5E6C"), Color("#2CC9B5")]

var defs: Array = []
var lv: Dictionary = {}
var n := 6
var walls := {}
var fixed := {}          # cell -> 0 '/' or 1 '\'
var pieces: Array = []   # [{cell, kind, o}]
var piece_at := {}       # cell -> index
var targets := {}        # cell -> color
var bombs := {}
var sources: Array = []  # [{cell, dir, color}]
var vis_angle: Array[float] = []
var segments: Array = [] # [from, to, color] in cell units (centers)
var lit := {}
var boom := {}
var flips := 0
var solved := false
var board: Control
var flip_chip: Label
var par_chip: Label
var _time := 0.0


func _on_start() -> void:
	var v := frame("الليزر والمرايا")
	flip_chip = chip("0", "restart")
	par_chip = chip("", "star", Tokens.COIN)
	board = Control.new()
	board.custom_minimum_size = Vector2(0, 660)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	board.draw.connect(_paint)
	board.resized.connect(board.queue_redraw)
	board.gui_input.connect(_on_input)
	v.add_child(board)
	var r := UiKit.icon_button("restart", "إعادة", UiKit.Variant.GHOST)
	r.pressed.connect(_restart)
	v.add_child(action_bar([r]))
	v.add_child(UiKit.label("اضغط المرآة لتقلبها. أضئ كل هدف بشعاع من لونه، ولا تلمس القنابل. المقسِّم يمرر الشعاع ويعكسه معًا.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/laser/levels.json"))
	if p is Dictionary:
		defs = p["levels"]
	if defs.is_empty():
		title_label.text = "تعذّر تحميل المراحل"
		return
	_load_level(level_id)


func _cell(a) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


func _load_level(id: int) -> void:
	lv = defs[clampi(id - 1, 0, defs.size() - 1)]
	title_label.text = "الليزر · %s" % lv["name"]
	n = int(lv["size"])
	walls.clear()
	fixed.clear()
	targets.clear()
	bombs.clear()
	pieces.clear()
	piece_at.clear()
	sources.clear()
	vis_angle.clear()
	for w in lv["walls"]:
		walls[_cell(w)] = true
	for f in lv["fixed"]:
		fixed[_cell(f)] = int(f[2])
	for t in lv["targets"]:
		targets[Vector2i(int(t["x"]), int(t["y"]))] = int(t["color"])
	for b in lv["bombs"]:
		bombs[_cell(b)] = true
	for s in lv["sources"]:
		sources.append({"cell": Vector2i(int(s["x"]), int(s["y"])), "dir": _cell(s["dir"]), "color": int(s["color"])})
	for pc in lv["pieces"]:
		var c := Vector2i(int(pc["x"]), int(pc["y"]))
		piece_at[c] = pieces.size()
		pieces.append({"cell": c, "kind": str(pc["kind"]), "o": int(pc["start"])})
		vis_angle.append(_angle_of(int(pc["start"])))
	flips = 0
	solved = false
	_trace()
	_refresh()


func _angle_of(o: int) -> float:
	return -PI / 4.0 if o == 0 else PI / 4.0


static func _reflect(o: int, d: Vector2i) -> Vector2i:
	return Vector2i(-d.y, -d.x) if o == 0 else Vector2i(d.y, d.x)


## Same rules as tools/laser_gen.py trace().
func _trace() -> void:
	segments.clear()
	lit.clear()
	boom.clear()
	var src_cells := {}
	for s in sources:
		src_cells[s["cell"]] = true
	for s in sources:
		var col: int = s["color"]
		var stack: Array = [[s["cell"], s["dir"]]]
		var seen := {}
		while not stack.is_empty():
			var item: Array = stack.pop_back()
			var p: Vector2i = item[0]
			var d: Vector2i = item[1]
			while true:
				var q := p + d
				if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n or walls.has(q) or src_cells.has(q):
					segments.append([Vector2(p), Vector2(p) + Vector2(d) * 0.5, col])
					break
				var key := "%d,%d,%d,%d,%d" % [q.x, q.y, d.x, d.y, col]
				if seen.has(key):
					break
				seen[key] = true
				segments.append([Vector2(p), Vector2(q), col])
				p = q
				if bombs.has(p):
					boom[p] = true
					break
				if targets.has(p):
					if int(targets[p]) == col:
						lit[p] = true
					break
				if fixed.has(p):
					d = _reflect(int(fixed[p]), d)
				elif piece_at.has(p):
					var pc: Dictionary = pieces[int(piece_at[p])]
					if pc["kind"] == "split":
						stack.append([p, d])
					d = _reflect(int(pc["o"]), d)


func _won() -> bool:
	if not boom.is_empty():
		return false
	for t in targets:
		if not lit.has(t):
			return false
	return true


func _refresh() -> void:
	UiKit.set_chip(flip_chip, str(flips))
	UiKit.set_chip(par_chip, "الأقل %d" % int(lv.get("par", 0)), false)
	board.queue_redraw()


func _geom() -> Array:
	var cell := minf((board.size.x - 16.0) / n, (board.size.y - 16.0) / n)
	var o := (board.size - Vector2(cell, cell) * n) / 2.0
	return [cell, o]


func _on_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or solved or defs.is_empty():
		return
	var g := _geom()
	var rel: Vector2 = (e.position - g[1]) / float(g[0])
	var c := Vector2i(floori(rel.x), floori(rel.y))
	if not piece_at.has(c):
		return
	var i := int(piece_at[c])
	pieces[i]["o"] = 1 - int(pieces[i]["o"])
	flips += 1
	Sfx.play("pop", 1.1)
	Settings.vibrate(8)
	var to := _angle_of(int(pieces[i]["o"]))
	if Motion.reduce_motion:
		vis_angle[i] = to
	else:
		var from := vis_angle[i]
		var tw := create_tween()
		tw.tween_method(func(a: float):
			vis_angle[i] = a
			board.queue_redraw(), from, to, Motion.FAST).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_trace()
	_refresh()
	if not boom.is_empty():
		Sfx.play("wrong")
		Motion.shake_area(self, 8.0)
	if _won():
		_win()


func _win() -> void:
	solved = true
	Sfx.play("win")
	var g := _geom()
	for t in targets:
		UiKit.burst(board, g[1] + (Vector2(t) + Vector2(0.5, 0.5)) * float(g[0]), Tokens.COIN, 40)
	var par := int(lv.get("par", flips))
	var stars := 3 if flips <= par + 1 else (2 if flips <= par * 2 + 2 else 1)
	await wait(1.2)
	finish(stars, maxi(100, 1200 - maxi(flips - par, 0) * 40), "أضأت كل الأهداف في %d قلبة (الأقل %d)" % [flips, par])


func _restart() -> void:
	_load_level(level_id)
	Sfx.play("whoosh")


func _process(delta: float) -> void:
	_time += delta
	if Quality.fancy() and not defs.is_empty():
		board.queue_redraw()   # beam shimmer + target glow


func _paint() -> void:
	if board.size.x < 60.0 or board.size.y < 60.0:
		return   # not laid out yet (first frame): avoid negative sizes
	if defs.is_empty():
		return
	var g := _geom()
	var cell: float = g[0]
	var o: Vector2 = g[1]
	var cc := func(p: Vector2) -> Vector2: return o + (p + Vector2(0.5, 0.5)) * cell
	board.draw_rect(Rect2(o - Vector2(6, 6), Vector2(cell * n + 12, cell * n + 12)), Tokens.SURFACE_2)
	for y in n:
		for x in n:
			var p := Vector2i(x, y)
			var r := Rect2(o + Vector2(x, y) * cell + Vector2(2, 2), Vector2(cell - 4, cell - 4))
			if walls.has(p):
				board.draw_rect(r, Tokens.LINE)
				board.draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Tokens.LINE.lightened(0.2))
			else:
				board.draw_rect(r, Color(Tokens.SURFACE_1, 0.9 if (x + y) % 2 == 0 else 0.75))
	# beams: wide soft glow, then bright core
	var shimmer := 0.85 + 0.15 * sin(_time * 9.0)
	for s in segments:
		var a: Vector2 = cc.call(s[0])
		var b: Vector2 = cc.call(s[1])
		var col: Color = BEAM[int(s[2])]
		board.draw_line(a, b, Color(col, 0.22 * shimmer), cell * 0.32, true)
	for s in segments:
		var a: Vector2 = cc.call(s[0])
		var b: Vector2 = cc.call(s[1])
		board.draw_line(a, b, Color(BEAM[int(s[2])]).lightened(0.35), maxf(cell * 0.07, 3.0), true)
	for f in fixed:
		_draw_mirror(cc.call(Vector2(f)), cell, _angle_of(int(fixed[f])), Tokens.TEXT_MUTED, false, false)
	for i in pieces.size():
		var pc: Dictionary = pieces[i]
		var c: Vector2 = cc.call(Vector2(pc["cell"]))
		board.draw_circle(c, cell * 0.42, Color(accent, 0.12))
		board.draw_arc(c, cell * 0.42, 0, TAU, 32, Color(accent, 0.55), 2.0, true)
		_draw_mirror(c, cell, vis_angle[i], Tokens.TEXT, pc["kind"] == "split", true)
	for t in targets:
		var c: Vector2 = cc.call(Vector2(t))
		var col: Color = BEAM[int(targets[t])]
		var on := lit.has(t)
		var glow := 0.5 + 0.5 * sin(_time * 4.0)
		if on:
			board.draw_circle(c, cell * (0.42 + 0.05 * glow), Color(col, 0.3))
		board.draw_circle(c, cell * 0.3, Tokens.BG)
		board.draw_arc(c, cell * 0.3, 0, TAU, 32, col, 5.0, true)
		if int(targets[t]) == 1:   # second color also gets a different shape (colorblind)
			var h := cell * 0.14
			board.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)]), col if on else Color(col, 0.4))
		else:
			board.draw_circle(c, cell * 0.12, col if on else Color(col, 0.4))
	for b in bombs:
		var c: Vector2 = cc.call(Vector2(b))
		var hot := boom.has(b)
		board.draw_circle(c, cell * 0.3, Color("#2A1A1A") if not hot else Tokens.ERROR)
		board.draw_arc(c, cell * 0.3, 0, TAU, 24, Tokens.ERROR, 3.0, true)
		var k := cell * 0.13
		board.draw_line(c - Vector2(k, k), c + Vector2(k, k), Tokens.ERROR if not hot else Tokens.TEXT, 4.0, true)
		board.draw_line(c + Vector2(-k, k), c + Vector2(k, -k), Tokens.ERROR if not hot else Tokens.TEXT, 4.0, true)
	for s in sources:
		var c: Vector2 = cc.call(Vector2(s["cell"]))
		var col: Color = BEAM[int(s["color"])]
		var r := Rect2(c - Vector2(cell, cell) * 0.32, Vector2(cell, cell) * 0.64)
		board.draw_rect(r, Tokens.SURFACE_2)
		board.draw_rect(r, col, false, 4.0)
		var d: Vector2 = Vector2(s["dir"])
		var tip := c + d * cell * 0.28
		var side := Vector2(-d.y, d.x) * cell * 0.14
		board.draw_colored_polygon(PackedVector2Array([tip, c - d * cell * 0.06 + side, c - d * cell * 0.06 - side]), col)


func _draw_mirror(c: Vector2, cell: float, ang: float, col: Color, split: bool, movable: bool) -> void:
	var half := Vector2(cos(ang), sin(ang)) * cell * 0.36
	var w := maxf(cell * 0.09, 5.0)
	board.draw_line(c - half + Vector2(2, 4), c + half + Vector2(2, 4), Color(0, 0, 0, 0.35), w, true)
	if split:
		var segs := 5
		for k in segs:
			if k % 2 == 0:
				var a := c - half + half * 2.0 * (float(k) / segs)
				var b := c - half + half * 2.0 * (float(k + 1) / segs)
				board.draw_line(a, b, Tokens.COIN, w, true)
	else:
		board.draw_line(c - half, c + half, col, w, true)
		board.draw_line(c - half * 0.9, c + half * 0.9, Color(1, 1, 1, 0.5), w * 0.3, true)
	if movable:
		board.draw_circle(c, w * 0.7, Tokens.COIN if split else accent)
