extends MiniGame
## Escape room: tap objects in a drawn room to look, search, use items and open locks
## (3-digit codes, 4-symbol locks, keys). Every clue is inside the same room. Paid hints
## (coins) point at the next unsolved puzzle. Rooms live in content/escape/levels.json and
## tools/escape_check.py proves each one can be escaped from its own clues.
## Room space is 100 x 110 units (wall above y=70, floor below), scaled to fit the board.

const ROOM_W := 100.0
const ROOM_H := 110.0
const SYMS := ["sun", "moon", "star", "drop", "triangle", "diamond"]

var data: Dictionary = {}
var room: Dictionary = {}
var objs := {}                 # id -> object dict
var order: Array = []          # draw / hit-test order
var visible_ids := {}
var opened := {}               # puzzle solved / searched
var inventory: Array = []
var bought_hints := {}         # hint target id -> true (re-shown for free)
var mistakes := 0
var elapsed := 0.0
var won := false
var hint_cost := 15
var board: Control
var inv_row: HBoxContainer
var status: Label
var mistakes_chip: Label
var coins_chip: Label
var hint_btn: Button
var overlay: Control
var _code := [0, 0, 0]
var _code_labels: Array = []
var _sym_input: Array = []
var _sym_slots: Array = []
var _glow := 0.0
var _tap_id := ""
var _tap_t := 0.0
var _new_item := ""


func _on_start() -> void:
	var v := frame("غرفة الهروب")
	mistakes_chip = chip("", "close", Tokens.ERROR)
	coins_chip = chip("", "coin", Tokens.COIN)
	board = Control.new()
	board.custom_minimum_size = Vector2(0, 640)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	board.draw.connect(_paint)
	board.resized.connect(board.queue_redraw)
	board.gui_input.connect(_on_board_input)
	v.add_child(board)
	status = UiKit.label("", Tokens.FS_CAPTION, Tokens.TEXT)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status)
	inv_row = UiKit.hbox(Tokens.SP_S)
	inv_row.custom_minimum_size = Vector2(0, 64)
	v.add_child(inv_row)
	hint_btn = UiKit.icon_button("hint", "تلميح", UiKit.Variant.SECONDARY, Tokens.COIN)
	hint_btn.pressed.connect(_hint)
	v.add_child(action_bar([hint_btn]))
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/escape/levels.json"))
	if not (p is Dictionary) or (p.get("rooms", []) as Array).is_empty():
		title_label.text = "تعذّر تحميل الغرفة"
		hint_btn.disabled = true
		return
	data = p
	hint_cost = int(data.get("hint_cost", 15))
	var rooms: Array = data["rooms"]
	room = rooms[clampi(level_id - 1, 0, rooms.size() - 1)]
	_load_room()


func _load_room() -> void:
	title_label.text = "غرفة الهروب · %s" % room["name"]
	objs.clear()
	order.clear()
	visible_ids.clear()
	for o in room["objects"]:
		objs[o["id"]] = o
		order.append(o["id"])
		if not bool(o.get("hidden", false)):
			visible_ids[o["id"]] = true
	_say(str(room.get("intro", "")))
	_refresh()


