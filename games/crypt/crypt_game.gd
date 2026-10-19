extends MiniGame
## Letter arithmetic: every letter hides one digit (different letters = different digits,
## no number starts with 0). Pick a letter, tap a digit. When every letter has a digit the
## sum is checked; a wrong sum costs a mistake and marks the first wrong column (from the right).
## Each shipped puzzle has exactly one solution (tools/crypt_gen.py).

var defs: Array = []
var lv: Dictionary = {}
var words: Array[String] = []
var letters: Array[String] = []      # unique letters, in first-seen order
var assign := {}                     # letter -> digit
var locked := {}                     # letters revealed by hints
var selected := ""
var mistakes := 0
var hints := 0
var bad_col := -1
var solved := false
var eq: Control
var keypad: GridContainer
var digit_btns: Array[Button] = []
var mist_chip: Label
var hint_chip: Label
var msg: Label


func _on_start() -> void:
	var v := frame("حساب الحروف")
	mist_chip = chip("0", "close", Tokens.ERROR)
	hint_chip = chip("0", "hint", Tokens.COIN)
	msg = UiKit.label("اختر حرفًا ثم رقمًا. كل حرف رقم مختلف، ولا يبدأ عدد بصفر.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(msg)
	eq = Control.new()
	eq.custom_minimum_size = Vector2(0, 470)
	eq.size_flags_vertical = Control.SIZE_EXPAND_FILL
	eq.layout_direction = Control.LAYOUT_DIRECTION_LTR
	eq.draw.connect(_paint)
	eq.resized.connect(eq.queue_redraw)
	eq.gui_input.connect(_on_eq_input)
	v.add_child(eq)
	keypad = GridContainer.new()
	keypad.columns = 5
	keypad.layout_direction = Control.LAYOUT_DIRECTION_LTR
	keypad.add_theme_constant_override("h_separation", Tokens.SP_S)
	keypad.add_theme_constant_override("v_separation", Tokens.SP_S)
	for d in 10:
		var b := UiKit.button(str(d), UiKit.Variant.SECONDARY, accent)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 84)
		b.add_theme_font_size_override("font_size", Tokens.FS_H2)
		var dd := d
		b.pressed.connect(func(): _put(dd))
		keypad.add_child(b)
		digit_btns.append(b)
	v.add_child(keypad)
	var clear := UiKit.icon_button("close", "امسح الحرف", UiKit.Variant.GHOST)
	clear.pressed.connect(func(): _put(-1))
	var hint := UiKit.icon_button("hint", "اكشف حرفًا", UiKit.Variant.SECONDARY, Tokens.COIN)
	hint.pressed.connect(_hint)
	v.add_child(action_bar([clear, hint]))
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/crypt/levels.json"))
	if p is Dictionary:
		defs = p["levels"]
	if defs.is_empty():
		msg.text = "تعذّر تحميل المراحل"
		return
	_load_level(level_id)


func _load_level(id: int) -> void:
	lv = defs[clampi(id - 1, 0, defs.size() - 1)]
	title_label.text = "حساب الحروف · %s" % lv["name"]
	words = [str(lv["a"]), str(lv["b"]), str(lv["c"])]
	letters.clear()
	for w in words:
		for ch in w:
			if not (ch in letters):
				letters.append(ch)
	assign.clear()
	locked.clear()
	selected = letters[0]
	_refresh()


func _leading(ch: String) -> bool:
	for w in words:
		if w.substr(0, 1) == ch:
			return true
	return false


func _put(d: int) -> void:
	if solved or selected == "" or locked.has(selected):
		return
	if d == 0 and _leading(selected):
		Sfx.play("wrong")
		msg.text = "الحرف «%s» أول العدد، فلا يكون صفرًا." % selected
		return
	if d < 0:
		assign.erase(selected)
	else:
		for k in assign.keys():
			if int(assign[k]) == d and k != selected:
				if locked.has(k):
					Sfx.play("wrong")
					return
				assign.erase(k)   # a digit belongs to one letter only
		assign[selected] = d
		Sfx.play("pop")
		_select_next()
	bad_col = -1
	_refresh()
	if assign.size() == letters.size():
		_check()


func _select_next() -> void:
	var i := letters.find(selected)
	for k in letters.size():
		var c: String = letters[(i + 1 + k) % letters.size()]
		if not assign.has(c):
			selected = c
			return


func _value(w: String) -> int:
	var v := 0
	for ch in w:
		v = v * 10 + int(assign.get(ch, 0))
	return v


func _check() -> void:
	if _value(words[0]) + _value(words[1]) == _value(words[2]):
		solved = true
		Sfx.play("win")
		msg.text = "%d + %d = %d" % [_value(words[0]), _value(words[1]), _value(words[2])]
		UiKit.burst(eq, eq.size / 2.0, Tokens.SUCCESS, 80)
		var stars := 3 if hints == 0 and mistakes <= 2 else (2 if hints <= 1 and mistakes <= 5 else 1)
		await wait(1.2)
		finish(stars, maxi(100, 1200 - mistakes * 120 - hints * 250), "حللتها بـ %d أخطاء و%d تلميح" % [mistakes, hints])
		return
	mistakes += 1
	bad_col = _first_bad_column()
	Sfx.play("wrong")
	Settings.vibrate(40)
	Motion.shake_area(eq, 10.0)
	msg.text = "ليس صحيحًا. أول خانة خاطئة من اليمين معلّمة بالأحمر."
	_refresh()


