extends MiniGame
## Pipe engineer: lay pipes so water reaches every house from the source, as cheaply as
## possible. Ground costs 1, mud 2, rock 3, dark cells are blocked. Tap or drag to lay pipes
## (drag again over pipes to remove them). Press «سلّم» when every house has water.
## The optimal cost of each level (content/pipe_cost/levels.json) is exact: a node-weighted
## Steiner tree solved by Dreyfus-Wagner in tools/pipe_cost_gen.py, re-solved here by
## steiner_cost() inside the test runner.

const COSTS := {".": 1, "~": 2, "^": 3}

var lv: Dictionary = {}
var n := 6
var grid: Array = []          # strings
var pipes := {}               # Vector2i -> true
var wet := {}                 # cells reached by water
var source := Vector2i.ZERO
var houses: Array[Vector2i] = []
var optimal := 1
var done := false
var board: Control
var cost_chip: Label
var goal_chip: Label
var submit: Button
var _paint_mode := 0          # 1 add, -1 remove, 0 none
var _last_cell := Vector2i(-1, -1)
var _flow := 0.0              # 0..1 phase of the water animation


func _on_start() -> void:
	var v := frame("مهندس الأنابيب")
	cost_chip = chip("", "coin", Tokens.COIN)
	goal_chip = chip("", "star", Tokens.COIN)
	board = Control.new()
	board.custom_minimum_size = Vector2(0, 600)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	board.draw.connect(_paint)
	board.resized.connect(board.queue_redraw)
	board.gui_input.connect(_on_board_input)
	v.add_child(board)
	var clear := UiKit.icon_button("restart", "امسح الأنابيب", UiKit.Variant.GHOST)
	clear.pressed.connect(_clear)
	submit = UiKit.icon_button("check", "سلّم الشبكة", UiKit.Variant.PRIMARY, accent)
	submit.pressed.connect(_submit)
	v.add_child(action_bar([clear, submit]))
	var help := UiKit.label("اضغط أو اسحب لتمد الأنابيب، واسحب فوقها لإزالتها. الأرض 1، الطين 2، الصخر 3. أوصل الماء لكل البيوت بأقل تكلفة.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/pipe_cost/levels.json"))
	if not (p is Dictionary) or (p.get("levels", []) as Array).is_empty():
		title_label.text = "تعذّر تحميل المرحلة"
		submit.disabled = true
		return
	var all: Array = p["levels"]
	lv = all[clampi(level_id - 1, 0, all.size() - 1)]
	_load_level()


func _load_level() -> void:
	title_label.text = "مهندس الأنابيب · %s" % lv["name"]
	grid = lv["grid"]
	n = grid.size()
	optimal = int(lv["optimal"])
	houses.clear()
	for y in n:
		for x in n:
			var ch := str(grid[y])[x]
			if ch == "S":
				source = Vector2i(x, y)
			elif ch in ["A", "B", "C", "D"]:
				houses.append(Vector2i(x, y))
	pipes.clear()
	done = false
	_update()


static func cell_cost(rows: Array, c: Vector2i) -> int:
	return int(COSTS.get(str(rows[c.y])[c.x], 0))


