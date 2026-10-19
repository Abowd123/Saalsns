extends Screen
## One world: its real games only, each with stars and a play button.
## A world without finished games shows an honest empty state (no fake cards).

var world_key := "puzzles"


func _ready() -> void:
	world_key = str(Router.params.get("world", "puzzles"))
	var w: int = Catalog.WORLD_IDS.get(world_key, Tokens.World.PUZZLES)
	build_screen(Tokens.WORLD_NAMES[w], Tokens.world_color(w))
	var items: Array = []
	var games := []
	for g in Catalog.games:
		if g["world"] == world_key and (not bool(g.get("dev_only", false)) or OS.is_debug_build()):
			games.append(g)
	if games.is_empty():
		var c := UiKit.card(1)
		var v := UiKit.vbox(Tokens.SP_S)
		c.add_child(v)
		v.add_child(UiKit.heading("قيد البناء", Tokens.FS_H2, accent))
		v.add_child(UiKit.label(_planned_text(), Tokens.FS_BODY, Tokens.TEXT_MUTED))
		body.add_child(c)
		items.append(c)
	for g in games:
		var card := _game_card(g)
		body.add_child(card)
		items.append(card)
	await get_tree().process_frame
	await get_tree().process_frame
	Motion.enter_stagger(items)


func _planned_text() -> String:
	match world_key:
		"knowledge":
			return "قادم: تحدي المعرفة، وعواصم وأعلام، وعقل الحساب."
		"puzzles":
			return "قادم: الصناديق، والأنابيب والتيار، وأعواد الثقاب."
		"speed":
			return "قادم: التعليمات المتغيرة، وذاكرة التسلسل، وتفادَ."
		_:
			return "قادم: ارسم الحل، وبرج التوازن، ومصنع التروس."


func _game_card(g: Dictionary) -> PanelContainer:
	var c := UiKit.card(1)
	var v := UiKit.vbox(Tokens.SP_S)
	c.add_child(v)
	var h := UiKit.hbox(Tokens.SP_S)
	var t := UiKit.heading(str(g["title"]), Tokens.FS_H2, accent)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if bool(g.get("dev_only", false)):
		h.add_child(UiKit.label("تجريبية", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	if bool(g.get("hard", false)):
		h.add_child(UiKit.chip("صعبة", Tokens.COIN, "flame", Tokens.ERROR)[0])
	v.add_child(h)
	if g.has("subtitle"):
		v.add_child(UiKit.label(str(g["subtitle"]), Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	var levels := int(g["levels"])
	var stars := Progress.model.stars_in_game(g["id"])
	v.add_child(UiKit.label("%d نجمة من %d  ·  أفضل نتيجة %d" % [stars, levels * 3, Progress.model.best_in_game(g["id"])], Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	# level path: one chip per level, locked until the previous level has a star
	var path := HFlowContainer.new()
	path.add_theme_constant_override("h_separation", Tokens.SP_S)
	path.add_theme_constant_override("v_separation", Tokens.SP_S)
	for lvl in range(1, levels + 1):
		var s := Progress.model.stars_for(g["id"], lvl)
		var unlocked := lvl == 1 or Progress.model.stars_for(g["id"], lvl - 1) > 0
		var chip: Button
		if unlocked:
			chip = UiKit.button(str(lvl), UiKit.Variant.PRIMARY if s > 0 else UiKit.Variant.SECONDARY, accent)
		else:
			chip = UiKit.icon_button("lock", "", UiKit.Variant.GHOST)
		chip.custom_minimum_size = Vector2(Tokens.TOUCH_MIN, Tokens.TOUCH_MIN + 8)
		chip.disabled = not unlocked
		if unlocked:
			chip.add_child(_star_dots(s, s > 0))
		chip.tooltip_text = "%d نجوم" % s
		var lv := lvl
		chip.pressed.connect(func(): Router.play_game(g["id"], lv))
		path.add_child(chip)
	v.add_child(path)
	var resume := Progress.model.resume_level(g["id"], levels)
	var play := UiKit.icon_button("play", "العب المرحلة %d" % resume, UiKit.Variant.PRIMARY, accent)
	play.pressed.connect(func(): Router.play_game(g["id"], resume))
	v.add_child(play)
	return c


## Three small dots under a level number: filled = stars earned.
func _star_dots(stars: int, on_primary: bool) -> Control:
	var d := Control.new()
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	d.offset_top = -18
	d.offset_bottom = -6
	d.draw.connect(func():
		var c := Vector2(d.size.x / 2.0, d.size.y / 2.0)
		for i in 3:
			var col := (Tokens.BG if on_primary else Tokens.COIN) if i < stars else Color(Tokens.TEXT_MUTED, 0.35)
			d.draw_circle(c + Vector2((i - 1) * 14.0, 0), 4.5, col))
	return d
