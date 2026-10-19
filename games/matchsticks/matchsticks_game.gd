extends MiniGame
## Matchsticks: move exactly N sticks so the grid shows exactly `target` unit squares
## and no stick is left loose. Tap a stick to lift it, tap an empty slot to place it.
## Levels come from tools/matchsticks_gen.py, which proves `move` is the minimum.
## Edge keys: "h:x:y" = (x,y)-(x+1,y), "v:x:y" = (x,y)-(x,y+1).

var defs: Array = []
var lv: Dictionary = {}
var gw := 3
var gh := 1
var sticks := {}          # key -> true
var start_sticks := {}
var history: Array = []   # [from_key, to_key]
var selected := ""
var hint_slot := ""
var hints := 0
var moves := 0
var solved := false
var canvas: Control
var info: Label
var instruction: Label
var anim_from := ""     # stick flying from this slot...
var anim_to := ""       # ...to this one
var anim_t := 1.0


func _on_start() -> void:
	var v := frame("أعواد الثقاب")
	info = chip("", "undo")
	instruction = UiKit.label("", Tokens.FS_BODY, Tokens.TEXT, Tokens.font_bold)
	v.add_child(instruction)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(0, 560)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.layout_direction = Control.LAYOUT_DIRECTION_LTR
	canvas.draw.connect(_paint)
	canvas.resized.connect(canvas.queue_redraw)
	canvas.gui_input.connect(_on_input)
	v.add_child(canvas)
	var undo := UiKit.icon_button("undo", "تراجع", UiKit.Variant.SECONDARY, accent)
	undo.pressed.connect(_undo)
	var r := UiKit.icon_button("restart", "إعادة", UiKit.Variant.GHOST)
	r.pressed.connect(_restart)
	var hint := UiKit.icon_button("hint", "تلميح", UiKit.Variant.SECONDARY, accent)
	hint.pressed.connect(_hint)
	v.add_child(action_bar([undo, r, hint]))
	v.add_child(UiKit.label("اضغط عودًا لترفعه، ثم اضغط مكانًا فارغًا لتضعه. لا تترك عودًا خارج مربع.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/matchsticks/levels.json"))
	if p is Dictionary:
		defs = p["levels"]
	if defs.is_empty():
		instruction.text = "تعذّر تحميل المراحل"
		return
	_load_level(level_id)


static func key_of(e: Array) -> String:
	return "%s:%d:%d" % [str(e[0]), int(e[1]), int(e[2])]


func _load_level(id: int) -> void:
	lv = defs[clampi(id - 1, 0, defs.size() - 1)]
	gw = int(lv["w"])
	gh = int(lv["h"])
	start_sticks.clear()
	for e in lv["sticks"]:
		start_sticks[key_of(e)] = true
	sticks = start_sticks.duplicate()
	history.clear()
	selected = ""
	hint_slot = ""
	anim_t = 1.0
	moves = 0
	solved = false
	instruction.text = "حرّك %s لتكوّن %d مربعات بالضبط" % [("عودًا واحدًا" if int(lv["move"]) == 1 else "%d أعواد" % int(lv["move"])), int(lv["target"])]
	_refresh()


func _all_slots() -> Array:
	var out := []
	for y in gh + 1:
		for x in gw:
			out.append("h:%d:%d" % [x, y])
	for y in gh:
		for x in gw + 1:
			out.append("v:%d:%d" % [x, y])
	return out


func _square_count(st: Dictionary) -> Array:
	var count := 0
	var used := {}
	for y in gh:
		for x in gw:
			var e := ["h:%d:%d" % [x, y], "h:%d:%d" % [x, y + 1], "v:%d:%d" % [x, y], "v:%d:%d" % [x + 1, y]]
			if st.has(e[0]) and st.has(e[1]) and st.has(e[2]) and st.has(e[3]):
				count += 1
				for k in e:
					used[k] = true
	return [count, used.size() == st.size()]


func _is_solved() -> bool:
	var r := _square_count(sticks)
	return int(r[0]) == int(lv["target"]) and bool(r[1])


func _geom() -> Array:
	var cell := minf((canvas.size.x - 60.0) / gw, (canvas.size.y - 60.0) / gh)
	cell = minf(cell, 200.0)
	var origin := (canvas.size - Vector2(gw, gh) * cell) / 2.0
	return [cell, origin]


func _ends(k: String) -> Array:
	var parts := k.split(":")
	var a := Vector2(int(parts[1]), int(parts[2]))
	var b := a + (Vector2(1, 0) if parts[0] == "h" else Vector2(0, 1))
	var g := _geom()
	return [g[1] + a * float(g[0]), g[1] + b * float(g[0])]