func _refresh() -> void:
	UiKit.set_chip(mistakes_chip, "%d أخطاء" % mistakes, false)
	UiKit.set_chip(coins_chip, str(coins()), false)
	hint_btn.text = "تلميح · %d عملة" % hint_cost
	for c in inv_row.get_children():
		c.queue_free()
	var lbl := UiKit.label("معك:" if not inventory.is_empty() else "لا تحمل شيئًا بعد.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	inv_row.add_child(lbl)
	for it in inventory:
		var ch := _item_chip(str(it))
		inv_row.add_child(ch)
		if str(it) == _new_item and _anim_ok():
			ch.modulate.a = 0.0
			_pop_later(ch)
	_new_item = ""
	board.queue_redraw()


func _item_chip(id: String) -> Control:
	var info: Dictionary = room["items"].get(id, {})
	var h := UiKit.hbox(Tokens.SP_XS)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(44, 44)
	var kind := str(info.get("icon", "key"))
	ic.draw.connect(func(): draw_item(ic, kind, Rect2(Vector2.ZERO, ic.size)))
	h.add_child(ic)
	h.add_child(UiKit.label(str(info.get("name", id)), Tokens.FS_CAPTION, Tokens.COIN, Tokens.font_bold))
	return h


func _say(text: String, color := Tokens.TEXT) -> void:
	status.text = text
	status.add_theme_color_override("font_color", color)


func _anim_ok() -> bool:
	return not Motion.reduce_motion and Quality.tier() != "low"


func _process(delta: float) -> void:
	if won or room.is_empty():
		return
	elapsed += delta
	if Quality.fancy():   # soft glow on unsolved puzzles; no per-frame redraw on low quality
		_glow = fmod(_glow + delta, 2.0)
		board.queue_redraw()


# ---------------- geometry / input ----------------
func _geom() -> Array:
	var s := minf(board.size.x / ROOM_W, board.size.y / ROOM_H)
	var o := (board.size - Vector2(ROOM_W, ROOM_H) * s) / 2.0
	return [s, o]


func _rect_px(o: Dictionary) -> Rect2:
	var g := _geom()
	var s: float = g[0]
	var r: Array = o["rect"]
	return Rect2(g[1] + Vector2(float(r[0]), float(r[1])) * s, Vector2(float(r[2]), float(r[3])) * s)


func _on_board_input(e: InputEvent) -> void:
	if overlay != null or won or room.is_empty():
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		for i in range(order.size() - 1, -1, -1):
			var id: String = order[i]
			if visible_ids.has(id) and _rect_px(objs[id]).grow(6.0).has_point(e.position):
				_interact(id)
				return


# ---------------- painting ----------------
func _paint() -> void:
	if board.size.x < 60.0 or board.size.y < 60.0 or room.is_empty():
		return
	var g := _geom()
	var s: float = g[0]
	var o: Vector2 = g[1]
	var wall := Rect2(o, Vector2(ROOM_W, 70.0) * s)
	var floor_r := Rect2(o + Vector2(0, 70.0 * s), Vector2(ROOM_W, ROOM_H - 70.0) * s)
	board.draw_rect(wall, Tokens.SURFACE_1)
	board.draw_rect(Rect2(wall.position, Vector2(wall.size.x, 6)), Color(accent, 0.25))
	board.draw_rect(floor_r, Tokens.SURFACE_2.darkened(0.25))
	for k in 6:
		var y := floor_r.position.y + floor_r.size.y * (k + 1) / 7.0
		board.draw_line(Vector2(floor_r.position.x, y), Vector2(floor_r.end.x, y), Color(Tokens.LINE, 0.6), 2.0)
	board.draw_line(floor_r.position, Vector2(floor_r.end.x, floor_r.position.y), Tokens.LINE.lightened(0.2), 4.0)
	for id in order:
		if not visible_ids.has(id):
			continue
		var ob: Dictionary = objs[id]
		var r := _rect_px(ob)
		var t := str(ob["action"]["type"])
		if t != "look" and not opened.has(id) and Quality.fancy():
			var a := 0.10 + 0.08 * sin(_glow / 2.0 * TAU)
			board.draw_rect(r.grow(5.0), Color(Tokens.COIN, a), false, 3.0)
		paint_object(board, ob, r, opened.has(id))
		if id == _tap_id and _tap_t > 0.0:
			board.draw_rect(r.grow(4.0), Color(1, 1, 1, 0.22 * _tap_t))


static func _col(i: int) -> Color:
	return [Tokens.ERROR, Tokens.COIN, Tokens.SUCCESS][posmod(i, 3)]


static func _wood() -> Color:
	return Tokens.COIN.darkened(0.55)


static func _teal() -> Color:
	return Tokens.WORLD_COLORS[Tokens.World.PUZZLES]


## Draws one room object into rect r of any CanvasItem (room board and zoomed panel).
static func paint_object(ci: CanvasItem, ob: Dictionary, r: Rect2, is_open: bool) -> void:
	var c := r.get_center()
	var m := minf(r.size.x, r.size.y)
	var lw := maxf(2.0, m * 0.04)
	match str(ob["kind"]):
		"door":
			ci.draw_rect(r, _wood())
			ci.draw_rect(r, _wood().darkened(0.4), false, lw)
			if is_open:
				ci.draw_rect(r.grow(-lw * 2), Tokens.COIN.lightened(0.3))
				ci.draw_rect(Rect2(r.position + Vector2(lw * 2, lw * 2), Vector2(r.size.x * 0.25, r.size.y - lw * 4)), _wood().lightened(0.1))
			else:
				for k in 2:
					ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.15, r.size.y * (0.08 + k * 0.46)), Vector2(r.size.x * 0.7, r.size.y * 0.38)), _wood().lightened(0.12), false, lw * 0.6)
				var knob := Vector2(r.position.x + r.size.x * 0.18, c.y)
				ci.draw_circle(knob, m * 0.07, Tokens.COIN)
				var t := str(ob["action"]["type"])
				var pad := Rect2(Vector2(r.end.x - r.size.x * 0.42, c.y - r.size.y * 0.09), Vector2(r.size.x * 0.3, r.size.y * 0.18))
				if t == "code":
					ci.draw_rect(pad, Tokens.SURFACE_2)
					for k in 9:
						ci.draw_circle(pad.position + Vector2((k % 3 + 0.5) * pad.size.x / 3.0, (floori(k / 3.0) + 0.5) * pad.size.y / 3.0), pad.size.x * 0.09, Tokens.TEXT_MUTED)
				elif t == "symbols":
					ci.draw_rect(pad, Tokens.SURFACE_2)
					for k in 4:
						ci.draw_circle(pad.position + Vector2(pad.size.x * 0.5, (k + 0.5) * pad.size.y / 4.0), pad.size.x * 0.14, Tokens.TEXT_MUTED)
				elif t == "item" and str(ob["action"].get("needs", "")) == "card":
					ci.draw_rect(pad, Tokens.SURFACE_2)
					ci.draw_rect(Rect2(pad.position + pad.size * Vector2(0.2, 0.42), pad.size * Vector2(0.6, 0.16)), Tokens.BG)
				else:
					ci.draw_circle(Vector2(knob.x, knob.y + m * 0.14), m * 0.035, Tokens.BG)
		"clock":
			var rad := m * 0.46
			ci.draw_circle(c, rad, _wood())
			ci.draw_circle(c, rad * 0.86, Tokens.TEXT)
			for h in 12:
				var a := h / 12.0 * TAU - PI / 2.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * rad * 0.72, c + Vector2(cos(a), sin(a)) * rad * 0.82, Tokens.BG, maxf(1.5, lw * (0.9 if h % 3 == 0 else 0.4)))
			if m > 90.0:
				for h in [12, 3, 6, 9]:
					var a2: float = (int(h) % 12) / 12.0 * TAU - PI / 2.0
					var fs := int(rad * 0.22)
					ci.draw_string(Tokens.font_bold, c + Vector2(cos(a2), sin(a2)) * rad * 0.56 + Vector2(-fs * 0.6, fs * 0.38), str(h), HORIZONTAL_ALIGNMENT_CENTER, fs * 1.2, fs, Tokens.BG)
			var ha := float(ob.get("hour", 12)) / 12.0 * TAU - PI / 2.0
			ci.draw_line(c, c + Vector2(0, -rad * 0.72), Tokens.TEXT_MUTED.darkened(0.3), maxf(1.5, lw * 0.5), true)
			ci.draw_line(c, c + Vector2(cos(ha), sin(ha)) * rad * 0.48, Tokens.BG, maxf(2.5, lw * 1.2), true)
			ci.draw_circle(c, lw * 0.9, Tokens.ERROR)
		"frame":
			ci.draw_rect(r, _wood())
			var inner := r.grow(-maxf(3.0, m * 0.1))
			ci.draw_rect(inner, Tokens.BG.lerp(Color(0.1, 0.15, 0.35), 0.5))
			var n := int(ob.get("stars", 0))
			var cols := ceili(sqrt(float(n) * inner.size.x / maxf(inner.size.y, 1.0)))
			cols = maxi(cols, 1)
			var rows := ceili(float(n) / cols)
			for k in n:
				var cx := inner.position.x + (k % cols + 0.5) * inner.size.x / cols
				var cy := inner.position.y + (floori(k / float(cols)) + 0.5) * inner.size.y / maxf(rows, 1)
				draw_symbol(ci, "star", Vector2(cx, cy), minf(inner.size.x / cols, inner.size.y / maxf(rows, 1)) * 0.32, Tokens.COIN)
		"plant":
			var pot := PackedVector2Array([Vector2(r.position.x + r.size.x * 0.2, r.end.y - r.size.y * 0.35), Vector2(r.end.x - r.size.x * 0.2, r.end.y - r.size.y * 0.35), Vector2(r.end.x - r.size.x * 0.3, r.end.y), Vector2(r.position.x + r.size.x * 0.3, r.end.y)])
			for k in 5:
				var a := -PI / 2.0 + (k - 2) * 0.45
				var tip := Vector2(c.x, r.end.y - r.size.y * 0.35) + Vector2(cos(a), sin(a)) * r.size.y * 0.6
				ci.draw_line(Vector2(c.x, r.end.y - r.size.y * 0.35), tip, Tokens.SUCCESS.darkened(0.3), lw * 2.2, true)
				ci.draw_circle(tip, m * 0.16, Tokens.SUCCESS.darkened(0.15 + k * 0.05))
			ci.draw_colored_polygon(pot, Tokens.ERROR.darkened(0.35))
		"candles":
			var n2 := int(ob.get("count", 1))
			var w := r.size.x / (n2 * 2.0)
			for k in n2:
				var x := r.position.x + w * (k * 2 + 0.5)
				var body := Rect2(Vector2(x, r.position.y + r.size.y * 0.4), Vector2(w, r.size.y * 0.6))
				ci.draw_rect(body, Tokens.TEXT)
				var fl := Vector2(x + w / 2.0, r.position.y + r.size.y * 0.25)
				ci.draw_colored_polygon(PackedVector2Array([fl + Vector2(0, -r.size.y * 0.22), fl + Vector2(w * 0.35, 0), fl + Vector2(0, r.size.y * 0.12), fl + Vector2(-w * 0.35, 0)]), Tokens.COIN)
		"desk":
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.25)), _wood().lightened(0.15))
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.04, r.size.y * 0.25), Vector2(r.size.x * 0.08, r.size.y * 0.75)), _wood())
			ci.draw_rect(Rect2(Vector2(r.end.x - r.size.x * 0.12, r.position.y + r.size.y * 0.25), Vector2(r.size.x * 0.08, r.size.y * 0.75)), _wood())
			var dr := Rect2(r.position + Vector2(r.size.x * 0.3, r.size.y * (0.3 if not is_open else 0.45)), Vector2(r.size.x * 0.4, r.size.y * 0.4))
			ci.draw_rect(dr, _wood().lightened(0.05))
			ci.draw_rect(dr, _wood().darkened(0.4), false, lw * 0.6)
			ci.draw_circle(dr.get_center(), m * 0.06, Tokens.COIN)
		"note":
			ci.draw_rect(r, Tokens.TEXT)
			for k in 3:
				var y := r.position.y + r.size.y * (0.3 + k * 0.22)
				ci.draw_line(Vector2(r.position.x + r.size.x * 0.15, y), Vector2(r.end.x - r.size.x * 0.15, y), Tokens.TEXT_MUTED, maxf(1.0, lw * 0.4))
		"drawing":
			ci.draw_rect(r, Tokens.TEXT.darkened(0.15))
			var syms: Array = ob.get("syms", [])
			for k in syms.size():
				var cc := Vector2(r.end.x - (k + 0.5) * r.size.x / syms.size(), r.position.y + r.size.y * 0.42)
				draw_symbol(ci, str(syms[k]), cc, minf(r.size.x / syms.size(), r.size.y) * 0.28, Tokens.BG)
				if m > 40.0:
					var fs := int(clampf(r.size.y * 0.18, 10.0, 34.0))
					ci.draw_string(Tokens.font_bold, cc + Vector2(-fs, r.size.y * 0.42), str(k + 1), HORIZONTAL_ALIGNMENT_CENTER, fs * 2.0, fs, Tokens.ERROR)
		"safe":
			ci.draw_rect(r, Tokens.TEXT_MUTED.darkened(0.35))
			ci.draw_rect(r, Tokens.BG, false, lw)
			if is_open:
				ci.draw_rect(r.grow(-lw * 2), Tokens.BG)
				ci.draw_rect(Rect2(r.position - Vector2(r.size.x * 0.25, 0), Vector2(r.size.x * 0.25, r.size.y)), Tokens.TEXT_MUTED.darkened(0.2))
			else:
				ci.draw_circle(c, m * 0.24, Tokens.TEXT_MUTED)
				ci.draw_circle(c, m * 0.08, Tokens.BG)
				for k in 3:
					ci.draw_rect(Rect2(Vector2(r.position.x + r.size.x * (0.2 + k * 0.22), r.end.y - r.size.y * 0.2), Vector2(r.size.x * 0.16, r.size.y * 0.1)), Tokens.BG)
		"shelf":
			ci.draw_rect(r, _wood().darkened(0.2))
			var books: Array = ob.get("books", [])
			var bw := r.size.x / (books.size() + 1)
			var base_y := r.end.y - r.size.y * 0.06
			for k in books.size():
				var b: Dictionary = books[k]
				var bh := r.size.y * 0.85 * float(b["h"]) / 10.0
				var br := Rect2(Vector2(r.position.x + bw * (k + 0.5), base_y - bh), Vector2(bw * 0.85, bh))
				var bc := _col(int(b["c"]))
				ci.draw_rect(br, bc.darkened(0.15))
				ci.draw_rect(br, bc.darkened(0.5), false, maxf(1.0, lw * 0.4))
				for st in maxi(0, 2 - int(b["c"])):   # bands: red 2, yellow 1, green 0 (colorblind help)
					ci.draw_rect(Rect2(br.position + Vector2(0, br.size.y * (0.08 + st * 0.08)), Vector2(br.size.x, maxf(1.0, br.size.y * 0.04))), Tokens.BG)
				if str(b["sym"]) != "":
					draw_symbol(ci, str(b["sym"]), Vector2(br.get_center().x, br.position.y + br.size.y * 0.6), br.size.x * 0.32, Tokens.TEXT)
			ci.draw_rect(Rect2(Vector2(r.position.x, base_y), Vector2(r.size.x, r.size.y * 0.06)), _wood())
		"sign":
			ci.draw_rect(r, Tokens.COIN.darkened(0.2))
			ci.draw_rect(r, Tokens.COIN.darkened(0.55), false, lw)
			for k in 2:
				var y2 := r.position.y + r.size.y * (0.38 + k * 0.26)
				ci.draw_line(Vector2(r.position.x + r.size.x * 0.12, y2), Vector2(r.end.x - r.size.x * 0.12, y2), Tokens.COIN.darkened(0.6), maxf(1.0, lw * 0.5))
		"lamps":
			var lit: Array = ob.get("lit", [])
			for k in lit.size():
				var lc := Vector2(r.position.x + (k + 0.5) * r.size.x / lit.size(), c.y)
				var on := bool(lit[k])
				if on:
					ci.draw_circle(lc, m * 0.48, Color(Tokens.COIN, 0.25))
				ci.draw_circle(lc, m * 0.28, Tokens.COIN if on else Tokens.LINE)
				ci.draw_rect(Rect2(lc + Vector2(-m * 0.12, m * 0.25), Vector2(m * 0.24, m * 0.22)), Tokens.TEXT_MUTED.darkened(0.4))
		"chest":
			var lid_h := r.size.y * 0.35
			ci.draw_rect(Rect2(r.position + Vector2(0, lid_h), Vector2(r.size.x, r.size.y - lid_h)), _wood())
			if is_open:
				ci.draw_rect(Rect2(r.position + Vector2(0, lid_h * 0.2), Vector2(r.size.x, lid_h * 0.8)), Tokens.BG)
				ci.draw_rect(Rect2(r.position - Vector2(0, lid_h * 0.6), Vector2(r.size.x, lid_h * 0.7)), _wood().lightened(0.1))
			else:
				ci.draw_rect(Rect2(r.position, Vector2(r.size.x, lid_h)), _wood().lightened(0.1))
				ci.draw_rect(Rect2(Vector2(c.x - m * 0.12, r.position.y + lid_h * 0.6), Vector2(m * 0.24, m * 0.3)), Tokens.COIN)
				if str(ob["action"]["type"]) == "symbols":
					for k in 4:
						ci.draw_circle(Vector2(r.position.x + r.size.x * (0.12 + k * 0.08), r.end.y - r.size.y * 0.25), m * 0.05, Tokens.TEXT_MUTED)
			ci.draw_rect(r, _wood().darkened(0.45), false, lw * 0.6)
		"cabinet":
			ci.draw_rect(r, _wood())
			if is_open:
				ci.draw_rect(r.grow(-lw * 1.5), Tokens.BG)
				ci.draw_line(Vector2(r.position.x + lw * 2, c.y), Vector2(r.end.x - lw * 2, c.y), _wood(), lw)
			else:
				ci.draw_line(Vector2(c.x, r.position.y), Vector2(c.x, r.end.y), _wood().darkened(0.45), lw * 0.6)
				ci.draw_circle(Vector2(c.x - m * 0.08, c.y), m * 0.04, Tokens.COIN)
				ci.draw_circle(Vector2(c.x + m * 0.08, c.y), m * 0.04, Tokens.COIN)
				if str(ob["action"]["type"]) == "symbols":
					var pr := Rect2(Vector2(c.x - r.size.x * 0.3, r.position.y + r.size.y * 0.15), Vector2(r.size.x * 0.6, r.size.y * 0.12))
					ci.draw_rect(pr, Tokens.SURFACE_2)
					for k in 4:
						ci.draw_circle(pr.position + Vector2((k + 0.5) * pr.size.x / 4.0, pr.size.y / 2.0), pr.size.y * 0.25, Tokens.TEXT_MUTED)
			ci.draw_rect(r, _wood().darkened(0.45), false, lw * 0.6)
		"board":
			ci.draw_rect(r, _wood())
			var inner2 := r.grow(-maxf(3.0, m * 0.06))
			ci.draw_rect(inner2, Tokens.SUCCESS.darkened(0.75))
			var pairs: Array = ob.get("pairs", [])
			for k in pairs.size():
				var cc := Vector2(inner2.end.x - (k + 0.5) * inner2.size.x / pairs.size(), inner2.position.y + inner2.size.y * 0.38)
				draw_symbol(ci, str(pairs[k][0]), cc, minf(inner2.size.x / pairs.size(), inner2.size.y) * 0.24, Tokens.TEXT)
				var fs2 := int(clampf(inner2.size.y * 0.2, 8.0, 40.0))
				ci.draw_string(Tokens.font_bold, cc + Vector2(-fs2, inner2.size.y * 0.42), str(pairs[k][1]), HORIZONTAL_ALIGNMENT_CENTER, fs2 * 2.0, fs2, Tokens.COIN)
		"poster":
			ci.draw_rect(r, Tokens.BG.lerp(Color(0.1, 0.12, 0.3), 0.6))
			ci.draw_rect(r, Tokens.LINE.lightened(0.3), false, lw * 0.6)
			var pp: Array = ob.get("pairs", [])
			for k in pp.size():
				var y3 := r.position.y + (k + 0.5) * r.size.y / pp.size()
				var sz := r.size.y / pp.size() * 0.32
				draw_symbol(ci, str(pp[k][0]), Vector2(r.end.x - r.size.x * 0.14, y3), sz, Tokens.TEXT)
				for d in int(pp[k][1]):
					ci.draw_circle(Vector2(r.end.x - r.size.x * 0.3 - d * r.size.x * 0.085, y3), maxf(1.5, sz * 0.32), Tokens.COIN)
		"window":
			ci.draw_rect(r, Tokens.TEXT_MUTED.darkened(0.2))
			var sky := r.grow(-maxf(3.0, m * 0.06))
			ci.draw_rect(sky, Tokens.BG.darkened(0.3))
			var np := int(ob.get("planets", 0))
			for k in np:
				var px := sky.position.x + sky.size.x * (0.12 + 0.76 * fmod(k * 0.618, 1.0))
				var py := sky.position.y + sky.size.y * (0.2 + 0.6 * fmod(k * 0.377 + 0.1, 1.0))
				ci.draw_circle(Vector2(px, py), m * (0.06 + 0.02 * (k % 3)), Tokens.WORLD_COLORS.values()[k % 4])
			ci.draw_line(Vector2(c.x, sky.position.y), Vector2(c.x, sky.end.y), Tokens.TEXT_MUTED.darkened(0.2), lw * 0.5)
		"flasks":
			for k in 3:
				var fx := r.position.x + (k + 0.5) * r.size.x / 3.0
				var fr := r.size.x / 7.0
				ci.draw_circle(Vector2(fx, r.end.y - fr), fr, Tokens.WORLD_COLORS.values()[k])
				ci.draw_rect(Rect2(Vector2(fx - fr * 0.35, r.position.y), Vector2(fr * 0.7, r.size.y - fr * 1.8)), Color(Tokens.TEXT, 0.6))
		"rug":
			var rr := r if not is_open else Rect2(r.position + Vector2(r.size.x * 0.08, 0), r.size)
			ci.draw_rect(rr, Tokens.ERROR.darkened(0.45))
			ci.draw_rect(rr.grow(-lw * 1.5), Tokens.COIN.darkened(0.4), false, lw * 0.6)
			if is_open:
				ci.draw_colored_polygon(PackedVector2Array([rr.position, rr.position + Vector2(rr.size.x * 0.2, 0), rr.position + Vector2(0, rr.size.y * 0.6)]), Tokens.ERROR.darkened(0.2))
		"vase":
			ci.draw_circle(Vector2(c.x, r.position.y + r.size.y * 0.62), r.size.x * 0.45, _teal().darkened(0.3))
			ci.draw_rect(Rect2(Vector2(c.x - r.size.x * 0.18, r.position.y), Vector2(r.size.x * 0.36, r.size.y * 0.4)), _teal().darkened(0.3))
			ci.draw_line(Vector2(c.x - r.size.x * 0.3, r.position.y + r.size.y * 0.62), Vector2(c.x + r.size.x * 0.3, r.position.y + r.size.y * 0.62), _teal().lightened(0.3), lw)
		"sofa":
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.3), Vector2(r.size.x, r.size.y * 0.5)), _teal().darkened(0.5))
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.45)), _teal().darkened(0.35))
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.8), Vector2(r.size.x * 0.08, r.size.y * 0.2)), _wood())
			ci.draw_rect(Rect2(Vector2(r.end.x - r.size.x * 0.08, r.position.y + r.size.y * 0.8), Vector2(r.size.x * 0.08, r.size.y * 0.2)), _wood())
		"vent":
			ci.draw_rect(r, Tokens.TEXT_MUTED.darkened(0.3))
			if is_open:
				ci.draw_rect(r.grow(-lw), Tokens.BG.darkened(0.4))
			else:
				for k in 5:
					var y4 := r.position.y + (k + 1) * r.size.y / 6.0
					ci.draw_line(Vector2(r.position.x + lw * 2, y4), Vector2(r.end.x - lw * 2, y4), Tokens.BG, lw * 0.7)
				for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
					ci.draw_circle((corner as Vector2).lerp(c, 0.12), maxf(1.5, m * 0.05), Tokens.COIN.darkened(0.3))
		"pipes":
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.2), Vector2(r.size.x, r.size.y * 0.3)), Tokens.TEXT_MUTED.darkened(0.45))
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.6), Vector2(r.size.x, r.size.y * 0.3)), Tokens.TEXT_MUTED.darkened(0.55))
			for k in 4:
				ci.draw_rect(Rect2(Vector2(r.position.x + r.size.x * (0.1 + k * 0.25), r.position.y), Vector2(r.size.x * 0.03, r.size.y)), Tokens.COIN.darkened(0.6))
		"barrel":
			ci.draw_rect(r, _wood())
			for k in 3:
				var y5 := r.position.y + r.size.y * (0.15 + k * 0.35)
				ci.draw_rect(Rect2(Vector2(r.position.x, y5), Vector2(r.size.x, r.size.y * 0.06)), Tokens.TEXT_MUTED.darkened(0.4))
			ci.draw_rect(r, _wood().darkened(0.45), false, lw * 0.6)
		"toolbox":
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.3), Vector2(r.size.x, r.size.y * 0.7)), Tokens.ERROR.darkened(0.25))
			ci.draw_rect(Rect2(Vector2(c.x - r.size.x * 0.2, r.position.y), Vector2(r.size.x * 0.4, r.size.y * 0.3)), Tokens.TEXT_MUTED.darkened(0.3), false, lw)
			if is_open:
				ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.05, r.size.y * 0.35), Vector2(r.size.x * 0.9, r.size.y * 0.2)), Tokens.BG)
			else:
				ci.draw_rect(Rect2(Vector2(c.x - m * 0.1, r.position.y + r.size.y * 0.45), Vector2(m * 0.2, m * 0.25)), Tokens.COIN)
		_:
			ci.draw_rect(r, Tokens.SURFACE_2)


