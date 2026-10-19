extends Screen
## Settings: separate music/sfx volume, haptics, reduce motion, colorblind, fps cap, quality, perf overlay.

func _ready() -> void:
	build_screen("الإعدادات", Color("#2CC9B5"))
	section("الصوت")
	body.add_child(_slider("الموسيقى", "music"))
	body.add_child(_slider("المؤثرات الصوتية", "sfx"))
	section("التجربة")
	body.add_child(_toggle("الاهتزاز", "haptics"))
	body.add_child(_toggle("تقليل الحركة", "reduce_motion"))
	body.add_child(_toggle("وضع عمى الألوان", "colorblind"))
	section("الأداء")
	body.add_child(_choice("حد الإطارات", "fps", [[60, "60"], [30, "30 (توفير البطارية)"]]))
	body.add_child(_choice("جودة الرسوم", "quality", [["auto", "تلقائي"], ["high", "عالية"], ["balanced", "متوازنة"], ["low", "منخفضة"]]))
	body.add_child(_toggle("عرض مؤشر الأداء", "show_perf"))
	var tier_names := {"high": "عالية", "balanced": "متوازنة", "low": "منخفضة"}
	var note := UiKit.label("المستخدم الآن: %s. المنخفضة توقف حركة الخلفيات وتقلل الشرر، والتلقائي يخفض الجودة وحده إذا تباطأ الجهاز." % tier_names.get(Quality.tier(), ""), Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	body.add_child(note)
	if str(Settings.get_value("quality")) == "auto" and Quality.tier() != "high":
		var retry := UiKit.button("أعد فحص الجودة التلقائية", UiKit.Variant.GHOST)
		retry.pressed.connect(func():
			Quality.reset_auto()
			note.text = "أُعيد الضبط إلى عالية. سيُقاس الأداء أثناء اللعب.")
		body.add_child(retry)
	var howto := UiKit.icon_button("hint", "أعد إظهار شرح الألعاب", UiKit.Variant.GHOST)
	howto.pressed.connect(func():
		SaveService.section("howto_seen").clear()
		SaveService.mark_dirty()
		howto.text = "سيظهر الشرح عند فتح كل لعبة"
		howto.disabled = true)
	body.add_child(howto)
	section("النسخ الاحتياطي")
	_backup_card()
	if OS.is_debug_build():
		section("للمطور")
		var dev := UiKit.button("أدوات المطور والاختبارات", UiKit.Variant.GHOST)
		dev.pressed.connect(func(): Router.go("res://devtools/lab_hub.tscn", accent))
		body.add_child(dev)


func _row(title: String) -> Array:
	var c := UiKit.card(1)
	var v := UiKit.vbox(Tokens.SP_S)
	c.add_child(v)
	v.add_child(UiKit.label(title, Tokens.FS_BODY, Tokens.TEXT, Tokens.font_bold))
	return [c, v]


func _slider(title: String, key: String) -> PanelContainer:
	var r := _row(title)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Settings.get_value(key))
	s.custom_minimum_size = Vector2(0, 56)
	s.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var track := StyleBoxFlat.new()
	track.bg_color = Tokens.SURFACE_2
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(6)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.value_changed.connect(func(v: float): Settings.set_value(key, v))
	s.drag_ended.connect(func(_c: bool): Sfx.play("tap"))
	r[1].add_child(s)
	return r[0]


func _toggle(title: String, key: String) -> PanelContainer:
	var c := UiKit.card(1)
	var t := CheckButton.new()
	t.text = title
	t.button_pressed = bool(Settings.get_value(key))
	t.add_theme_font_override("font", Tokens.font_bold)
	t.add_theme_font_size_override("font_size", Tokens.FS_BODY)
	for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		t.add_theme_color_override(k, Tokens.TEXT)
	t.custom_minimum_size = Vector2(0, 64)
	t.focus_mode = Control.FOCUS_NONE
	t.toggled.connect(func(on: bool):
		Settings.set_value(key, on)
		Sfx.play("tap"))
	c.add_child(t)
	return c


