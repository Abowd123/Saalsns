extends Screen
## Motion QA: every motion token on real components. Each demo has a replay button.

var stagger_cards: Array = []
var stars: Array = []
var coin_label: Label
var coins := 120
var answer_ok: Button
var answer_bad: Button
var celebrate_panel: PanelContainer
var anim: AnimationPlayer


func _ready() -> void:
	back_target = "res://devtools/lab_hub.tscn"
	build_screen("مختبر الحركة", Color("#F5B33D"))
	_top_bar()
	_demo_tap()
	_demo_stagger()
	_demo_stars()
	_demo_answers()
	_demo_coins()
	_demo_celebrate()
	_demo_misc()
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 80)
	body.add_child(spacer)


func _demo_header(title: String, token: String) -> void:
	var h := UiKit.hbox(Tokens.SP_S)
	var t := UiKit.label(title, Tokens.FS_H2, Tokens.TEXT, Tokens.font_display)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var k := UiKit.label(token, Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	k.text_direction = Control.TEXT_DIRECTION_LTR
	h.add_child(k)
	body.add_child(h)


func _top_bar() -> void:
	var c := UiKit.card(1, Tokens.SURFACE_2)
	var h := UiKit.hbox(Tokens.SP_S)
	c.add_child(h)
	var lv := UiKit.label("المستوى 7", Tokens.FS_BODY, Tokens.TEXT, Tokens.font_bold)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lv)
	coin_label = UiKit.label("%d عملة" % coins, Tokens.FS_BODY, Tokens.COIN, Tokens.font_bold)
	h.add_child(coin_label)
	body.add_child(c)


# 1. tap
func _demo_tap() -> void:
	_demo_header("الضغط والارتداد", "tap 80ms / base back")
	var b := UiKit.button("اضغطني بقوة", UiKit.Variant.PRIMARY, Color("#F5B33D"))
	body.add_child(b)


# 2. stagger
func _demo_stagger() -> void:
	_demo_header("دخول البطاقات المتتابع", "base 280ms · stagger 60ms")
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", Tokens.SP_S)
	g.add_theme_constant_override("v_separation", Tokens.SP_S)
	body.add_child(g)
	for w in [Tokens.World.KNOWLEDGE, Tokens.World.PUZZLES, Tokens.World.SPEED, Tokens.World.BUILD]:
		var wc := UiKit.world_card(w, 3, 0.3)
		wc.custom_minimum_size = Vector2(0, 150)
		wc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(wc)
		stagger_cards.append(wc)
	var r := UiKit.button("إعادة الدخول", UiKit.Variant.SECONDARY, Color("#F5B33D"))
	r.pressed.connect(func(): Motion.enter_stagger(stagger_cards))
	body.add_child(r)


# 3. stars
func _demo_stars() -> void:
	_demo_header("منح النجوم", "pop 320ms out back")
	var row := UiKit.hbox(Tokens.SP_M)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var s := StarIcon.new()
		s.custom_minimum_size = Vector2(110, 110)
		row.add_child(s)
		stars.append(s)
	body.add_child(row)
	var b := UiKit.button("امنح 3 نجوم", UiKit.Variant.SECONDARY, Color("#F5B33D"))
	b.pressed.connect(_award_stars)
	body.add_child(b)


func _award_stars() -> void:
	for s in stars:
		s.filled = false
	for i in stars.size():
		await get_tree().create_timer(Motion.POP * 0.9).timeout
		var s: StarIcon = stars[i]
		s.filled = true
		Motion.pop_in(s)
		Sfx.play("star%d" % (i + 1))
		UiKit.burst(s, s.size / 2.0, Tokens.COIN, 28)


# 4. answers
func _demo_answers() -> void:
	_demo_header("الإجابة الصحيحة والخاطئة", "flash fast+base · shake")
	var q := UiKit.label("ما عاصمة أستراليا؟", Tokens.FS_BODY, Tokens.TEXT, Tokens.font_bold)
	body.add_child(q)
	var r := UiKit.hbox(Tokens.SP_S)
	answer_ok = UiKit.button("كانبرا", UiKit.Variant.SECONDARY, Tokens.LINE)
	answer_bad = UiKit.button("سيدني", UiKit.Variant.SECONDARY, Tokens.LINE)
	for a in [answer_ok, answer_bad]:
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(a)
	body.add_child(r)
	answer_ok.pressed.connect(func():
		Sfx.play("correct")
		Motion.flash(answer_ok, Tokens.SUCCESS)
		UiKit.burst(self, answer_ok.get_global_rect().get_center() - global_position, Tokens.SUCCESS, 40))
	answer_bad.pressed.connect(func():
		Sfx.play("wrong")
		Motion.shake(answer_bad)
		Motion.flash(answer_bad, Tokens.ERROR))


# 5. coins
func _demo_coins() -> void:
	_demo_header("ظهور العملات وطيرانها", "pop + base curve + counter")
	var b := UiKit.button("اكسب 15 عملة", UiKit.Variant.PRIMARY, Tokens.COIN)
	b.pressed.connect(func(): _fly_coins(b))
	body.add_child(b)