## Shared symbol set: sun, moon, star, drop, triangle, diamond.
static func draw_symbol(ci: CanvasItem, sym: String, c: Vector2, r: float, col: Color) -> void:
	match sym:
		"sun":
			ci.draw_circle(c, r * 0.5, col)
			for k in 8:
				var a := k * TAU / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.66, c + Vector2(cos(a), sin(a)) * r, col, maxf(1.5, r * 0.16), true)
		"moon":
			var pts := PackedVector2Array()
			for k in 15:
				var a := deg_to_rad(50.0 + 260.0 * k / 14.0)
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			var c2 := c + Vector2(r * 0.45, 0)
			for k in 15:
				var a2 := deg_to_rad(284.1 - 208.2 * k / 14.0)
				pts.append(c2 + Vector2(cos(a2), sin(a2)) * r * 0.79)
			ci.draw_colored_polygon(pts, col)
		"star":
			var sp := PackedVector2Array()
			for k in 10:
				var a3 := -PI / 2.0 + k * PI / 5.0
				sp.append(c + Vector2(cos(a3), sin(a3)) * (r if k % 2 == 0 else r * 0.45))
			ci.draw_colored_polygon(sp, col)
		"drop":
			var dp := PackedVector2Array([c + Vector2(0, -r)])
			var cc := c + Vector2(0, r * 0.3)
			for k in 13:
				var a4 := deg_to_rad(-30.0 + 240.0 * k / 12.0)
				dp.append(cc + Vector2(cos(a4), sin(a4)) * r * 0.62)
			ci.draw_colored_polygon(dp, col)
		"triangle":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.95, r * 0.75), c + Vector2(-r * 0.95, r * 0.75)]), col)
		"diamond":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]), col)
		_:
			ci.draw_circle(c, r * 0.3, col)