func _choice(title: String, key: String, options: Array) -> PanelContainer:
	var r := _row(title)
	var h := UiKit.hbox(Tokens.SP_S)
	r[1].add_child(h)
	var buttons: Array[Button] = []
	for o in options:
		var b := UiKit.button(str(o[1]), UiKit.Variant.SECONDARY, Tokens.LINE)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		b.add_theme_font_size_override("font_size", Tokens.FS_CAPTION)
		b.toggle_mode = true
		b.button_pressed = Settings.get_value(key) == o[0]
		h.add_child(b)
		buttons.append(b)
	for i in buttons.size():
		var val = options[i][0]
		buttons[i].pressed.connect(func():
			Settings.set_value(key, val)
			for j in buttons.size():
				buttons[j].set_pressed_no_signal(j == i))
	return r[0]


# ---------- export / import ----------
func _backup_card() -> void:
	var c := UiKit.card(1)
	var v := UiKit.vbox(Tokens.SP_S)
	c.add_child(v)
	v.add_child(UiKit.label("انسخ تقدمك كنص واحفظه في مكان آمن (ملاحظاتك أو رسالة لنفسك). ستحتاجه إذا غيّرت الجوال أو حذفت التطبيق.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	var status := UiKit.label("", Tokens.FS_CAPTION, Tokens.SUCCESS, Tokens.font_bold)
	var exp_b := UiKit.button("تصدير: نسخ الحفظ", UiKit.Variant.PRIMARY, accent)
	exp_b.pressed.connect(func():
		SaveService.save_now()
		DisplayServer.clipboard_set(SaveTransfer.encode(SaveService.store.data))
		status.add_theme_color_override("font_color", Tokens.SUCCESS)
		status.text = "تم النسخ. الصقه في مكان آمن الآن."
		Sfx.play("correct"))
	v.add_child(exp_b)
	var imp_b := UiKit.button("استيراد: لصق حفظ", UiKit.Variant.SECONDARY, accent)
	v.add_child(imp_b)
	v.add_child(status)
	var confirm_box := UiKit.vbox(Tokens.SP_S)
	confirm_box.visible = false
	v.add_child(confirm_box)
	var pending := {}
	imp_b.pressed.connect(func():
		for ch in confirm_box.get_children():
			ch.queue_free()
		var res := SaveTransfer.decode(DisplayServer.clipboard_get())
		if not bool(res["ok"]):
			status.add_theme_color_override("font_color", Tokens.ERROR)
			status.text = str(res["error"]) + " انسخ نص الحفظ كاملًا ثم اضغط استيراد."
			confirm_box.visible = false
			Sfx.play("wrong")
			return
		pending["data"] = res["data"]
		status.text = ""
		confirm_box.visible = true
		confirm_box.add_child(UiKit.label("الحفظ الموجود في الحافظة:\n" + SaveTransfer.summary(res["data"]), Tokens.FS_BODY, Tokens.TEXT, Tokens.font_bold))
		confirm_box.add_child(UiKit.label("حفظك الحالي:\n" + SaveTransfer.summary(SaveService.store.data), Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
		confirm_box.add_child(UiKit.label("الاستيراد يستبدل تقدمك الحالي بالكامل. نحتفظ بنسخة من الحالي على الجهاز للطوارئ.", Tokens.FS_CAPTION, Tokens.ERROR))
		var row := UiKit.hbox(Tokens.SP_S)
		var yes := UiKit.button("استبدل تقدمي", UiKit.Variant.PRIMARY, Tokens.ERROR)
		yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var no := UiKit.button("إلغاء", UiKit.Variant.GHOST)
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(yes)
		row.add_child(no)
		confirm_box.add_child(row)
		no.pressed.connect(func(): confirm_box.visible = false)
		yes.pressed.connect(func():
			if SaveService.replace_all(pending["data"]):
				Sfx.play("win")
				Router.go("res://meta/home.tscn")
			else:
				status.add_theme_color_override("font_color", Tokens.ERROR)
				status.text = "تعذّر الاستيراد. لم يتغير شيء."))
	body.add_child(c)