func _fly_coins(from: Control) -> void:
	var start := from.get_global_rect().get_center()
	var target := coin_label.get_global_rect().get_center()
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	for i in 8:
		var coin := Panel.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Tokens.COIN
		st.set_corner_radius_all(18)
		st.border_width_bottom = 4
		st.border_color = Tokens.COIN.darkened(0.3)
		coin.add_theme_stylebox_override("panel", st)
		coin.size = Vector2(36, 36)
		coin.position = start - coin.size / 2.0 + Vector2(randf_range(-60, 60), randf_range(-30, 30))
		layer.add_child(coin)
		Motion.pop_in(coin, i * 0.03)
		var tw := coin.create_tween()
		tw.tween_interval(Motion.POP + i * 0.05)
		tw.tween_property(coin, "position", target - coin.size / 2.0, Motion.BASE * 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			Sfx.play("coin", 1.0 + i * 0.04)
			coin.queue_free())
	await get_tree().create_timer(Motion.POP + 8 * 0.05 + Motion.BASE * 1.6).timeout
	Motion.count_to(coin_label, coins, coins + 15, "", " عملة")
	coins += 15
	coin_label.pivot_offset = coin_label.size / 2.0
	var tw2 := coin_label.create_tween()
	tw2.tween_property(coin_label, "scale", Vector2.ONE * 1.15, Motion.FAST)
	tw2.tween_property(coin_label, "scale", Vector2.ONE, Motion.BASE)
	await get_tree().create_timer(1.5).timeout
	layer.queue_free()


# 6. celebrate (AnimationPlayer, authored sequence)
func _demo_celebrate() -> void:
	_demo_header("احتفال الفوز", "celebrate 1.1s AnimationPlayer")
	celebrate_panel = UiKit.card(2)
	var v := UiKit.vbox(Tokens.SP_S)
	celebrate_panel.add_child(v)
	var h := UiKit.heading("فزت بالمرحلة!", Tokens.FS_H1, Tokens.SUCCESS)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	var s := UiKit.label("+120 XP", Tokens.FS_H2, Tokens.TEXT, Tokens.font_bold)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.text_direction = Control.TEXT_DIRECTION_LTR
	v.add_child(s)
	body.add_child(celebrate_panel)
	celebrate_panel.modulate.a = 0.0
	anim = AnimationPlayer.new()
	add_child(anim)
	anim.root_node = NodePath("..")
	var lib := AnimationLibrary.new()
	lib.add_animation("win", _build_win_animation())
	anim.add_animation_library("", lib)
	var b := UiKit.button("شغّل الاحتفال", UiKit.Variant.PRIMARY, Tokens.SUCCESS)
	b.pressed.connect(func():
		celebrate_panel.pivot_offset = celebrate_panel.size / 2.0
		anim.stop()
		anim.play("win"))
	body.add_child(b)


func _build_win_animation() -> Animation:
	var a := Animation.new()
	a.length = Motion.CELEBRATE
	var t_scale := a.add_track(Animation.TYPE_VALUE)
	var panel_path := str(get_path_to(celebrate_panel))
	a.track_set_path(t_scale, NodePath(panel_path + ":scale"))
	a.track_insert_key(t_scale, 0.0, Vector2(0.6, 0.6))
	a.track_insert_key(t_scale, 0.25, Vector2(1.08, 1.08))
	a.track_insert_key(t_scale, 0.45, Vector2(1.0, 1.0))
	a.track_insert_key(t_scale, 0.75, Vector2(1.03, 1.03))
	a.track_insert_key(t_scale, 1.1, Vector2(1.0, 1.0))
	var t_alpha := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t_alpha, NodePath(panel_path + ":modulate:a"))
	a.track_insert_key(t_alpha, 0.0, 0.0)
	a.track_insert_key(t_alpha, 0.18, 1.0)
	var t_call := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(t_call, NodePath("."))
	a.track_insert_key(t_call, 0.0, {"method": "_celebrate_fx", "args": [0]})
	a.track_insert_key(t_call, 0.45, {"method": "_celebrate_fx", "args": [1]})
	a.track_insert_key(t_call, 0.75, {"method": "_celebrate_fx", "args": [2]})
	return a


func _celebrate_fx(step: int) -> void:
	var c := celebrate_panel.size / 2.0
	match step:
		0:
			Sfx.play("win")
		1:
			UiKit.burst(celebrate_panel, c + Vector2(-180, 0), Tokens.world_color(Tokens.World.PUZZLES), 50)
			UiKit.burst(celebrate_panel, c + Vector2(180, 0), Tokens.world_color(Tokens.World.KNOWLEDGE), 50)
		2:
			UiKit.burst(celebrate_panel, c, Tokens.SUCCESS, 70)


# 7. misc: idle pulse, scene transition, reduce motion
func _demo_misc() -> void:
	_demo_header("نبض التحدي اليومي", "idle pulse كل 3.5s")
	var daily := UiKit.card(1, Tokens.SURFACE_2)
	var dl := UiKit.label("التحدي اليومي: 5 ألغاز صناديق  ·  ينتهي بعد 04:12:09", Tokens.FS_BODY, Tokens.TEXT, Tokens.font_bold)
	daily.add_child(dl)
	body.add_child(daily)
	_start_pulse(daily)

	_demo_header("انتقال المشهد", "scene 450ms radial wipe")
	var t := UiKit.button("انتقل إلى مختبر الأسلوب", UiKit.Variant.SECONDARY, Color("#2CC9B5"))
	t.pressed.connect(func(): Router.go("res://devtools/style_lab.tscn", Color("#2CC9B5"), Vector2(0.5, 0.85)))
	body.add_child(t)

	_demo_header("تقليل الحركة", "reduce_motion")
	var rm := CheckButton.new()
	rm.text = "تفعيل تقليل الحركة (يلغي الاهتزاز والانزلاق)"
	rm.add_theme_font_override("font", Tokens.font_body)
	rm.add_theme_font_size_override("font_size", Tokens.FS_BODY)
	rm.add_theme_color_override("font_color", Tokens.TEXT)
	rm.add_theme_color_override("font_pressed_color", Tokens.TEXT)
	rm.button_pressed = Motion.reduce_motion
	rm.toggled.connect(func(on: bool): Motion.reduce_motion = on)
	body.add_child(rm)


func _start_pulse(c: Control) -> void:
	await get_tree().process_frame
	Motion.idle_pulse(c)
