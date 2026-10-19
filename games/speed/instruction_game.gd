extends MiniGame
## Changing instructions: 12 rounds. Each round the 4 buttons get a fresh random
## pairing of shape and color and a fresh position, so the player must really read the rule.
## Higher levels: less time, more rule switches, and (level 6+) the prompt is printed in
## a misleading color (Stroop). Colorblind mode writes the color name on every button.

const ROUNDS := 12
const COLORS := [Color("#F5B33D"), Color("#2CC9B5"), Color("#FF5E6C"), Color("#9BDB4D")]
const COLOR_NAMES := ["الكهرماني", "الفيروزي", "المرجاني", "الليموني"]
const COLOR_SHORT := ["كهرماني", "فيروزي", "مرجاني", "ليموني"]

var prompt: Label
var score_label: Label
var timer_chip: Label
var time_bar: ProgressBar
var buttons: Array[Button] = []
var icons: Array[ShapeIcon] = []
var tags: Array[Label] = []
var btn_shape: Array[int] = [0, 1, 2, 3]
var btn_color: Array[int] = [0, 1, 2, 3]
var running := false
var round_no := 0
var score := 0
var streak := 0
var rule_shape := false
var target_value := 0
var elapsed := 0.0
var limit := 2.4
var rng := RandomNumberGenerator.new()


func _on_start() -> void:
	rng.seed = Time.get_ticks_usec()
	limit = maxf(1.2, 2.5 - 0.12 * (level_id - 1))
	var v := frame("التعليمات المتغيرة", 28)
	score_label = chip("", "check")
	timer_chip = chip("", "bolt", Tokens.COIN)
	prompt = UiKit.heading("", Tokens.FS_H1, accent)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(prompt)
	time_bar = ProgressBar.new()
	time_bar.show_percentage = false
	time_bar.custom_minimum_size = Vector2(0, 10)
	time_bar.max_value = 1.0
	var tb_bg := StyleBoxFlat.new()
	tb_bg.bg_color = Tokens.SURFACE_2
	tb_bg.set_corner_radius_all(5)
	var tb_fill := StyleBoxFlat.new()
	tb_fill.bg_color = accent
	tb_fill.set_corner_radius_all(5)
	time_bar.add_theme_stylebox_override("background", tb_bg)
	time_bar.add_theme_stylebox_override("fill", tb_fill)
	v.add_child(time_bar)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Tokens.SP_S)
	grid.add_theme_constant_override("v_separation", Tokens.SP_S)
	v.add_child(grid)
	var cb := bool(Settings.get_value("colorblind"))
	for i in 4:
		var b := UiKit.button("", UiKit.Variant.SECONDARY, Tokens.LINE)
		b.custom_minimum_size = Vector2(0, 190)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.pressed.connect(func(): _choose(idx))
		var icon := ShapeIcon.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_top = 16
		icon.offset_bottom = -(44 if cb else 16)
		b.add_child(icon)
		var tag := UiKit.label("", Tokens.FS_CAPTION, Tokens.TEXT, Tokens.font_bold)
		tag.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		tag.offset_top = -44
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.visible = cb
		b.add_child(tag)
		grid.add_child(b)
		buttons.append(b)
		icons.append(icon)
		tags.append(tag)
	var help := "اضغط ما تطلبه التعليمة الآن: لون أو شكل. الأزرار تتبدل كل جولة."
	if level_id >= 6:
		help += " انتبه: لون كلمة التعليمة قد يخدعك."
	v.add_child(UiKit.label(help, Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	_next_round()


func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	time_bar.value = clampf(1.0 - elapsed / limit, 0.0, 1.0)
	if elapsed > limit:
		_choose(-1)


func _next_round() -> void:
	if round_no >= ROUNDS:
		var ratio := float(score) / float(ROUNDS)
		finish(3 if ratio >= 0.9 else (2 if ratio >= 0.7 else (1 if ratio >= 0.5 else 0)), score * 100 + streak * 10, "%d من %d تعليمة صحيحة" % [score, ROUNDS])
		return
	round_no += 1
	elapsed = 0.0
	# switch probability grows with the level; the first round is always a color rule
	var p_switch := 0.25 + 0.05 * level_id
	if round_no > 1 and rng.randf() < p_switch:
		rule_shape = not rule_shape
	_shuffle(btn_shape)
	_shuffle(btn_color)
	target_value = rng.randi_range(0, 3)
	var word: String = ("اضغط ال" + str(ShapeIcon.NAMES[target_value])) if rule_shape else ("اضغط اللون " + str(COLOR_NAMES[target_value]))
	prompt.text = word
	var prompt_color := accent
	if level_id >= 6:
		prompt_color = COLORS[(target_value + 1 + rng.randi_range(0, 2)) % 4]   # never the asked color
	prompt.add_theme_color_override("font_color", prompt_color)
	Motion.pop_in(prompt)
	UiKit.set_chip(score_label, "%d" % score)
	UiKit.set_chip(timer_chip, "%d/%d" % [round_no, ROUNDS], false)
	for i in 4:
		icons[i].set_shape(btn_shape[i], COLORS[btn_color[i]])
		tags[i].text = COLOR_SHORT[btn_color[i]]
		buttons[i].disabled = false
		buttons[i].modulate = Color.WHITE
	running = true


func _shuffle(a: Array[int]) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := a[i]
		a[i] = a[j]
		a[j] = t


func _choose(index: int) -> void:
	if not running:
		return
	running = false
	var ok := false
	if index >= 0:
		ok = (btn_shape[index] if rule_shape else btn_color[index]) == target_value
	if ok:
		score += 1
		streak += 1
		Sfx.play("correct", 1.0 + minf(streak * 0.03, 0.3))
		Motion.flash(buttons[index], Tokens.SUCCESS)
	else:
		streak = 0
		Sfx.play("wrong")
		Settings.vibrate(30)
		if index >= 0:
			Motion.shake(buttons[index])
		prompt.text = "انتهى الوقت" if index < 0 else "خطأ"
	for b in buttons:
		b.disabled = true
	await wait(0.35)
	_next_round()