static func draw_item(ci: CanvasItem, kind: String, r: Rect2) -> void:
	var c := r.get_center()
	var m := minf(r.size.x, r.size.y)
	match kind:
		"card":
			ci.draw_rect(Rect2(c - Vector2(m * 0.42, m * 0.28), Vector2(m * 0.84, m * 0.56)), Tokens.TEXT)
			ci.draw_rect(Rect2(c - Vector2(m * 0.42, m * 0.12), Vector2(m * 0.84, m * 0.12)), Tokens.BG)
		"screwdriver":
			ci.draw_line(c + Vector2(-m * 0.4, m * 0.4), c + Vector2(m * 0.05, -m * 0.05), Tokens.ERROR, m * 0.18, true)
			ci.draw_line(c + Vector2(m * 0.05, -m * 0.05), c + Vector2(m * 0.4, -m * 0.4), Tokens.TEXT_MUTED, m * 0.07, true)
		_:
			var big := kind == "key_big"
			var col := Tokens.COIN if big else Tokens.COIN.lightened(0.2)
			ci.draw_arc(c + Vector2(-m * 0.22, 0), m * (0.18 if big else 0.14), 0, TAU, 20, col, m * 0.08, true)
			ci.draw_line(c + Vector2(-m * 0.06, 0), c + Vector2(m * 0.42, 0), col, m * 0.08, true)
			ci.draw_line(c + Vector2(m * 0.3, 0), c + Vector2(m * 0.3, m * 0.16), col, m * 0.07)
			ci.draw_line(c + Vector2(m * 0.4, 0), c + Vector2(m * 0.4, m * 0.12), col, m * 0.07)