func _is_terrain(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < n and c.y < n and COSTS.has(str(grid[c.y])[c.x])


func _is_node(c: Vector2i) -> bool:
	return pipes.has(c) or c == source or c in houses


func total_cost() -> int:
	var t := 0
	for c in pipes:
		t += cell_cost(grid, c)
	return t


func _update() -> void:
	wet.clear()
	var st: Array[Vector2i] = [source]
	wet[source] = 0               # value = distance from the source (breadth-first)
	var head := 0
	while head < st.size():
		var c: Vector2i = st[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			if not wet.has(q) and _is_node(q):
				wet[q] = int(wet[c]) + 1
				st.append(q)
	var all_wet := true
	for hs in houses:
		all_wet = all_wet and wet.has(hs)
	submit.disabled = not all_wet or done
	UiKit.set_chip(cost_chip, "التكلفة %d" % total_cost())
	UiKit.set_chip(goal_chip, "3 نجوم: %d" % optimal, false)
	board.queue_redraw()


func _geom() -> Array:
	var cell := floorf(minf((board.size.x - 12.0) / n, (board.size.y - 12.0) / n))
	cell = clampf(cell, 24.0, 110.0)
	return [cell, ((board.size - Vector2(n, n) * cell) / 2.0).floor()]


func _cell_at(p: Vector2) -> Vector2i:
	var g := _geom()
	var q: Vector2 = (p - g[1]) / float(g[0])
	return Vector2i(floori(q.x), floori(q.y))


func _on_board_input(e: InputEvent) -> void:
	if done or lv.is_empty():
		return
	# Touch arrives as emulated mouse too; reading only mouse avoids double events.
	var mb := e as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			var c := _cell_at(mb.position)
			if _is_terrain(c):
				_paint_mode = -1 if pipes.has(c) else 1
				_last_cell = Vector2i(-1, -1)
				_apply(c)
		else:
			_paint_mode = 0
	var mm := e as InputEventMouseMotion
	if mm and _paint_mode != 0:
		_apply(_cell_at(mm.position))


func _apply(c: Vector2i) -> void:
	if c == _last_cell or not _is_terrain(c):
		return
	_last_cell = c
	if _paint_mode > 0 and not pipes.has(c):
		pipes[c] = true
		Sfx.play("tap", 1.0 + 0.1 * cell_cost(grid, c))
	elif _paint_mode < 0 and pipes.has(c):
		pipes.erase(c)
		Sfx.play("tap", 0.7)
	else:
		return
	var had := 0
	for hs in houses:
		if wet.has(hs):
			had += 1
	_update()
	var now := 0
	for hs in houses:
		if wet.has(hs):
			now += 1
	if now > had:
		var g := _geom()
		for hs in houses:
			if wet.has(hs):
				UiKit.ring(board, g[1] + (Vector2(hs) + Vector2(0.5, 0.5)) * float(g[0]), Tokens.SUCCESS, float(g[0]) * 1.4)
		Sfx.play("correct")
		Settings.vibrate(12)


func _process(delta: float) -> void:
	if done or wet.size() < 2 or not Quality.fancy():
		return
	_flow = fmod(_flow + delta * 1.6, 1.0)
	board.queue_redraw()


func _clear() -> void:
	if done:
		return
	pipes.clear()
	Sfx.play("whoosh")
	_update()


static func stars_for(cost: int, opt: int) -> int:
	if cost <= opt:
		return 3
	if cost <= opt + maxi(2, ceili(opt * 0.2)):
		return 2
	return 1


func _submit() -> void:
	if done or submit.disabled:
		return
	done = true
	submit.disabled = true
	var c := total_cost()
	var stars := stars_for(c, optimal)
	Sfx.play("win")
	UiKit.burst(board, board.size / 2.0, accent, 80)
	board.queue_redraw()
	await wait(Motion.NEXT_BUTTON_MAX_DELAY)
	finish(stars, maxi(100, 1000 - (c - optimal) * 60), "تكلفة شبكتك %d (أقل تكلفة ممكنة %d)" % [c, optimal])


func _paint() -> void:
	if board.size.x < 60.0 or board.size.y < 60.0 or lv.is_empty():
		return
	var g := _geom()
	var cell: float = g[0]
	var o: Vector2 = g[1]
	var fs := int(clampf(cell * 0.28, 12.0, 26.0))
	for y in n:
		for x in n:
			var ch := str(grid[y])[x]
			var r := Rect2(o + Vector2(x, y) * cell, Vector2(cell, cell)).grow(-1.5)
			var col := Tokens.SURFACE_2
			match ch:
				"~":
					col = Tokens.COIN.darkened(0.62)
				"^":
					col = Tokens.TEXT_MUTED.darkened(0.45)
				"#":
					col = Tokens.BG
			board.draw_rect(r, col)
			if ch == "#":
				board.draw_line(r.position + Vector2(6, 6), r.end - Vector2(6, 6), Tokens.LINE, 2.0)
				board.draw_line(Vector2(r.end.x - 6, r.position.y + 6), Vector2(r.position.x + 6, r.end.y - 6), Tokens.LINE, 2.0)
			elif COSTS.has(ch) and not pipes.has(Vector2i(x, y)):
				board.draw_string(Tokens.font_bold, r.position + Vector2(5, fs + 2), str(COSTS[ch]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Tokens.TEXT, 0.45))
	# pipes: a joint per cell and a segment to every connected neighbour
	var pw := maxf(6.0, cell * 0.26)
	for c in pipes:
		var cc: Vector2i = c
		var col2 := accent if wet.has(cc) else Tokens.TEXT_MUTED
		var pc := o + (Vector2(cc) + Vector2(0.5, 0.5)) * cell
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = cc + d
			if _is_node(q):
				board.draw_line(pc, pc + Vector2(d) * cell * 0.5, col2, pw)
		board.draw_circle(pc, pw * 0.62, col2)
	# moving water: a bright drop on every wet segment, travelling away from the source
	if Quality.fancy():
		var wcol := accent.lightened(0.55)
		for c in wet:
			var cc2: Vector2i = c
			var p0 := o + (Vector2(cc2) + Vector2(0.5, 0.5)) * cell
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q2: Vector2i = cc2 + d
				if wet.has(q2) and int(wet[q2]) == int(wet[cc2]) + 1:
					board.draw_circle(p0 + Vector2(d) * cell * _flow, pw * 0.32, wcol)
	# source and houses
	var sc := o + (Vector2(source) + Vector2(0.5, 0.5)) * cell
	board.draw_circle(sc, cell * 0.4, accent)
	board.draw_colored_polygon(PackedVector2Array([sc + Vector2(0, -cell * 0.26), sc + Vector2(cell * 0.16, cell * 0.06), sc + Vector2(0, cell * 0.22), sc + Vector2(-cell * 0.16, cell * 0.06)]), Tokens.BG)
	for hs in houses:
		var hc := o + (Vector2(hs) + Vector2(0.5, 0.5)) * cell
		var hcol := Tokens.SUCCESS if wet.has(hs) else Tokens.COIN
		var s := cell * 0.34
		board.draw_rect(Rect2(hc + Vector2(-s, -s * 0.1), Vector2(s * 2, s * 1.2)), hcol)
		board.draw_colored_polygon(PackedVector2Array([hc + Vector2(-s * 1.2, -s * 0.05), hc + Vector2(0, -s * 1.1), hc + Vector2(s * 1.2, -s * 0.05)]), hcol.darkened(0.25))
		board.draw_rect(Rect2(hc + Vector2(-s * 0.25, s * 0.45), Vector2(s * 0.5, s * 0.65)), Tokens.BG)


# ---------------- exact optimum (used by the test runner) ----------------
## Node-weighted Steiner tree cost (Dreyfus-Wagner). Same algorithm as the Python tool.
static func steiner_cost(rows: Array) -> int:
	var cnt := rows.size()
	var idx := {}
	var w: Array[int] = []
	var pos: Array[Vector2i] = []
	var terms: Array[int] = []
	var src := -1
	for y in cnt:
		for x in cnt:
			var ch := str(rows[y])[x]
			if ch == "#":
				continue
			idx[Vector2i(x, y)] = pos.size()
			pos.append(Vector2i(x, y))
			w.append(int(COSTS.get(ch, 0)))
			if ch == "S":
				src = pos.size() - 1
			elif not COSTS.has(ch):
				terms.append(pos.size() - 1)
	terms.push_front(src)
	var nb: Array = []
	for p in pos:
		var l: Array[int] = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if idx.has(p + d):
				l.append(int(idx[p + d]))
		nb.append(l)
	var V := pos.size()
	var k := terms.size()
	var full := (1 << k) - 1
	var BIG := 1 << 40
	var dp: Array = []
	for s in full + 1:
		var row := PackedInt64Array()
		row.resize(V)
		row.fill(BIG)
		dp.append(row)
	for i in k:
		var r0: PackedInt64Array = dp[1 << i]
		r0[terms[i]] = w[terms[i]]
		dp[1 << i] = r0
	for s in range(1, full + 1):
		var d: PackedInt64Array = dp[s]
		var sub := (s - 1) & s
		while sub > 0:
			var other := s ^ sub
			if sub < other:
				var a: PackedInt64Array = dp[sub]
				var b: PackedInt64Array = dp[other]
				for v in V:
					if a[v] < BIG and b[v] < BIG:
						d[v] = mini(d[v], a[v] + b[v] - w[v])
			sub = (sub - 1) & s
		# Dijkstra (V <= 81: simple O(V^2) selection is enough)
		var fixed := PackedByteArray()
		fixed.resize(V)
		for _it in V:
			var best := -1
			for v in V:
				if fixed[v] == 0 and d[v] < BIG and (best < 0 or d[v] < d[best]):
					best = v
			if best < 0:
				break
			fixed[best] = 1
			for u in nb[best]:
				if d[best] + w[u] < d[u]:
					d[u] = d[best] + w[u]
		dp[s] = d
	var fin: PackedInt64Array = dp[full]
	return int(fin[terms[0]])
