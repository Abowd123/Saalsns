extends MiniGame
## Space challenge: fill the board with every piece, no overlaps. Pieces keep their
## orientation (no rotation, like fixed tetris pieces). Tap a piece in the tray, then touch
## the board: a ghost follows the finger and the piece drops where you lift it. Touch a
## placed piece to pick it up again. Hints place one piece where the solution has it.
## Levels: content/packing/levels.json. tools/packing_gen.py proves each has a solution
## (exact-cover search) and counts them: every level has exactly one.

var lv: Dictionary = {}
var w := 4
var h := 4
var holes := {}
var pieces: Array = []          # Array of Array[Vector2i]
var placed := {}                # piece index -> Vector2i offset
var selected := -1
var ghost := Vector2i(-99, -99)
var pickups := 0
var hints := 0
var won := false
var board: Control
var tray: HFlowContainer
var tray_items: Array = []
var info: Label
var hint_chip: Label
var _pressing := false
var _colors: Array = []
var _settle := {}             # piece index -> 0..1 settle animation


func _on_start() -> void:
	var v := frame("تحدي المساحة")
	info = chip("", "puzzle")
	hint_chip = chip("0", "hint", Tokens.COIN)
	board = Control.new()
	board.custom_minimum_size = Vector2(0, 520)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	board.draw.connect(_paint)
	board.resized.connect(board.queue_redraw)
	board.gui_input.connect(_on_board_input)
	v.add_child(board)
	tray = HFlowContainer.new()
	tray.layout_direction = Control.LAYOUT_DIRECTION_LTR
	tray.add_theme_constant_override("h_separation", Tokens.SP_S)
	tray.add_theme_constant_override("v_separation", Tokens.SP_S)
	tray.alignment = FlowContainer.ALIGNMENT_CENTER
	v.add_child(tray)
	var clear := UiKit.icon_button("restart", "أفرغ اللوحة", UiKit.Variant.GHOST)
	clear.pressed.connect(_clear)
	var hint := UiKit.icon_button("hint", "تلميح", UiKit.Variant.SECONDARY, Tokens.COIN)
	hint.pressed.connect(_hint)
	v.add_child(action_bar([clear, hint]))
	var help := UiKit.label("اختر قطعة ثم المس اللوحة واسحب، وارفع إصبعك لتضعها. المس قطعة موضوعة لتحملها من جديد. القطع لا تدور.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	_colors = [Tokens.WORLD_COLORS[Tokens.World.BUILD], Tokens.WORLD_COLORS[Tokens.World.PUZZLES], Tokens.WORLD_COLORS[Tokens.World.KNOWLEDGE],
		Tokens.WORLD_COLORS[Tokens.World.SPEED], Tokens.COIN, Tokens.SUCCESS.lightened(0.2), Tokens.TEXT_MUTED,
		Tokens.WORLD_COLORS[Tokens.World.PUZZLES].darkened(0.3), Tokens.WORLD_COLORS[Tokens.World.SPEED].lightened(0.3), Tokens.WORLD_COLORS[Tokens.World.KNOWLEDGE].darkened(0.3)]
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/packing/levels.json"))
	if not (p is Dictionary) or (p.get("levels", []) as Array).is_empty():
		title_label.text = "تعذّر تحميل المرحلة"
		return
	var all: Array = p["levels"]
	lv = all[clampi(level_id - 1, 0, all.size() - 1)]
	_load_level()


func _load_level() -> void:
	title_label.text = "تحدي المساحة · %s" % lv["name"]
	w = int(lv["w"])
	h = int(lv["h"])
	holes.clear()
	for hp in lv["holes"]:
		holes[Vector2i(int(hp[0]), int(hp[1]))] = true
	pieces.clear()
	for pc in lv["pieces"]:
		var cells: Array[Vector2i] = []
		for c in pc:
			cells.append(Vector2i(int(c[0]), int(c[1])))
		pieces.append(cells)
	placed.clear()
	selected = -1
	_build_tray()
	_refresh()


func _color(i: int) -> Color:
	return _colors[i % _colors.size()]


static func piece_size(cells: Array) -> Vector2i:
	var m := Vector2i.ZERO
	for c in cells:
		m = Vector2i(maxi(m.x, (c as Vector2i).x), maxi(m.y, (c as Vector2i).y))
	return m + Vector2i.ONE


