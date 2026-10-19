extends Screen
## Home: profile bar, continue, daily challenge, 4 worlds, recent games, progress.
## Sections with no real content are hidden. No fake game cards, ever.

var ring: LevelRing
var coin_label: Label
var daily_timer: Label
var _entering: Array = []


func _ready() -> void:
	build_screen("", Color("#2CC9B5"), false)
	header.get_child(0).queue_free()   # home has its own top bar instead of a title
	_profile_bar()
	_continue_card()
	_daily_card()
	_worlds()
	_recent()
	_progress_card()
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	body.add_child(spacer)
	Music.play("res://assets/music/ambient_menu.ogg")
	Progress.changed.connect(_refresh_top)
	_intro()
	if str(SaveService.section("profile").get("name", "")) == "" and not bool(SaveService.section("profile").get("onboarded", false)):
		_onboarding()


func _intro() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	Motion.enter_stagger(_entering)
	var lv := ProgressModel.level_from_xp(Progress.model.xp())
	ring.animate_to(float(lv["into"]) / float(lv["needed"]))


func _add(c: Control) -> void:
	body.add_child(c)
	_entering.append(c)


# ---------- top bar ----------
func _profile_bar() -> void:
	var bar := UiKit.hbox(Tokens.SP_M)
	var lv := ProgressModel.level_from_xp(Progress.model.xp())
	ring = LevelRing.new()
	ring.set_values(int(lv["level"]), 0.0)
	var profile_btn := Button.new()
	profile_btn.flat = true
	profile_btn.focus_mode = Control.FOCUS_NONE
	profile_btn.custom_minimum_size = Vector2(Tokens.TOUCH_MIN, Tokens.TOUCH_MIN)
	profile_btn.add_child(ring)
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	profile_btn.pressed.connect(func():
		Sfx.play("tap")
		Router.go("res://meta/profile_screen.tscn", Color("#F5B33D")))
	bar.add_child(profile_btn)
	var names := UiKit.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := str(SaveService.section("profile").get("name", ""))
	names.add_child(UiKit.heading("مدار", Tokens.FS_H2 + 4))
	names.add_child(UiKit.label(("أهلًا يا %s" % nm) if nm != "" else "أربعة عوالم، عقل واحد", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	bar.add_child(names)
	var coins := UiKit.chip(str(Progress.model.coins()), Tokens.COIN, "coin", Tokens.COIN)
	coin_label = coins[1]
	coin_label.add_theme_font_size_override("font_size", Tokens.FS_BODY)
	var store_btn := Button.new()
	store_btn.flat = true
	store_btn.focus_mode = Control.FOCUS_NONE
	store_btn.add_child(coins[0])
	store_btn.custom_minimum_size = Vector2(0, Tokens.TOUCH_MIN)
	coins[0].set_anchors_preset(Control.PRESET_CENTER)
	coins[0].grow_horizontal = Control.GROW_DIRECTION_BOTH
	coins[0].grow_vertical = Control.GROW_DIRECTION_BOTH
	coins[0].mouse_filter = Control.MOUSE_FILTER_IGNORE
	store_btn.custom_minimum_size.x = 150
	store_btn.pressed.connect(func():
		Sfx.play("tap")
		Router.go("res://meta/store_screen.tscn", Tokens.COIN))
	bar.add_child(store_btn)
	var gear := UiKit.icon_button("settings", "", UiKit.Variant.ICON)
	gear.pressed.connect(func(): Router.go("res://meta/settings_screen.tscn", Color("#2CC9B5")))
	bar.add_child(gear)
	_add(bar)


func _refresh_top() -> void:
	UiKit.set_chip(coin_label, str(Progress.model.coins()))


# ---------- continue ----------
func _continue_card() -> void:
	var last := Progress.model.last_played()
	if last.is_empty():
		return
	var g := Catalog.get_game(str(last.get("g", "")))
	if g.is_empty():
		return
	var lvl := Progress.model.resume_level(g["id"], int(g["levels"]))
	var accent_c := Catalog.world_color(g)
	var c := PanelContainer.new()
	var st := UiKit.card_style(Tokens.SURFACE_1, Tokens.RADIUS_WORLD, 2)
	st.border_width_right = 6
	st.border_color = accent_c
	c.add_theme_stylebox_override("panel", st)
	var h := UiKit.hbox(Tokens.SP_M)
	c.add_child(h)
	var v := UiKit.vbox(Tokens.SP_XS)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.label("تابع من حيث توقفت", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	v.add_child(UiKit.heading(str(g["title"]), Tokens.FS_H2, accent_c))
	v.add_child(UiKit.label("المرحلة %d من %d" % [lvl, int(g["levels"])], Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	h.add_child(v)
	var play := UiKit.icon_button("play", "العب", UiKit.Variant.PRIMARY, accent_c)
	play.custom_minimum_size = Vector2(150, Tokens.TOUCH_MIN)
	play.pressed.connect(func(): Router.play_game(g["id"], lvl))
	h.add_child(play)
	UiKit.shine(play)
	_add(c)


# ---------- daily ----------
func _daily_card() -> void:
	var day := Progress.today_key()
	var status := Progress.model.daily_status(day)
	var ch := Progress.today_challenge()
	if ch.is_empty():
		return
	var g := Catalog.get_game(str(ch["game"]))
	var c := UiKit.card(1, Tokens.SURFACE_2)
	var v := UiKit.vbox(Tokens.SP_XS)
	c.add_child(v)
	var h := UiKit.hbox(Tokens.SP_S)
	var flame := UiKit.icon_rect("flame", 40, Tokens.COIN)
	h.add_child(flame)
	Motion.breathe(flame)
	var t := UiKit.heading("التحدي اليومي", Tokens.FS_H2, Tokens.COIN)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	daily_timer = UiKit.label("", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	daily_timer.text_direction = Control.TEXT_DIRECTION_LTR
	h.add_child(daily_timer)
	v.add_child(h)
	var streak := Progress.model.current_streak(day)
	var msg := ""
	match status:
		"claimed":
			msg = "أنجزت تحدي اليوم. سلسلتك %d يوم. تحدٍّ جديد بعد منتصف الليل." % streak
		"clock_rollback":
			msg = "تاريخ الجهاز أقدم من آخر تحدٍّ مسجل. صحّح التاريخ لتفعيل التحديات."
		_:
			var rw := Daily.reward(streak + 1)
			msg = "%s  ·  المرحلة %d  ·  %d نجوم على الأقل\nالجائزة: %d XP و%d عملة%s" % [ch["title"], int(ch["level"]), int(ch["target_stars"]), int(rw["xp"]), int(rw["coins"]), ("  ·  سلسلتك %d يوم" % streak) if streak > 0 else ""]
	v.add_child(UiKit.label(msg, Tokens.FS_BODY, Tokens.TEXT))
	if status == "available" and not g.is_empty():
		var play := UiKit.icon_button("play", "ابدأ التحدي", UiKit.Variant.PRIMARY, Tokens.COIN)
		var gid: String = ch["game"]
		var lvl := int(ch["level"])
		play.pressed.connect(func(): Router.play_game(gid, lvl, true))
		v.add_child(play)
		UiKit.shine(play, 4.4)
	_add(c)
	_tick_daily()
	if status == "available":
		_pulse_later(c)


func _pulse_later(c: Control) -> void:
	await UiKit.wait(self, Motion.BASE * 3)
	if is_instance_valid(c):
		Motion.idle_pulse(c)


func _tick_daily() -> void:
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_update_daily_timer)
	_update_daily_timer()


var _shown_day := 0


func _update_daily_timer() -> void:
	if _shown_day == 0:
		_shown_day = Progress.today_key()
	elif Progress.today_key() != _shown_day:
		# midnight passed while home was open: rebuild with the new challenge
		_shown_day = Progress.today_key()
		Progress.model.observe_date(_shown_day)
		Router.go("res://meta/home.tscn")
		return
	var t := Time.get_time_dict_from_system()
	var left := 86399 - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"]))
	daily_timer.text = "%02d:%02d:%02d" % [int(left / 3600.0), int((left % 3600) / 60.0), left % 60]


# ---------- worlds ----------
func _worlds() -> void:
	var title := UiKit.label("العوالم", Tokens.FS_H2, Tokens.TEXT_MUTED, Tokens.font_display)
	_add(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Tokens.SP_S)
	grid.add_theme_constant_override("v_separation", Tokens.SP_S)
	for key in ["knowledge", "puzzles", "speed", "build"]:
		var w: int = Catalog.WORLD_IDS[key]
		var games := _games_in(key)
		var total := 0
		var earned := 0
		for g in games:
			total += int(g["levels"]) * 3
			earned += Progress.model.stars_in_game(g["id"])
		var card := UiKit.world_card(w, games.size(), (float(earned) / total) if total > 0 else 0.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 190)
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(btn)
		var world_key: String = key
		btn.button_down.connect(func(): Motion.press(card))
		btn.button_up.connect(func(): Motion.release(card))
		btn.pressed.connect(func():
			Sfx.play("tap")
			Router.params = {"world": world_key}
			var center := card.get_global_rect().get_center() / get_viewport_rect().size
			Router.go("res://meta/world_screen.tscn", Tokens.world_color(w), center))
		grid.add_child(card)
	_add(grid)


func _games_in(world_key: String) -> Array:
	var out := []
	for g in Catalog.games:
		if g["world"] == world_key and (not bool(g.get("dev_only", false)) or OS.is_debug_build()):
			out.append(g)
	return out


# ---------- recent ----------
func _recent() -> void:
	var ids := Progress.model.recent_games(6)
	var valid := []
	for id in ids:
		var g := Catalog.get_game(id)
		if not g.is_empty():
			valid.append(g)
	if valid.is_empty():
		return
	_add(UiKit.label("لعبت مؤخرًا", Tokens.FS_H2, Tokens.TEXT_MUTED, Tokens.font_display))
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 150)
	var row := UiKit.hbox(Tokens.SP_S)
	sc.add_child(row)
	for g in valid:
		row.add_child(_mini_game_card(g))
	_add(sc)


func _mini_game_card(g: Dictionary) -> Control:
	var accent_c := Catalog.world_color(g)
	var b := UiKit.button("", UiKit.Variant.SECONDARY, accent_c)
	b.custom_minimum_size = Vector2(240, 130)
	b.text = "%s\n%d نجمة" % [g["title"], Progress.model.stars_in_game(g["id"])]
	b.add_theme_font_size_override("font_size", Tokens.FS_CAPTION + 2)
	b.pressed.connect(func(): Router.play_game(g["id"], Progress.model.resume_level(g["id"], int(g["levels"]))))
	return b


# ---------- progress ----------
func _progress_card() -> void:
	var c := UiKit.card(1)
	var v := UiKit.vbox(Tokens.SP_S)
	c.add_child(v)
	v.add_child(UiKit.heading("تقدمك", Tokens.FS_H2))
	var total_possible := 0
	for g in Catalog.games:
		if not bool(g.get("dev_only", false)) or OS.is_debug_build():
			total_possible += int(g["levels"]) * 3
	var stars := Progress.model.total_stars()
	v.add_child(UiKit.label("%d نجمة من %d  ·  %d جولة لعب" % [stars, total_possible, Progress.model.total_plays()], Tokens.FS_BODY, Tokens.TEXT_MUTED))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.value = 100.0 * stars / maxf(total_possible, 1)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Tokens.SURFACE_2
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Tokens.COIN
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	v.add_child(bar)
	var done := 0
	for a in Achievements.defs():
		if Achievements.is_unlocked(a, Progress.model):
			done += 1
	var ab := UiKit.icon_button("trophy", "الإنجازات  %d / %d" % [done, Achievements.defs().size()], UiKit.Variant.SECONDARY, Tokens.COIN)
	ab.pressed.connect(func(): Router.go("res://meta/achievements_screen.tscn", Tokens.COIN))
	v.add_child(ab)
	_add(c)


# ---------- first run ----------
func _onboarding() -> void:
	await UiKit.wait(self, Motion.SCENE)
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	Motion.fade_in(dim, Motion.BASE)
	# Sheet sits at the TOP: the Android keyboard covers the bottom half of the screen.
	var sheet := UiKit.card(2)
	sheet.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sheet.offset_left = Tokens.SP_M
	sheet.offset_right = -Tokens.SP_M
	sheet.offset_top = Tokens.SP_XL * 3
	sheet.grow_vertical = Control.GROW_DIRECTION_END
	layer.add_child(sheet)
	var v := UiKit.vbox(Tokens.SP_M)
	sheet.add_child(v)
	v.add_child(UiKit.heading("أهلًا بك في مدار", Tokens.FS_H1))
	v.add_child(UiKit.label("بماذا نناديك؟ (اختياري، ويبقى على جهازك فقط)", Tokens.FS_BODY, Tokens.TEXT_MUTED))
	var input := LineEdit.new()
	input.placeholder_text = "اسمك"
	input.max_length = 20
	input.custom_minimum_size = Vector2(0, Tokens.TOUCH_MIN)
	input.add_theme_font_override("font", Tokens.font_bold)
	input.add_theme_font_size_override("font_size", Tokens.FS_BODY)
	input.add_theme_color_override("font_color", Tokens.TEXT)
	input.add_theme_color_override("font_placeholder_color", Tokens.TEXT_MUTED)
	input.add_theme_stylebox_override("normal", UiKit.card_style(Tokens.SURFACE_2, Tokens.RADIUS_BUTTON, 0))
	input.add_theme_stylebox_override("focus", UiKit.card_style(Tokens.SURFACE_2, Tokens.RADIUS_BUTTON, 0))
	v.add_child(input)
	var h := UiKit.hbox(Tokens.SP_S)
	var ok := UiKit.button("ابدأ", UiKit.Variant.PRIMARY, Color("#2CC9B5"))
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skip := UiKit.button("تخطَّ", UiKit.Variant.GHOST)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ok)
	h.add_child(skip)
	v.add_child(h)
	var close := func(save_name: bool):
		var prof := SaveService.section("profile")
		if save_name:
			prof["name"] = input.text.strip_edges().left(20)
		prof["onboarded"] = true
		SaveService.save_now()
		Router.go("res://meta/home.tscn")
	ok.pressed.connect(func(): close.call(true))
	skip.pressed.connect(func(): close.call(false))
	await get_tree().process_frame
	var y := sheet.position.y
	sheet.position.y -= 500
	sheet.create_tween().tween_property(sheet, "position:y", y, Motion.BASE * 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