# ---------------- interaction ----------------
func _interact(id: String) -> void:
	var ob: Dictionary = objs[id]
	var a: Dictionary = ob["action"]
	Sfx.play("tap")
	_flash(id)
	match str(a["type"]):
		"search":
			if not opened.has(id):
				_solve(id)
				_open_panel(id, str(a["text"]))
			else:
				_open_panel(id, "فتّشت هنا من قبل. لا يوجد شيء آخر.")
		"look":
			_open_panel(id, str(a["text"]))
		_:
			_open_panel(id, str(a.get("done", "مفتوح.")) if opened.has(id) else str(a["text"]))


## Marks a puzzle solved, hands out its item / reveals, and wins on the exit.
func _solve(id: String) -> void:
	var a: Dictionary = objs[id]["action"]
	opened[id] = true
	var got := ""
	if a.has("needs"):
		inventory.erase(a["needs"])
	if a.has("gives"):
		inventory.append(a["gives"])
		_new_item = str(a["gives"])
		got = str(room["items"][a["gives"]]["name"])
	for rid in a.get("reveals", []):
		visible_ids[rid] = true
	Sfx.play("correct")
	Settings.vibrate(15)
	var r := _rect_px(objs[id])
	UiKit.burst(board, r.get_center(), Tokens.COIN, 40)
	UiKit.ring(board, r.get_center(), Tokens.COIN, maxf(r.size.x, r.size.y) * 0.8)
	if got != "":
		_say("حصلت على: %s" % got, Tokens.COIN)
	elif not (a.get("reveals", []) as Array).is_empty():
		_say("ظهر شيء جديد في الغرفة.", Tokens.COIN)
	_refresh()
	if bool(a.get("win", false)):
		_win()


