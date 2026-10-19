extends Screen
## Achievements list: unlocked first, each with a progress bar and its reward.

func _ready() -> void:
	back_target = "res://meta/profile_screen.tscn"
	build_screen("الإنجازات", Tokens.COIN)
	Progress.check_achievements()   # catches anything earned before this version
	var m := Progress.model
	var gw := Progress.game_world_map()
	var defs: Array = Achievements.defs().duplicate()
	var done := 0
	for a in defs:
		if Achievements.is_unlocked(a, m):
			done += 1
	body.add_child(UiKit.label("أنجزت %d من %d" % [done, defs.size()], Tokens.FS_H2, Tokens.COIN, Tokens.font_bold))
	defs.sort_custom(func(a, b): return int(Achievements.is_unlocked(a, m)) > int(Achievements.is_unlocked(b, m)))
	var rows: Array = []
	for a in defs:
		var unlocked := Achievements.is_unlocked(a, m)
		var p := Achievements.progress_of(a, m, gw)
		var c := UiKit.card(1, Tokens.SURFACE_2 if unlocked else Tokens.SURFACE_1)
		var v := UiKit.vbox(Tokens.SP_XS)
		c.add_child(v)
		var h := UiKit.hbox(Tokens.SP_S)
		var t := UiKit.label(str(a["title"]), Tokens.FS_BODY, Tokens.COIN if unlocked else Tokens.TEXT, Tokens.font_bold)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		var rw := []
		if int(a["xp"]) > 0:
			rw.append("%d XP" % int(a["xp"]))
		if int(a["coins"]) > 0:
			rw.append("%d عملة" % int(a["coins"]))
		h.add_child(UiKit.label("تم" if unlocked else " + ".join(PackedStringArray(rw)), Tokens.FS_CAPTION, Tokens.SUCCESS if unlocked else Tokens.TEXT_MUTED, Tokens.font_bold))
		v.add_child(h)
		v.add_child(UiKit.label(str(a["desc"]), Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
		if not unlocked:
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 10)
			bar.max_value = float(p[1])
			bar.value = float(p[0])
			var bg := StyleBoxFlat.new()
			bg.bg_color = Tokens.LINE
			bg.set_corner_radius_all(5)
			var fill := StyleBoxFlat.new()
			fill.bg_color = Tokens.COIN
			fill.set_corner_radius_all(5)
			bar.add_theme_stylebox_override("background", bg)
			bar.add_theme_stylebox_override("fill", fill)
			v.add_child(bar)
			var pl := UiKit.label("%d / %d" % [p[0], p[1]], Tokens.FS_MIN, Tokens.TEXT_MUTED)
			pl.text_direction = Control.TEXT_DIRECTION_LTR
			v.add_child(pl)
		body.add_child(c)
		rows.append(c)
	await get_tree().process_frame
	Motion.enter_stagger(rows.slice(0, 8))
