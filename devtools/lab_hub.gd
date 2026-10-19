extends Screen
## Phase 1 entry: brand splash + links to Style Lab and Motion Lab.

func _ready() -> void:
	build_screen("أدوات المطور", Color("#2CC9B5"), true)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/brand/logo_mark_512.png")
	logo.custom_minimum_size = Vector2(0, 300)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(logo)
	var name_l := UiKit.heading("مدار", Tokens.FS_DISPLAY)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(name_l)
	var tag := UiKit.label("أربعة عوالم، عقل واحد", Tokens.FS_BODY, Tokens.TEXT_MUTED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(tag)

	var b1 := UiKit.button("مختبر الأسلوب: الألوان والخطوط والمكونات", UiKit.Variant.PRIMARY, Color("#2CC9B5"))
	b1.pressed.connect(func(): Router.go("res://devtools/style_lab.tscn", Color("#2CC9B5")))
	var b2 := UiKit.button("مختبر الحركة: كل رموز الحركة", UiKit.Variant.SECONDARY, Color("#F5B33D"))
	b2.pressed.connect(func(): Router.go("res://devtools/motion_lab.tscn", Color("#F5B33D")))
	var b3 := UiKit.button("اختبارات الأنظمة", UiKit.Variant.PRIMARY, Color("#9BDB4D"))
	b3.pressed.connect(func(): Router.go("res://devtools/test_runner.tscn", Color("#9BDB4D")))
	var b4 := UiKit.button("لعبة تجريبية: الدورة الكاملة", UiKit.Variant.SECONDARY, Color("#FF5E6C"))
	b4.pressed.connect(func(): Router.play_game("demo_tap", 1))
	var b5 := UiKit.button("الإعدادات", UiKit.Variant.SECONDARY, Color("#2CC9B5"))
	b5.pressed.connect(func(): Router.go("res://meta/settings_screen.tscn", Color("#2CC9B5")))
	var lv := ProgressModel.level_from_xp(Progress.model.xp())
	var status := UiKit.label("المستوى %d  ·  %d/%d XP  ·  %d عملة" % [lv["level"], lv["into"], lv["needed"], Progress.model.coins()], Tokens.FS_BODY, Tokens.COIN, Tokens.font_bold)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(status)
	body.add_child(b1)
	body.add_child(b2)
	body.add_child(b3)
	body.add_child(b4)
	body.add_child(b5)
	var b6 := UiKit.button("فاحص مراحل ارسم الحل", UiKit.Variant.SECONDARY, Color("#9BDB4D"))
	b6.pressed.connect(func(): Router.go("res://devtools/build_verifier.tscn", Color("#9BDB4D")))
	body.add_child(b6)
	var b7 := UiKit.button("مراجعة الأسئلة (بوابة الإصدار)", UiKit.Variant.SECONDARY, Color("#F5B33D"))
	b7.pressed.connect(func(): Router.go("res://devtools/review_screen.tscn", Color("#F5B33D")))
	body.add_child(b7)
	var b8 := UiKit.button("فحص الأداء (20 ثانية)", UiKit.Variant.SECONDARY, Color("#FF5E6C"))
	b8.pressed.connect(func(): Router.go("res://devtools/bench_screen.tscn", Color("#FF5E6C")))
	body.add_child(b8)
	var b9 := UiKit.button("بوابة الإصدار (الفحص النهائي)", UiKit.Variant.PRIMARY, Tokens.SUCCESS)
	b9.pressed.connect(func(): Router.go("res://devtools/release_gate.tscn", Tokens.SUCCESS))
	body.add_child(b9)
	var note := UiKit.label("قبل أي إصدار: شغّل «بوابة الإصدار» وأكمل الفحوص اليدوية، ثم انسخ التقرير وأرسله.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)

	_intro(logo, [name_l, tag, status, b1, b2, b3, b4, b5, b6, b7, b8, b9, note])


func _intro(logo: Control, rest: Array) -> void:
	await get_tree().process_frame
	Motion.pop_in(logo)
	Sfx.play("pop")
	for c in rest:
		c.modulate.a = 0.0
	await get_tree().create_timer(Motion.POP).timeout
	Motion.enter_stagger(rest)