## Short white flash on the touched object (skipped on low quality / reduce motion).
func _flash(id: String) -> void:
	if not _anim_ok():
		return
	_tap_id = id
	create_tween().tween_method(func(v: float):
		_tap_t = v
		board.queue_redraw(), 1.0, 0.0, Motion.BASE)


func _mistake(msg: String) -> void:
	mistakes += 1
	Sfx.play("wrong")
	Settings.vibrate(30)
	_say(msg, Tokens.ERROR)
	_refresh()


# ---------------- panel ----------------
func _close_panel() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null


func _make_panel(title: String) -> VBoxContainer:
	_close_panel()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close_panel())
	overlay.add_child(dim)
	var sheet := UiKit.card(2)
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.custom_minimum_size = Vector2(640, 0)
	sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(sheet)
	var v := UiKit.vbox(Tokens.SP_M)
	sheet.add_child(v)
	v.add_child(UiKit.heading(title, Tokens.FS_H2, accent))
	if _anim_ok():
		sheet.modulate.a = 0.0
		_pop_later(sheet)
	return v


func _pop_later(c: Control) -> void:
	await get_tree().process_frame   # size known -> pop from the center
	if is_instance_valid(c):
		c.modulate.a = 1.0
		Motion.pop_in(c)


func _open_panel(id: String, text: String) -> void:
	var ob: Dictionary = objs[id]
	var a: Dictionary = ob["action"]
	var v := _make_panel(str(ob["label"]))
	var prev := Control.new()
	prev.custom_minimum_size = Vector2(600, 300)
	prev.layout_direction = Control.LAYOUT_DIRECTION_LTR
	prev.draw.connect(func():
		var rr: Array = ob["rect"]
		var asp := float(rr[2]) / float(rr[3])
		var w := minf(prev.size.x * 0.9, prev.size.y * 0.9 * asp)
		var h := w / asp
		paint_object(prev, ob, Rect2((prev.size - Vector2(w, h)) / 2.0, Vector2(w, h)), opened.has(id)))
	v.add_child(prev)
	v.add_child(UiKit.label(text, Tokens.FS_BODY, Tokens.TEXT))
	if not opened.has(id):
		match str(a["type"]):
			"item":
				_item_ui(v, id)
			"code":
				_code_ui(v, id)
			"symbols":
				_symbols_ui(v, id)
	var close := UiKit.icon_button("close", "إغلاق", UiKit.Variant.GHOST)
	close.pressed.connect(_close_panel)
	v.add_child(close)