func _slot_at(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	var g := _geom()
	for k in _all_slots():
		var e := _ends(k)
		var mid: Vector2 = (e[0] + e[1]) / 2.0
		var d := pos.distance_to(mid)
		if d < best_d:
			best_d = d
			best = k
	return best if best_d < float(g[0]) * 0.45 else ""


func _on_input(e: InputEvent) -> void:
	# Touch arrives as emulated mouse too; reading only mouse avoids double taps.
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if solved or defs.is_empty():
		return
	var k := _slot_at(e.position)
	if k == "":
		return
	if sticks.has(k):
		selected = "" if selected == k else k
		Sfx.play("tap")
	elif selected != "":
		if moves >= int(lv["move"]):
			Sfx.play("wrong")
			instruction.text = "انتهت حركاتك. اضغط تراجع أو إعادة."
			return
		sticks.erase(selected)
		sticks[k] = true
		history.append([selected, k])
		_fly(selected, k)
		moves += 1
		selected = ""
		hint_slot = ""
		Sfx.play("pop")
		Settings.vibrate(10)
		_refresh()
		_check()
		return
	_refresh()


func _check() -> void:
	if _is_solved():
		solved = true
		Sfx.play("win")
		var g := _geom()
		UiKit.burst(canvas, g[1] + Vector2(gw, gh) * float(g[0]) / 2.0, Tokens.SUCCESS, 60)
		await wait(1.0)
		finish(3 if hints == 0 else 2, maxi(100, 800 - hints * 200), "حللت اللغز" + ("" if hints == 0 else " بمساعدة التلميح"))
	elif moves >= int(lv["move"]):
		Sfx.play("wrong")
		instruction.text = "ليس الحل بعد. اضغط تراجع وجرّب عودًا آخر."


func _undo() -> void:
	if solved or history.is_empty():
		return
	var last: Array = history.pop_back()
	sticks.erase(last[1])
	sticks[last[0]] = true
	_fly(str(last[1]), str(last[0]))
	moves -= 1
	selected = ""
	Sfx.play("whoosh")
	_load_instruction()
	_refresh()


func _load_instruction() -> void:
	instruction.text = "حرّك %s لتكوّن %d مربعات بالضبط" % [("عودًا واحدًا" if int(lv["move"]) == 1 else "%d أعواد" % int(lv["move"])), int(lv["target"])]


## Shows the next move of the reference solution. If the player went another way,
## the board is reset first (the hint only knows one solution).
func _hint() -> void:
	if solved or defs.is_empty():
		return
	var sol: Array = lv.get("solution", [])
	var on_track := moves < sol.size()
	for i in moves:
		if i >= sol.size() or key_of(sol[i][0]) != str(history[i][0]) or key_of(sol[i][1]) != str(history[i][1]):
			on_track = false
	if not on_track:
		var h := hints
		_load_level(level_id)
		hints = h
	if moves >= sol.size():
		return
	hints += 1
	selected = key_of(sol[moves][0])
	hint_slot = key_of(sol[moves][1])
	Sfx.play("pop")
	_refresh()


func _restart() -> void:
	var h := hints
	_load_level(level_id)
	hints = h
	Sfx.play("whoosh")


func _refresh() -> void:
	UiKit.set_chip(info, "%d/%d" % [moves, int(lv.get("move", 1))])
	canvas.queue_redraw()


## The moved stick flies along an arc to its new slot.
func _fly(from_key: String, to_key: String) -> void:
	anim_from = from_key
	anim_to = to_key
	if Motion.reduce_motion:
		anim_t = 1.0
		return
	anim_t = 0.0
	var tw := create_tween()
	tw.tween_method(func(t: float):
		anim_t = t
		canvas.queue_redraw(), 0.0, 1.0, Motion.BASE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _draw_stick(a: Vector2, b: Vector2, w: float, lifted: bool) -> void:
	var dir := (b - a).normalized()
	a += dir * w
	b -= dir * w
	var lift := Vector2(0, -8) if lifted else Vector2.ZERO
	canvas.draw_line(a + Vector2(3, 5), b + Vector2(3, 5), Color(0, 0, 0, 0.35 if not lifted else 0.22), w, true)
	a += lift
	b += lift
	var wood := Tokens.COIN if lifted else Color("#E2B57A")
	canvas.draw_line(a, b, wood.darkened(0.3), w + 3.0, true)
	canvas.draw_line(a, b, wood, w, true)
	var n := Vector2(-dir.y, dir.x) * (w * 0.22)
	canvas.draw_line(a - n, b - n, wood.lightened(0.3), maxf(w * 0.22, 2.0), true)
	canvas.draw_circle(b, w * 0.95, Color("#B83B3B"))
	canvas.draw_circle(b - n * 0.8, w * 0.45, Color("#FF7A6E"))


func _paint() -> void:
	if canvas.size.x < 60.0 or canvas.size.y < 60.0:
		return   # not laid out yet (first frame): avoid negative sizes
	if defs.is_empty():
		return
	var g := _geom()
	var cell: float = g[0]
	var w := clampf(cell * 0.09, 8.0, 16.0)
	for k in _all_slots():
		if sticks.has(k):
			continue
		var e := _ends(k)
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var dir := (b - a).normalized()
		if k == hint_slot:
			canvas.draw_line(a + dir * w, b - dir * w, Color(Tokens.SUCCESS, 0.75), w, true)
		else:
			canvas.draw_line(a + dir * w, b - dir * w, Color(Tokens.LINE, 0.9), 3.0, true)
	for k in sticks:
		var e := _ends(str(k))
		if str(k) == anim_to and anim_t < 1.0:
			var f := _ends(anim_from)
			var arc := Vector2(0, -sin(anim_t * PI) * cell * 0.35)
			_draw_stick((f[0] as Vector2).lerp(e[0], anim_t) + arc, (f[1] as Vector2).lerp(e[1], anim_t) + arc, w, true)
		else:
			_draw_stick(e[0], e[1], w, str(k) == selected)
