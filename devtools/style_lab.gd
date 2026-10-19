extends Screen
## Visual QA: palette, type scale, buttons, cards, world cards, result panels.

func _ready() -> void:
	back_target = "res://devtools/lab_hub.tscn"
	build_screen("مختبر الأسلوب", Color("#2CC9B5"))

	section("الألوان")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", Tokens.SP_S)
	grid.add_theme_constant_override("v_separation", Tokens.SP_S)
	body.add_child(grid)
	var swatches := [
		["الخلفية", Tokens.BG, "#0E1424"], ["سطح 1", Tokens.SURFACE_1, "#161E33"], ["سطح 2", Tokens.SURFACE_2, "#1E2843"],
		["نص", Tokens.TEXT, "#EEF2FA"], ["نص ثانوي", Tokens.TEXT_MUTED, "#9AA6C2"], ["العملات", Tokens.COIN, "#FFD45C"],
		["المعرفة", Tokens.world_color(Tokens.World.KNOWLEDGE), "#F5B33D"], ["الألغاز", Tokens.world_color(Tokens.World.PUZZLES), "#2CC9B5"], ["السرعة", Tokens.world_color(Tokens.World.SPEED), "#FF5E6C"],
		["البناء", Tokens.world_color(Tokens.World.BUILD), "#9BDB4D"], ["نجاح", Tokens.SUCCESS, "#3DDC84"], ["خطأ", Tokens.ERROR, "#FF5A5A"],
	]
	for s in swatches:
		grid.add_child(_swatch(s[0], s[1], s[2]))

	section("الخطوط")
	var tc := UiKit.card()
	var tv := UiKit.vbox(Tokens.SP_S)
	tc.add_child(tv)
	tv.add_child(UiKit.heading("عنوان كبير ٥٦", Tokens.FS_DISPLAY))
	tv.add_child(UiKit.heading("عنوان القسم ٣٦", Tokens.FS_H1))
	tv.add_child(UiKit.label("نص بارز ٢٨", Tokens.FS_H2, Tokens.TEXT, Tokens.font_bold))
	tv.add_child(UiKit.label("نص أساسي ٢٤: ما عاصمة أستراليا؟ كانبرا، وليست سيدني كما يظن كثيرون.", Tokens.FS_BODY))
	tv.add_child(UiKit.label("نص ثانوي ٢٠: المرحلة 12 من 60 · أفضل نتيجة 1,250", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	tv.add_child(UiKit.label("تشكيل: مَدَارٌ: أَرْبَعَةُ عَوَالِمَ، عَقْلٌ وَاحِدٌ", Tokens.FS_BODY, Tokens.world_color(Tokens.World.KNOWLEDGE)))
	tv.add_child(UiKit.label("نص طويل لاختبار الالتفاف: يجب أن ينكسر السطر بين الكلمات لا داخلها، وأن تبقى علامات الترقيم في مكانها الصحيح في نهاية الجملة العربية.", Tokens.FS_BODY, Tokens.TEXT_MUTED))
	body.add_child(tc)

	section("الأزرار")
	var row := UiKit.hbox(Tokens.SP_S)
	var p := UiKit.button("ابدأ اللعب", UiKit.Variant.PRIMARY, Color("#2CC9B5"))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s2 := UiKit.button("إعادة", UiKit.Variant.SECONDARY, Color("#2CC9B5"))
	s2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(p)
	row.add_child(s2)
	row.add_child(UiKit.button("؟", UiKit.Variant.ICON))
	body.add_child(row)
	var row2 := UiKit.hbox(Tokens.SP_S)
	var g := UiKit.button("لاحقًا", UiKit.Variant.GHOST)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var d := UiKit.button("مقفلة", UiKit.Variant.PRIMARY, Color("#F5B33D"))
	d.disabled = true
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(g)
	row2.add_child(d)
	body.add_child(row2)

	section("بطاقات العوالم")
	var wg := GridContainer.new()
	wg.columns = 2
	wg.add_theme_constant_override("h_separation", Tokens.SP_S)
	wg.add_theme_constant_override("v_separation", Tokens.SP_S)
	body.add_child(wg)
	var prog := [0.62, 0.40, 0.25, 0.10]
	for w in [Tokens.World.KNOWLEDGE, Tokens.World.PUZZLES, Tokens.World.SPEED, Tokens.World.BUILD]:
		var wc := UiKit.world_card(w, 3, prog[w])
		wc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wg.add_child(wc)

	section("شاشتا النجاح والخسارة")
	body.add_child(_result(true))
	body.add_child(_result(false))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	body.add_child(spacer)


func _swatch(name: String, color: Color, hex: String) -> PanelContainer:
	var c := PanelContainer.new()
	var st := UiKit.card_style(color, 16, 0)
	if color == Tokens.BG:
		st.set_border_width_all(1)
		st.border_color = Tokens.LINE
	c.add_theme_stylebox_override("panel", st)
	c.custom_minimum_size = Vector2(0, 120)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_END
	var fg := Tokens.BG if color.get_luminance() > 0.5 else Tokens.TEXT
	v.add_child(UiKit.label(name, Tokens.FS_CAPTION, fg, Tokens.font_bold))
	var h := UiKit.label(hex, Tokens.FS_MIN, fg)
	h.text_direction = Control.TEXT_DIRECTION_LTR
	v.add_child(h)
	c.add_child(v)
	return c


func _result(win: bool) -> PanelContainer:
	var c := UiKit.card(2)
	var v := UiKit.vbox(Tokens.SP_S)
	c.add_child(v)
	if win:
		v.add_child(UiKit.heading("أحسنت! 3 نجوم", Tokens.FS_H2 + 2, Tokens.SUCCESS))
		v.add_child(UiKit.label("+120 XP  ·  +15 عملة  ·  حللتها في 14 حركة (الأمثل 14)", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	else:
		v.add_child(UiKit.heading("قريب جدًا", Tokens.FS_H2 + 2, Tokens.ERROR))
		v.add_child(UiKit.label("سقط البرج بعد 3.2 ثانية. جرّب قاعدة أعرض.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	var r := UiKit.hbox(Tokens.SP_S)
	var a := UiKit.button("التالي" if win else "حاول مجددًا", UiKit.Variant.PRIMARY, Tokens.SUCCESS if win else Tokens.world_color(Tokens.World.SPEED))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := UiKit.button("إعادة" if win else "تلميح", UiKit.Variant.SECONDARY, Tokens.LINE)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(a)
	r.add_child(b)
	v.add_child(r)
	return c