func _item_ui(v: VBoxContainer, id: String) -> void:
	if inventory.is_empty():
		v.add_child(UiKit.label("لا تحمل شيئًا تجرّبه هنا بعد.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
		return
	v.add_child(UiKit.label("جرّب شيئًا مما معك:", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	for it in inventory:
		var item_id := str(it)
		var b := UiKit.button("استخدم: %s" % room["items"][item_id]["name"], UiKit.Variant.SECONDARY, accent)
		b.pressed.connect(func():
			if item_id == str(objs[id]["action"]["needs"]):
				_close_panel()
				_solve(id)
				if not won:
					_open_panel(id, str(objs[id]["action"].get("done", "انفتح.")))
			else:
				_mistake("%s لا يناسب هنا." % room["items"][item_id]["name"])
				Motion.shake(b))
		v.add_child(b)


func _code_ui(v: VBoxContainer, id: String) -> void:
	_code = [0, 0, 0]
	_code_labels.clear()
	var row := UiKit.hbox(Tokens.SP_L)
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR   # numbers read left to right
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var col := UiKit.vbox(Tokens.SP_XS)
		var up := UiKit.icon_button("arrow_up", "", UiKit.Variant.SECONDARY, accent)
		var lbl := UiKit.heading("0", Tokens.FS_DISPLAY, Tokens.TEXT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var dn := UiKit.icon_button("arrow_down", "", UiKit.Variant.SECONDARY, accent)
		var idx := i
		up.pressed.connect(func(): _turn(idx, 1))
		dn.pressed.connect(func(): _turn(idx, -1))
		col.add_child(up)
		col.add_child(lbl)
		col.add_child(dn)
		_code_labels.append(lbl)
		row.add_child(col)
	v.add_child(row)
	var go := UiKit.icon_button("check", "جرّب الرمز", UiKit.Variant.PRIMARY, accent)
	go.pressed.connect(func():
		var s: String = "%d%d%d" % [_code[0], _code[1], _code[2]]
		if s == str(objs[id]["action"]["answer"]):
			_close_panel()
			_solve(id)
			if not won:
				_open_panel(id, str(objs[id]["action"].get("done", "انفتح.")))
		else:
			_mistake("الرمز %s خاطئ." % s)
			Motion.shake(row))
	v.add_child(go)


func _turn(i: int, d: int) -> void:
	_code[i] = posmod(int(_code[i]) + d, 10)
	(_code_labels[i] as Label).text = str(_code[i])
	Sfx.play("tap", 1.0 + 0.04 * _code[i])


func _symbols_ui(v: VBoxContainer, id: String) -> void:
	_sym_input.clear()
	_sym_slots.clear()
	var need := (objs[id]["action"]["answer"] as Array).size()
	v.add_child(UiKit.label("اضغط الرموز بالترتيب. الخانة 1 هي الأولى.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	var slots := UiKit.hbox(Tokens.SP_S)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in need:
		var sl := Control.new()
		sl.custom_minimum_size = Vector2(96, 112)
		var idx := i
		sl.draw.connect(func():
			sl.draw_rect(Rect2(Vector2.ZERO, Vector2(sl.size.x, sl.size.x)), Tokens.SURFACE_2)
			sl.draw_rect(Rect2(Vector2.ZERO, Vector2(sl.size.x, sl.size.x)), accent, false, 2.0)
			if idx < _sym_input.size():
				draw_symbol(sl, str(_sym_input[idx]), Vector2(sl.size.x / 2.0, sl.size.x / 2.0), sl.size.x * 0.32, Tokens.TEXT)
			sl.draw_string(Tokens.font_bold, Vector2(0, sl.size.y - 2), str(idx + 1), HORIZONTAL_ALIGNMENT_CENTER, sl.size.x, Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
		_sym_slots.append(sl)
		slots.add_child(sl)
	v.add_child(slots)
	var pad := GridContainer.new()
	pad.columns = 3
	pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pad.add_theme_constant_override("h_separation", Tokens.SP_S)
	pad.add_theme_constant_override("v_separation", Tokens.SP_S)
	for sym in SYMS:
		var b := UiKit.button(str(data["symbols"].get(sym, sym)), UiKit.Variant.SECONDARY, accent)
		b.custom_minimum_size = Vector2(180, Tokens.TOUCH_MIN)
		var icon := Control.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(40, 40)
		icon.position = Vector2(12, 24)
		icon.size = Vector2(40, 40)
		var s_name := str(sym)
		icon.draw.connect(func(): draw_symbol(icon, s_name, Vector2(20, 20), 16.0, Tokens.TEXT))
		b.add_child(icon)
		b.pressed.connect(func(): _press_symbol(id, s_name, slots))
		pad.add_child(b)
	v.add_child(pad)
	var clear := UiKit.icon_button("undo", "امسح", UiKit.Variant.GHOST)
	clear.pressed.connect(func():
		_sym_input.clear()
		for sl in _sym_slots:
			(sl as Control).queue_redraw())
	v.add_child(clear)


func _press_symbol(id: String, sym: String, slots: Control) -> void:
	var ans: Array = objs[id]["action"]["answer"]
	if _sym_input.size() >= ans.size():
		return
	_sym_input.append(sym)
	for sl in _sym_slots:
		(sl as Control).queue_redraw()
	if _sym_input.size() < ans.size():
		return
	var ok := true
	for i in ans.size():
		if str(ans[i]) != str(_sym_input[i]):
			ok = false
	if ok:
		_close_panel()
		_solve(id)
		if not won:
			_open_panel(id, str(objs[id]["action"].get("done", "انفتح.")))
	else:
		_mistake("الترتيب غير صحيح.")
		Motion.shake(slots)
		_sym_input.clear()
		for sl in _sym_slots:
			(sl as Control).queue_redraw()


# ---------------- hints ----------------
## First hint whose target puzzle is not solved yet ({} when nothing is left).
func current_hint() -> Dictionary:
	for h in room.get("hints", []):
		if not opened.has(str(h["until"])):
			return h
	return {}


func _hint() -> void:
	if won or room.is_empty():
		return
	var h := current_hint()
	if h.is_empty():
		return
	var key := str(h["until"])
	if not bought_hints.has(key):
		if not spend_coins(hint_cost):
			var v0 := _make_panel("تلميح")
			v0.add_child(UiKit.label("التلميح يكلّف %d عملة، ورصيدك %d. اجمع العملات بالنجوم في الألعاب الأخرى." % [hint_cost, coins()], Tokens.FS_BODY, Tokens.TEXT))
			var ok0 := UiKit.icon_button("close", "حسنًا", UiKit.Variant.GHOST)
			ok0.pressed.connect(_close_panel)
			v0.add_child(ok0)
			Sfx.play("wrong")
			return
		bought_hints[key] = true
		Sfx.play("coin")
	var v := _make_panel("تلميح")
	v.add_child(UiKit.label(str(h["text"]), Tokens.FS_BODY, Tokens.TEXT))
	v.add_child(UiKit.label("هذا التلميح مدفوع، يمكنك رؤيته مجددًا مجانًا.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	var ok := UiKit.icon_button("check", "فهمت", UiKit.Variant.PRIMARY, accent)
	ok.pressed.connect(_close_panel)
	v.add_child(ok)
	_refresh()


# ---------------- end ----------------
static func stars_for(p_mistakes: int) -> int:
	if p_mistakes <= 2:
		return 3
	if p_mistakes <= 6:
		return 2
	return 1


func _win() -> void:
	won = true
	_close_panel()
	hint_btn.disabled = true
	var stars := stars_for(mistakes)
	Sfx.play("win")
	_say("انفتح الباب!", Tokens.SUCCESS)
	board.queue_redraw()
	await wait(Motion.NEXT_BUTTON_MAX_DELAY)
	var score := maxi(100, 1200 - mistakes * 80 - int(elapsed))
	finish(stars, score, "هربت في %d ثانية بـ %d أخطاء و%d تلميحات" % [int(elapsed), mistakes, bought_hints.size()])


# ---------------- verification (used by devtools/test_runner.gd) ----------------
static func _param(o: Dictionary, p: String) -> int:
	match p:
		"lit_count":
			var n := 0
			for x in o["lit"]:
				if bool(x):
					n += 1
			return n
		"red_books":
			var n2 := 0
			for b in o["books"]:
				if int(b["c"]) == 0:
					n2 += 1
			return n2
		"book_count":
			return (o["books"] as Array).size()
	return int(o.get(p, -1))


## Recomputes a lock's answer from its clue objects. Code -> "352", symbols -> "a,b,c,d".
static func derive_answer(rm: Dictionary, a: Dictionary) -> String:
	var by_id := {}
	for o in rm["objects"]:
		by_id[o["id"]] = o
	if str(a["type"]) == "code":
		var out := ""
		if a.has("from"):
			for f in a["from"]:
				out += str(_param(by_id[f[0]], str(f[1])))
			return out
		var ids: Array = (a["rule"]["objs"] as Array).duplicate()
		ids.sort_custom(func(x, y): return float(by_id[x]["rect"][2]) * float(by_id[x]["rect"][3]) < float(by_id[y]["rect"][2]) * float(by_id[y]["rect"][3]))
		for i in ids:
			out += str(int(by_id[i][a["rule"]["param"]]))
		return out
	var rule: Dictionary = a["rule"]
	var src: Dictionary = by_id[rule["obj"]]
	var seq: Array = []
	match str(rule["by"]):
		"height_asc":
			var bs: Array = []
			for b in src["books"]:
				if str(b["sym"]) != "":
					bs.append(b)
			bs.sort_custom(func(x, y): return float(x["h"]) < float(y["h"]))
			for b in bs:
				seq.append(str(b["sym"]))
		"number_asc", "count_desc":
			var ps: Array = (src["pairs"] as Array).duplicate()
			var asc := str(rule["by"]) == "number_asc"
			ps.sort_custom(func(x, y): return float(x[1]) < float(y[1]) if asc else float(x[1]) > float(y[1]))
			for pr in ps:
				seq.append(str(pr[0]))
		"as_listed":
			for sname in src["syms"]:
				seq.append(str(sname))
	return ",".join(PackedStringArray(seq))


## Play-through without UI: true if the exit opens using only things found in the room.
static func simulate(rm: Dictionary) -> bool:
	var vis := {}
	var done := {}
	var inv := {}
	for o in rm["objects"]:
		if not bool(o.get("hidden", false)):
			vis[o["id"]] = true
	var progress := true
	while progress:
		progress = false
		for o in rm["objects"]:
			var id := str(o["id"])
			if not vis.has(id) or done.has(id):
				continue
			var a: Dictionary = o["action"]
			var t := str(a["type"])
			var ok := t == "search" or (t == "item" and inv.has(str(a.get("needs", ""))))
			if t == "code" or t == "symbols":
				ok = true
				for cid in a.get("clues", []):
					ok = ok and vis.has(str(cid))
			if t == "look" or not ok:
				continue
			done[id] = true
			progress = true
			if a.has("gives"):
				inv[str(a["gives"])] = true
			for rid in a.get("reveals", []):
				vis[str(rid)] = true
			if bool(a.get("win", false)):
				return true
	return false
