extends MiniGame
## عقل الحساب: 60-second sprint with a custom keypad. Problems are generated and
## correct by construction (ArithGen). Combo raises the score multiplier.

const DURATION := 60.0
const GOALS := [8, 13, 18]   # correct answers for 1/2/3 stars at level 1, +1 per level

var rng := RandomNumberGenerator.new()
var problem: Dictionary = {}
var input := ""
var time_left := DURATION
var running := false
var correct := 0
var wrong := 0
var combo := 0
var score := 0
var problem_label: Label
var input_label: Label
var hud_l: Label
var combo_label: Label
var card: PanelContainer


func _on_start() -> void:
	rng.seed = Time.get_ticks_usec()
	var v := frame("عقل الحساب")
	hud_l = chip("", "", Tokens.TEXT)
	card = UiKit.card(2)
	var cv := UiKit.vbox(Tokens.SP_S)
	card.add_child(cv)
	problem_label = UiKit.heading("", Tokens.FS_DISPLAY, Tokens.TEXT)
	problem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	problem_label.text_direction = Control.TEXT_DIRECTION_LTR
	cv.add_child(problem_label)
	input_label = UiKit.heading("", Tokens.FS_DISPLAY, accent)
	input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_label.text_direction = Control.TEXT_DIRECTION_LTR
	cv.add_child(input_label)
	combo_label = UiKit.label("", Tokens.FS_CAPTION, Tokens.COIN, Tokens.font_bold)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(combo_label)
	v.add_child(card)
	var pad := GridContainer.new()
	pad.columns = 3
	pad.layout_direction = Control.LAYOUT_DIRECTION_LTR
	pad.add_theme_constant_override("h_separation", Tokens.SP_S)
	pad.add_theme_constant_override("v_separation", Tokens.SP_S)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in ["7", "8", "9", "4", "5", "6", "1", "2", "3", "مسح", "0", "="]:
		var b := UiKit.button(k, UiKit.Variant.PRIMARY if k == "=" else UiKit.Variant.SECONDARY, accent)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		b.add_theme_font_size_override("font_size", Tokens.FS_H1)
		var key: String = k
		b.button_down.connect(func(): _key(key))
		pad.add_child(b)
	v.add_child(pad)
	_new_problem()
	running = true


func _new_problem() -> void:
	problem = ArithGen.make(level_id, rng)
	problem_label.text = "%s = ?" % problem["text"]
	input = ""
	input_label.text = "_"


func _key(k: String) -> void:
	if not running:
		return
	if k == "مسح":
		input = input.left(maxi(input.length() - 1, 0))
	elif k == "=":
		_submit()
		return
	elif input.length() < 4:
		input += k
	input_label.text = input if input != "" else "_"
	# auto-submit when the typed length matches the answer length
	if input.length() == str(problem["answer"]).length():
		_submit()


func _submit() -> void:
	if input == "":
		return
	if int(input) == int(problem["answer"]):
		correct += 1
		combo += 1
		var mult := 1 + mini(combo / 5, 3)
		score += 10 * mult
		combo_label.text = ("سلسلة %d  ·  ×%d" % [combo, mult]) if combo >= 3 else ""
		Sfx.play("correct", 1.0 + minf(combo * 0.03, 0.3))
		Motion.flash(card, Tokens.SUCCESS)
		Motion.bump(problem_label, 1.08)
		if combo % 5 == 0:
			UiKit.burst(card, card.size / 2.0, Tokens.COIN, 40)
	else:
		wrong += 1
		combo = 0
		combo_label.text = "الإجابة %d" % int(problem["answer"])
		Sfx.play("wrong")
		Settings.vibrate(35)
		Motion.shake(card)
	_new_problem()


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	hud_l.text = "%02d ث  ·  %d صحيحة" % [ceili(maxf(time_left, 0.0)), correct]
	if time_left <= 0.0:
		running = false
		var bonus := level_id - 1
		var stars := 0
		for g in GOALS:
			if correct >= g + bonus:
				stars += 1
		finish(stars, score, "%d صحيحة و%d خاطئة في 60 ثانية" % [correct, wrong])