func _build_tray() -> void:
	for c in tray.get_children():
		c.queue_free()
	tray_items.clear()
	for i in pieces.size():
		var sz := piece_size(pieces[i])
		var cell := 24.0
		var item := Control.new()
		item.custom_minimum_size = Vector2(maxf(sz.x * cell + 16, Tokens.TOUCH_MIN), maxf(sz.y * cell + 16, Tokens.TOUCH_MIN))
		var idx := i
		item.draw.connect(func(): _paint_tray_item(item, idx, cell))
		item.gui_input.connect(func(e: InputEvent):
			var mb := e as InputEventMouseButton
			if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_select(idx))
		tray.add_child(item)
		tray_items.append(item)


func _paint_tray_item(item: Control, i: int, cell: float) -> void:
	var sz := piece_size(pieces[i])
	var o := (item.size - Vector2(sz) * cell) / 2.0
	if i == selected:
		item.draw_rect(Rect2(Vector2.ZERO, item.size), Color(accent, 0.18))
		item.draw_rect(Rect2(Vector2.ZERO, item.size), accent, false, 3.0)
	var col := _color(i)
	if placed.has(i):
		col = Color(col, 0.18)
	for c in pieces[i]:
		item.draw_rect(Rect2(o + Vector2(c) * cell + Vector2(1, 1), Vector2(cell - 2, cell - 2)), col)


func _select(i: int) -> void:
	if won:
		return
	if placed.has(i):
		placed.erase(i)
		pickups += 1
	selected = i if selected != i else -1
	Sfx.play("tap")
	_refresh()


func _refresh() -> void:
	UiKit.set_chip(info, "%d/%d قطع" % [placed.size(), pieces.size()], false)
	UiKit.set_chip(hint_chip, str(hints))
	for it in tray_items:
		(it as Control).queue_redraw()
	board.queue_redraw()


func _geom() -> Array:
	var cell := floorf(minf((board.size.x - 16.0) / w, (board.size.y - 16.0) / h))
	cell = clampf(cell, 20.0, 110.0)
	var o := ((board.size - Vector2(w, h) * cell) / 2.0).floor()
	return [cell, o]


func _cell_at(p: Vector2) -> Vector2i:
	var g := _geom()
	var q: Vector2 = (p - g[1]) / float(g[0])
	return Vector2i(floori(q.x), floori(q.y))


