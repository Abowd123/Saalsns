extends MiniGame
## N-Back: a square lights up (and from some levels a letter appears with it). Press
## "same place" / "same letter" when it matches what was shown N steps earlier.
## Scored per channel on every trial after the first N: press on a match, stay still
## otherwise. Stars by accuracy (92% / 82% / 70%).

## [N, dual (letters too), seconds per trial]
const LEVELS := [[1, false, 2.6], [2, false, 2.6], [1, true, 2.6], [2, true, 2.5], [3, false, 2.4], [2, true, 2.1], [3, true, 2.3], [4, false, 2.2]]
const LETTERS := ["ب", "ج", "د", "ر", "س", "ع", "م", "ن"]
const SHOW := 0.6
const MATCH_RATE := 0.3

var n := 1
var dual := false
var period := 2.5
var total := 20
var seq_pos: Array[int] = []
var seq_let: Array[int] = []
var trial := -1
var t := 0.0
var running := false
var pressed_pos := false
var pressed_let := false
var correct := 0
var judged := 0
var grid: Control
var pos_btn: Button
var let_btn: Button
var info: Label
var n_chip: Label
var prompt: Label
var rng := RandomNumberGenerator.new()
var _lit := -1
var _lit_letter := ""
var _miss_cell := -1


func _on_start() -> void:
	rng.seed = Time.get_ticks_usec()
	var cfg: Array = LEVELS[clampi(level_id - 1, 0, LEVELS.size() - 1)]
	n = int(cfg[0])
	dual = bool(cfg[1])
	period = float(cfg[2])
	total = 20 + n
	_make_sequence()
	var v := frame("N-Back")
	n_chip = chip("N = %d" % n, "hint", Tokens.COIN)
	info = chip("", "check")
	prompt = UiKit.label("", Tokens.FS_BODY, Tokens.TEXT, Tokens.font_bold)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(prompt)
	grid = Control.new()
	grid.custom_minimum_size = Vector2(0, 560)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.layout_direction = Control.LAYOUT_DIRECTION_LTR
	grid.draw.connect(_paint)
	grid.resized.connect(grid.queue_redraw)
	v.add_child(grid)
	pos_btn = UiKit.button("نفس المكان", UiKit.Variant.PRIMARY, accent)
	pos_btn.custom_minimum_size = Vector2(0, 120)
	pos_btn.button_down.connect(_press_pos)
	let_btn = UiKit.button("نفس الحرف", UiKit.Variant.PRIMARY, Tokens.COIN)
	let_btn.custom_minimum_size = Vector2(0, 120)
	let_btn.button_down.connect(_press_let)
	let_btn.visible = dual
	v.add_child(action_bar([pos_btn, let_btn]))
	var steps := "خطوة واحدة" if n == 1 else ("خطوتين" if n == 2 else "%d خطوات" % n)
	prompt.text = "اضغط «نفس المكان» إذا أضاء المربع نفسه قبل %s%s." % [steps, ("، و«نفس الحرف» إذا تكرر الحرف قبل %s" % steps) if dual else ""]
	_refresh_info()
	await wait(2.5)
	running = true
	_next_trial()


func _make_sequence() -> void:
	for i in total:
		if i >= n and rng.randf() < MATCH_RATE:
			seq_pos.append(seq_pos[i - n])
		else:
			var p := rng.randi_range(0, 8)
			if i >= n and p == seq_pos[i - n]:
				p = (p + 1 + rng.randi_range(0, 7)) % 9
			seq_pos.append(p)
		if i >= n and rng.randf() < MATCH_RATE:
			seq_let.append(seq_let[i - n])
		else:
			var l := rng.randi_range(0, LETTERS.size() - 1)
			if i >= n and l == seq_let[i - n]:
				l = (l + 1 + rng.randi_range(0, LETTERS.size() - 2)) % LETTERS.size()
			seq_let.append(l)


func _is_pos_match(i: int) -> bool:
	return i >= n and seq_pos[i] == seq_pos[i - n]


func _is_let_match(i: int) -> bool:
	return dual and i >= n and seq_let[i] == seq_let[i - n]


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	if (_lit >= 0 or _miss_cell >= 0) and t >= SHOW:
		_lit = -1
		_miss_cell = -1
		grid.queue_redraw()
	if t >= period:
		_judge()
		_next_trial()


func _next_trial() -> void:
	trial += 1
	if trial >= total:
		running = false
		var acc := float(correct) / float(maxi(judged, 1))
		var stars := 3 if acc >= 0.92 else (2 if acc >= 0.82 else (1 if acc >= 0.7 else 0))
		finish(stars, int(acc * 1000) + n * 100, "الدقة %d%% في %d خطوة (N = %d)" % [int(acc * 100), total, n])
		return
	t = 0.0
	pressed_pos = false
	pressed_let = false
	_lit = seq_pos[trial]
	_lit_letter = LETTERS[seq_let[trial]] if dual else ""
	pos_btn.disabled = trial < n
	let_btn.disabled = trial < n
	Sfx.play("tap", 0.8 + 0.06 * seq_pos[trial])
	_refresh_info()
	grid.queue_redraw()


## End of a trial: count both channels. A match nobody pressed is shown as a miss.
func _judge() -> void:
	_miss_cell = -1
	if trial < n:
		return
	judged += 1
	if pressed_pos == _is_pos_match(trial):
		correct += 1
	elif not pressed_pos:
		_miss_cell = seq_pos[trial]
	if dual:
		judged += 1
		if pressed_let == _is_let_match(trial):
			correct += 1


func _press_pos() -> void:
	if not running or trial < n or pressed_pos:
		return
	pressed_pos = true
	_feedback(pos_btn, _is_pos_match(trial))


func _press_let() -> void:
	if not running or trial < n or pressed_let or not dual:
		return
	pressed_let = true
	_feedback(let_btn, _is_let_match(trial))


func _feedback(b: Button, ok: bool) -> void:
	if ok:
		Sfx.play("correct")
		Motion.flash(b, Tokens.SUCCESS)
	else:
		Sfx.play("wrong")
		Settings.vibrate(30)
		Motion.shake(b)


func _refresh_info() -> void:
	UiKit.set_chip(info, "%d/%d" % [maxi(trial + 1, 0), total], false)


func _paint() -> void:
	if grid.size.x < 60.0 or grid.size.y < 60.0:
		return   # not laid out yet (first frame): avoid negative sizes
	var side := minf(grid.size.x, grid.size.y) - 20.0
	var cell := side / 3.0
	var o := (grid.size - Vector2(side, side)) / 2.0
	for i in 9:
		var r := Rect2(o + Vector2(i % 3, i / 3) * cell + Vector2(8, 8), Vector2(cell - 16, cell - 16))
		var lit := i == _lit
		grid.draw_rect(Rect2(r.position + Vector2(0, 5), r.size), Color(0, 0, 0, 0.3))
		grid.draw_rect(r, accent if lit else Tokens.SURFACE_1)
		if lit:
			grid.draw_rect(r.grow(6), Color(accent, 0.25), false, 6.0)
			if _lit_letter != "":
				var f := Tokens.font_display
				var fs := int(cell * 0.45)
				var ts := f.get_string_size(_lit_letter, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
				grid.draw_string(f, r.get_center() + Vector2(-ts.x / 2.0, ts.y * 0.3), _lit_letter, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Tokens.BG)
		elif i == _miss_cell:
			grid.draw_rect(r, Color(Tokens.ERROR, 0.8), false, 5.0)
		else:
			grid.draw_rect(r, Tokens.LINE, false, 2.0)