## Index from the right (0 = units) of the first column whose digit sum does not match.
func _first_bad_column() -> int:
	var carry := 0
	var L := words[2].length()
	for i in L:
		var da := _digit_at(words[0], i)
		var db := _digit_at(words[1], i)
		var s := da + db + carry
		if s % 10 != _digit_at(words[2], i):
			return i
		carry = s / 10
	return L - 1


func _digit_at(w: String, from_right: int) -> int:
	var idx := w.length() - 1 - from_right
	return int(assign.get(w.substr(idx, 1), 0)) if idx >= 0 else 0


func _hint() -> void:
	if solved:
		return
	var sol: Dictionary = lv["solution"]
	var order := letters.duplicate()
	order.shuffle()
	for ch in order:
		if locked.has(ch) or (assign.has(ch) and int(assign[ch]) == int(sol[ch])):
			continue
		for k in assign.keys():
			if int(assign[k]) == int(sol[ch]):
				assign.erase(k)
		assign[ch] = int(sol[ch])
		locked[ch] = true
		hints += 1
		Sfx.play("coin")
		_select_next()
		bad_col = -1
		_refresh()
		if assign.size() == letters.size():
			_check()
		return


func _refresh() -> void:
	UiKit.set_chip(mist_chip, str(mistakes))
	UiKit.set_chip(hint_chip, str(hints))
	for d in 10:
		var owner := ""
		for k in assign.keys():
			if int(assign[k]) == d:
				owner = k
		digit_btns[d].modulate = Color(1, 1, 1, 0.45) if owner != "" and owner != selected else Color.WHITE
	eq.queue_redraw()


func _layout() -> Array:
	var L := words[2].length()
	var box := minf((eq.size.x - 120.0) / L, 104.0)
	var gap := box * 0.12
	var right := (eq.size.x + (box + gap) * L) / 2.0 + 30.0
	var row_h := box * 1.3
	var top := (eq.size.y - row_h * 3 - 30.0) / 2.0
	return [box, gap, right, row_h, top]


func _box_rect(row: int, from_right: int) -> Rect2:
	var g := _layout()
	var box: float = g[0]
	var gap: float = g[1]
	var x: float = float(g[2]) - (from_right + 1) * (box + gap)
	var y: float = float(g[4]) + row * float(g[3]) + (30.0 if row == 2 else 0.0)
	return Rect2(Vector2(x, y), Vector2(box, box * 1.15))


func _on_eq_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or solved or words.is_empty():
		return
	for row in 3:
		var w := words[row]
		for i in w.length():
			if _box_rect(row, w.length() - 1 - i).has_point(e.position):
				selected = w.substr(i, 1)
				Sfx.play("tap")
				_refresh()
				return


func _paint() -> void:
	if eq.size.x < 60.0 or eq.size.y < 60.0:
		return   # not laid out yet (first frame): avoid negative sizes
	if words.is_empty():
		return
	var g := _layout()
	var box: float = g[0]
	for row in 3:
		var w := words[row]
		for i in w.length():
			var ch := w.substr(i, 1)
			var fr := w.length() - 1 - i
			var r := _box_rect(row, fr)
			var fill := Tokens.SURFACE_1
			if ch == selected:
				fill = accent.darkened(0.45)
			if locked.has(ch):
				fill = Tokens.COIN.darkened(0.55)
			eq.draw_rect(Rect2(r.position + Vector2(0, 5), r.size), Color(0, 0, 0, 0.3))
			eq.draw_rect(r, fill)
			var border := accent if ch == selected else Tokens.LINE
			if fr == bad_col:
				border = Tokens.ERROR
			eq.draw_rect(r, border, false, 3.0 if (ch == selected or fr == bad_col) else 2.0)
			var lf := Tokens.font_display
			var fs := int(box * 0.42)
			var ls := lf.get_string_size(ch, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			eq.draw_string(lf, Vector2(r.get_center().x - ls.x / 2.0, r.position.y + box * 0.5), ch, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Tokens.TEXT)
			var dig := str(assign[ch]) if assign.has(ch) else "؟"
			var df := Tokens.font_bold
			var dfs := int(box * 0.36)
			var dsz := df.get_string_size(dig, HORIZONTAL_ALIGNMENT_CENTER, -1, dfs)
			eq.draw_string(df, Vector2(r.get_center().x - dsz.x / 2.0, r.end.y - box * 0.14), dig, HORIZONTAL_ALIGNMENT_CENTER, -1, dfs, Tokens.COIN if assign.has(ch) else Tokens.TEXT_MUTED)
	# plus sign and sum line
	var b_len := words[1].length()
	var pr := _box_rect(1, b_len)
	var pc := pr.get_center()
	var pl := box * 0.22
	eq.draw_line(pc - Vector2(pl, 0), pc + Vector2(pl, 0), Tokens.TEXT, 5.0, true)
	eq.draw_line(pc - Vector2(0, pl), pc + Vector2(0, pl), Tokens.TEXT, 5.0, true)
	var L := words[2].length()
	var left := _box_rect(2, L - 1).position.x
	var right := _box_rect(2, 0).end.x
	var ly := _box_rect(2, 0).position.y - 18.0
	eq.draw_line(Vector2(left - 10, ly), Vector2(right + 10, ly), Tokens.TEXT_MUTED, 4.0, true)
