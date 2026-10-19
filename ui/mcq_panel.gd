class_name McqPanel
extends PanelContainer
## Shared multiple-choice round UI: question (text or custom visual), 4 answers,
## timer ring, feedback (flash, shake, burst, sound), explanation, then `answered`.

signal answered(correct: bool, time_left: float)

const TIME := 10.0

var accent := Color.WHITE
var question_label: Label
var visual_holder: Control
var buttons: Array[Button] = []
var explanation: Label
var timer_label: Label
var _q: Dictionary = {}
var _time := TIME
var _active := false


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.card_style(Tokens.SURFACE_1, Tokens.RADIUS_CARD, 2))


func build(p_accent: Color) -> void:
	accent = p_accent
	var v := UiKit.vbox(Tokens.SP_M)
	add_child(v)
	var top := UiKit.hbox(Tokens.SP_S)
	question_label = UiKit.heading("", Tokens.FS_H2 + 2, Tokens.TEXT)
	question_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(question_label)
	timer_label = UiKit.label("", Tokens.FS_H2, accent, Tokens.font_bold)
	timer_label.text_direction = Control.TEXT_DIRECTION_LTR
	top.add_child(timer_label)
	v.add_child(top)
	visual_holder = Control.new()
	visual_holder.custom_minimum_size = Vector2(0, 0)
	v.add_child(visual_holder)
	for i in 4:
		var b := UiKit.button("", UiKit.Variant.SECONDARY, accent)
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var idx := i
		b.pressed.connect(func(): _pick(idx))
		v.add_child(b)
		buttons.append(b)
	explanation = UiKit.label("", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	v.add_child(explanation)


## q: {question, answers[4], correct, explanation}. visual: optional Control shown above answers.
func show_question(q: Dictionary, visual: Control = null, visual_height := 0.0) -> void:
	_q = q
	question_label.text = str(q["question"])
	for c in visual_holder.get_children():
		c.queue_free()
	visual_holder.custom_minimum_size = Vector2(0, visual_height)
	if visual:
		visual.set_anchors_preset(Control.PRESET_FULL_RECT)
		visual_holder.add_child(visual)
	for i in 4:
		buttons[i].text = str(q["answers"][i])
		buttons[i].disabled = false
		buttons[i].modulate = Color.WHITE
	explanation.text = ""
	_time = TIME
	_active = true
	Motion.fade_in(self, Motion.FAST)


func _process(delta: float) -> void:
	if not _active:
		return
	_time -= delta
	timer_label.text = "%02d" % ceili(maxf(_time, 0.0))
	timer_label.add_theme_color_override("font_color", Tokens.ERROR if _time < 3.0 else accent)
	if _time <= 0.0:
		_pick(-1)


func _pick(idx: int) -> void:
	if not _active:
		return
	_active = false
	var c := int(_q["correct"])
	var ok := idx == c
	for b in buttons:
		b.disabled = true
	if ok:
		Sfx.play("correct")
		Settings.vibrate(15)
		Motion.pop_in(buttons[idx])   # no flash: its tween would reset the green color
		UiKit.burst(self, buttons[idx].get_global_rect().get_center() - global_position, Tokens.SUCCESS, 40)   # on the panel: buttons clip their children
	else:
		Sfx.play("wrong")
		Settings.vibrate(40)
		if idx >= 0:
			Motion.shake(buttons[idx])
			buttons[idx].modulate = Tokens.ERROR
	buttons[c].modulate = Tokens.SUCCESS
	var head := "صحيح. " if ok else ("انتهى الوقت. " if idx < 0 else "خطأ. ")
	explanation.text = head + str(_q.get("explanation", ""))
	await UiKit.wait(self, 1.4 if ok else 2.2)
	answered.emit(ok, maxf(_time, 0.0))
