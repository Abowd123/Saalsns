extends Screen
## Profile and stats: level, XP, coins, totals, per-game bests, last results.

func _ready() -> void:
	build_screen("ملفك", Color("#F5B33D"))
	var new_achs := Progress.check_achievements()   # before reading coins/XP so numbers are current
	var m := Progress.model
	var lv := ProgressModel.level_from_xp(m.xp())
	var top := UiKit.card(2)
	var h := UiKit.hbox(Tokens.SP_M)
	top.add_child(h)
	var ring := LevelRing.new()
	ring.custom_minimum_size = Vector2(130, 130)
	ring.set_values(int(lv["level"]), 0.0)
	h.add_child(ring)
	var v := UiKit.vbox(Tokens.SP_XS)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := str(SaveService.section("profile").get("name", ""))
	v.add_child(UiKit.heading(nm if nm != "" else "لاعب مدار", Tokens.FS_H2))
	v.add_child(UiKit.label("المستوى %d  ·  %d / %d XP" % [lv["level"], lv["into"], lv["needed"]], Tokens.FS_BODY, Tokens.TEXT_MUTED))
	v.add_child(UiKit.label("%d عملة" % m.coins(), Tokens.FS_BODY, Tokens.COIN, Tokens.font_bold))
	h.add_child(v)
	var av := AvatarView.new()
	av.custom_minimum_size = Vector2(130, 130)
	av.set_item(Store.equipped(m, SaveService.section("profile"), "avatar"))
	h.add_child(av)
	body.add_child(top)

	for a in new_achs:
		var badge := UiKit.card(1, Tokens.SURFACE_2)
		badge.add_child(UiKit.label("إنجاز جديد: %s  ·  %s" % [a["title"], a["desc"]], Tokens.FS_CAPTION, Tokens.COIN, Tokens.font_bold))
		body.add_child(badge)
	var done := 0
	for a in Achievements.defs():
		if Achievements.is_unlocked(a, m):
			done += 1
	var links := UiKit.hbox(Tokens.SP_S)
	var ab := UiKit.icon_button("trophy", "الإنجازات  %d/%d" % [done, Achievements.defs().size()], UiKit.Variant.PRIMARY, Tokens.COIN)
	ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab.pressed.connect(func(): Router.go("res://meta/achievements_screen.tscn", Tokens.COIN))
	var sb := UiKit.icon_button("bag", "المتجر", UiKit.Variant.SECONDARY, Tokens.COIN)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb.pressed.connect(func(): Router.go("res://meta/store_screen.tscn", Tokens.COIN))
	links.add_child(ab)
	links.add_child(sb)
	body.add_child(links)

	section("الإحصائيات")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Tokens.SP_S)
	grid.add_theme_constant_override("v_separation", Tokens.SP_S)
	for pair in [["مجموع XP", str(m.xp())], ["النجوم", str(m.total_stars())], ["جولات اللعب", str(m.total_plays())], ["المكافآت المستلمة", str(m.d["ledger"].size())], ["سلسلة الأيام", str(m.current_streak(Progress.today_key()))], ["أطول سلسلة", str(int(m.d["daily_streak_best"]))]]:
		var c := UiKit.card(1, Tokens.SURFACE_2)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UiKit.vbox(0)
		cv.add_child(UiKit.label(pair[0], Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
		cv.add_child(UiKit.heading(pair[1], Tokens.FS_H1))
		c.add_child(cv)
		grid.add_child(c)
	body.add_child(grid)

	section("آخر النتائج")
	var hist: Array = m.d["history"]
	if hist.is_empty():
		body.add_child(UiKit.label("لم تلعب بعد. نتائجك ستظهر هنا.", Tokens.FS_BODY, Tokens.TEXT_MUTED))
	for i in range(hist.size() - 1, maxi(-1, hist.size() - 11), -1):
		var e: Dictionary = hist[i]
		var g := Catalog.get_game(str(e.get("g", "")))
		var title := str(g.get("title", e.get("g", "")))
		var when := Time.get_datetime_string_from_unix_time(int(e.get("t", 0))).replace("T", "  ").left(17)
		var row := UiKit.card(0, Tokens.SURFACE_1)
		var rh := UiKit.hbox(Tokens.SP_S)
		row.add_child(rh)
		var l := UiKit.label("%s  ·  المرحلة %d  ·  %d نجوم  ·  %d نقطة" % [title, int(e.get("l", 0)), int(e.get("s", 0)), int(e.get("sc", 0))], Tokens.FS_CAPTION, Tokens.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(l)
		var tl := UiKit.label(when, Tokens.FS_MIN, Tokens.TEXT_MUTED)
		tl.text_direction = Control.TEXT_DIRECTION_LTR
		rh.add_child(tl)
		body.add_child(row)
	await get_tree().process_frame
	ring.animate_to(float(lv["into"]) / float(lv["needed"]))
