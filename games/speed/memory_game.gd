extends MiniGame
## Sequence memory. Level L asks for a sequence of 3 + L steps, played faster each level.
## Every cell has its own shape and its own tone, so color is never the only cue.

const COLORS := [Color("#F5B33D"), Color("#2CC9B5"), Color("#FF5E6C"), Color("#9BDB4D")]
const PITCH := [0.8, 1.0, 1.2, 1.45]

var grid: GridContainer
var status: Label
var step_chip: Label
var cells: Array[Button] = []
var sequence: Array[int] = []
var input_index := 0
var goal := 4
var step := 0.5
var accepting := false
var rng := RandomNumberGenerator.new()


func _on_start() -> void:
	rng.seed = Time.get_ticks_usec()
	goal = 3 + level_id
	step = maxf(0.28, 0.55 - 0.03 * (level_id - 1))
	var v := frame("ذاكرة التسلسل", 28)
	step_chip = chip("", "check")
	status = UiKit.heading("", Tokens.FS_H2, accent)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Tokens.SP_S)
	grid.add_theme_constant_override("v_separation", Tokens.SP_S)
	v.add_child(grid)
	for i in 4:
		var b := UiKit.button("", UiKit.Variant.SECONDARY, COLORS[i])
		b.custom_minimum_size = Vector2(0, 220)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.pressed.connect(func(): _tap(idx))
		var icon := ShapeIcon.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_top = 40
		icon.offset_bottom = -40
		icon.set_shape(i, COLORS[i])
		b.add_child(icon)
		grid.add_child(b)
		cells.append(b)
	v.add_child(UiKit.label("راقب التسلسل، ثم أعده بالضغط. الهدف: %d خطوات." % goal, Tokens.FS_BODY, Tokens.TEXT_MUTED))
	_next_round()


func _next_round() -> void:
	if sequence.size() >= goal:
		finish(3, goal * 100 + level_id * 50, "أكملت تسلسلًا من %d خطوات" % goal)
		return
	sequence.append(rng.randi_range(0, 3))
	input_index = 0
	accepting = false
	status.text = "شاهد"
	UiKit.set_chip(step_chip, "%d/%d" % [sequence.size(), goal])
	for b in cells:
		b.disabled = true
	await wait(0.5)
	for item in sequence:
		_light(item)
		await wait(step)
	for b in cells:
		b.disabled = false
	accepting = true
	status.text = "دورك"
	Motion.pop_in(status)


func _light(i: int) -> void:
	Motion.flash(cells[i], COLORS[i])
	Motion.pop_in(cells[i].get_child(0) as Control)
	Sfx.play("tap", PITCH[i])


func _tap(index: int) -> void:
	if not accepting:
		return
	if index != sequence[input_index]:
		accepting = false
		Sfx.play("wrong")
		Settings.vibrate(40)
		Motion.shake(cells[index])
		var done := sequence.size() - 1   # sequences fully repeated
		var stars := 2 if done >= goal - 1 else (1 if done >= int(ceil(goal / 2.0)) else 0)
		await wait(0.6)
		finish(stars, done * 80, "أعدت %d من %d تسلسلات" % [done, goal])
		return
	_light(index)
	input_index += 1
	if input_index >= sequence.size():
		accepting = false
		Sfx.play("correct")
		await wait(0.4)
		_next_round()