## Cells covered by piece i at offset (board coordinates).
func cover(i: int, off: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in pieces[i]:
		out.append(c + off)
	return out


func can_place(i: int, off: Vector2i) -> bool:
	var taken := {}
	for j in placed:
		if j != i:
			for c in cover(j, placed[j]):
				taken[c] = true
	for c in cover(i, off):
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or holes.has(c) or taken.has(c):
			return false
	return true


## Finger cell -> piece offset (the finger sits on the middle of the piece).
func _offset_for(i: int, cell: Vector2i) -> Vector2i:
	var sz := piece_size(pieces[i])
	return cell - Vector2i(floori((sz.x - 1) / 2.0), floori((sz.y - 1) / 2.0))


func _piece_at(cell: Vector2i) -> int:
	for j in placed:
		if cell in cover(j, placed[j]):
			return j
	return -1


func _on_board_input(e: InputEvent) -> void:
	if won or lv.is_empty():
		return
	# Touch arrives as emulated mouse too; reading only mouse avoids double events.
	var mb := e as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			var cell := _cell_at(mb.position)
			var under := _piece_at(cell)
			if under >= 0:   # pick up a placed piece and keep dragging it
				placed.erase(under)
				pickups += 1
				selected = under
				Sfx.play("tap")
			if selected < 0:
				return
			_pressing = true
			ghost = _offset_for(selected, cell)
			_refresh()
		elif _pressing:
			_pressing = false
			_drop()
	var mm := e as InputEventMouseMotion
	if mm and _pressing and selected >= 0:
		var g2 := _offset_for(selected, _cell_at(mm.position))
		if g2 != ghost:
			ghost = g2
			board.queue_redraw()


func _drop() -> void:
	var i := selected
	if i < 0:
		return
	if can_place(i, ghost):
		placed[i] = ghost
		selected = -1
		_settle_anim(i)
		Sfx.play("pop")
		Settings.vibrate(12)
		_refresh()
		_check_win()
	else:
		Sfx.play("wrong")
		Settings.vibrate(20)
		Motion.shake(board)
		ghost = Vector2i(-99, -99)
		_refresh()


func _anim_ok() -> bool:
	return not Motion.reduce_motion and Quality.tier() != "low"


func _piece_center(i: int) -> Vector2:
	var g := _geom()
	var acc := Vector2.ZERO
	for c in cover(i, placed[i]):
		acc += Vector2(c) + Vector2(0.5, 0.5)
	return g[1] + acc / float(pieces[i].size()) * float(g[0])


func _settle_anim(i: int) -> void:
	UiKit.ring(board, _piece_center(i), _color(i), float(_geom()[0]) * 1.8)
	if not _anim_ok():
		return
	_settle[i] = 0.0
	var tw := create_tween()
	tw.tween_method(func(v: float):
		_settle[i] = v
		board.queue_redraw(), 0.0, 1.0, Motion.BASE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _settle.erase(i))


func _clear() -> void:
	if won or placed.is_empty():
		return
	pickups += placed.size()
	placed.clear()
	selected = -1
	Sfx.play("whoosh")
	_refresh()


func _hint() -> void:
	if won or lv.is_empty():
		return
	var sol: Array = lv["solution"]
	for s in sol:
		var i := int(s[0])
		var off := Vector2i(int(s[1]), int(s[2]))
		if placed.get(i, Vector2i(-99, -99)) == off:
			continue
		placed.erase(i)
		var want := cover(i, off)
		for j in placed.keys():
			for c in cover(j, placed[j]):
				if c in want:
					placed.erase(j)
					break
		placed[i] = off
		_settle_anim(i)
		hints += 1
		selected = -1
		Sfx.play("coin")
		_refresh()
		_check_win()
		return


static func stars_for(p_hints: int, p_pickups: int) -> int:
	if p_hints == 0 and p_pickups <= 2:
		return 3
	if p_hints <= 1 and p_pickups <= 6:
		return 2
	return 1


func _check_win() -> void:
	if placed.size() < pieces.size():
		return
	won = true
	var stars := stars_for(hints, pickups)
	Sfx.play("win")
	UiKit.burst(board, board.size / 2.0, Tokens.SUCCESS, 80)
	UiKit.ring(board, board.size / 2.0, Tokens.SUCCESS, minf(board.size.x, board.size.y) * 0.5)
	board.queue_redraw()
	await wait(Motion.NEXT_BUTTON_MAX_DELAY)
	finish(stars, maxi(100, 1000 - pickups * 40 - hints * 200), "ملأت المساحة بـ %d قطع · %d مرات حمل · %d تلميح" % [pieces.size(), pickups, hints])


func _paint() -> void:
	if board.size.x < 60.0 or board.size.y < 60.0 or lv.is_empty():
		return
	var g := _geom()
	var cell: float = g[0]
	var o: Vector2 = g[1]
	for y in h:
		for x in w:
			var r := Rect2(o + Vector2(x, y) * cell, Vector2(cell, cell))
			if holes.has(Vector2i(x, y)):
				board.draw_rect(r.grow(-2), Color(Tokens.BG, 0.9))
				board.draw_line(r.position + Vector2(8, 8), r.end - Vector2(8, 8), Tokens.LINE, 2.0)
			else:
				board.draw_rect(r.grow(-2), Color(Tokens.SURFACE_2, 0.85))
	for j in placed:
		var col := _color(j)
		var sc := 1.0
		var pcen := Vector2.ZERO
		if _settle.has(j):
			sc = 1.12 - 0.12 * float(_settle[j])
			pcen = _piece_center(j)
		for c in cover(j, placed[j]):
			var r2 := Rect2(o + Vector2(c) * cell, Vector2(cell, cell)).grow(-3)
			if sc != 1.0:
				r2 = Rect2(pcen + (r2.position - pcen) * sc, r2.size * sc)
			board.draw_rect(r2, col)
			board.draw_rect(Rect2(r2.position, Vector2(r2.size.x, 4)), col.lightened(0.3))
	if _pressing and selected >= 0:
		var ok := can_place(selected, ghost)
		for c in cover(selected, ghost):
			var r3 := Rect2(o + Vector2(c) * cell, Vector2(cell, cell)).grow(-3)
			board.draw_rect(r3, Color(_color(selected) if ok else Tokens.ERROR, 0.55))
	board.draw_rect(Rect2(o - Vector2(3, 3), Vector2(w, h) * cell + Vector2(6, 6)), Color(accent, 0.6), false, 3.0)
