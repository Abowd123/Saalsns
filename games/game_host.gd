extends Control
## Hosts one MiniGame: loads it, starts it, records the result, shows the result screen.
## Router.play_game(id, level) sets Router.session and changes to this scene.
## A top bar gives a pause menu (resume / restart / leave). Android back opens it too.

const BAR_H := 76

var mini: MiniGame
var game: Dictionary
var level_id := 1
var _reported := false
var _pause_layer: Control
var _pause_btn: Button


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	process_mode = Node.PROCESS_MODE_ALWAYS   # menu + back button work while paused
	set_anchors_preset(Control.PRESET_FULL_RECT)
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	game = Catalog.get_game(Router.session.get("id", ""))
	level_id = int(Router.session.get("level", 1))
	if game.is_empty():
		Log.error("game_host: unknown game %s" % Router.session.get("id", ""))
		Router.go("res://meta/home.tscn")
		return
	add_child(WorldBg.make(Catalog.world_color(game)))
	var top := _top_inset()
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.offset_top = top + BAR_H
	holder.process_mode = Node.PROCESS_MODE_PAUSABLE   # the game itself freezes on pause
	add_child(holder)
	var packed: PackedScene = load(game["scene"])
	mini = packed.instantiate() as MiniGame
	if mini == null:
		Log.error("game_host: scene does not extend MiniGame")
		Router.go("res://meta/home.tscn")
		return
	holder.add_child(mini)
	_build_bar(top)
	mini.finished.connect(_on_finished, CONNECT_ONE_SHOT)
	mini.start(game, level_id)
	Motion.fade_in(mini, Motion.BASE)
	var seen := SaveService.section("howto_seen")
	if str(game.get("howto", "")) != "" and not bool(seen.get(game["id"], false)):
		_show_howto(true)


func _top_inset() -> int:
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.y <= 0:
		return 0
	var scale_y := get_viewport_rect().size.y / float(maxi(DisplayServer.window_get_size().y, 1))
	return int(safe.position.y * scale_y)


func _build_bar(top: int) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = top + 8
	bar.offset_bottom = top + BAR_H - 4
	bar.offset_left = Tokens.SP_M
	bar.offset_right = -Tokens.SP_M
	bar.add_theme_constant_override("separation", Tokens.SP_S)
	add_child(bar)
	var lvl := UiKit.chip("المرحلة %d من %d" % [level_id, int(game["levels"])], Tokens.TEXT_MUTED, "star", Catalog.world_color(game))
	bar.add_child(lvl[0])
	if bool(Router.session.get("daily", false)):
		bar.add_child(UiKit.chip("التحدي اليومي", Tokens.COIN, "flame", Tokens.COIN)[0])
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_pause_btn = UiKit.icon_button("pause", "", UiKit.Variant.SECONDARY, Catalog.world_color(game))
	_pause_btn.custom_minimum_size = Vector2(72, 64)
	_pause_btn.pressed.connect(_open_pause)
	bar.add_child(_pause_btn)


func _open_pause() -> void:
	if _reported or _pause_layer != null:
		return
	get_tree().paused = true
	_pause_layer = Control.new()
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(dim)
	var sheet := UiKit.card(2)
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.custom_minimum_size = Vector2(560, 0)
	sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause_layer.add_child(sheet)
	var v := UiKit.vbox(Tokens.SP_M)
	sheet.add_child(v)
	var h := UiKit.heading("متوقف مؤقتًا", Tokens.FS_H1)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	var resume := UiKit.icon_button("play", "متابعة", UiKit.Variant.PRIMARY, Catalog.world_color(game))
	resume.pressed.connect(_close_pause)
	v.add_child(resume)
	var restart := UiKit.icon_button("restart", "أعد المرحلة", UiKit.Variant.SECONDARY, Catalog.world_color(game))
	restart.pressed.connect(func():
		_unpause()
		Router.play_game(game["id"], level_id, bool(Router.session.get("daily", false))))
	v.add_child(restart)
	if str(game.get("howto", "")) != "":
		var how := UiKit.icon_button("hint", "كيف تلعب", UiKit.Variant.SECONDARY, Tokens.COIN)
		how.pressed.connect(func():
			_close_pause()
			_show_howto(false))
		v.add_child(how)
	var leave := UiKit.icon_button("home", "الخروج (بدون نتيجة)", UiKit.Variant.GHOST)
	leave.pressed.connect(func():
		_unpause()
		Router.go("res://meta/home.tscn"))
	v.add_child(leave)


func _close_pause() -> void:
	if _pause_layer:
		_pause_layer.queue_free()
		_pause_layer = null
	_unpause()


func _unpause() -> void:
	get_tree().paused = false


func _exit_tree() -> void:
	get_tree().paused = false


func _on_finished(result: Dictionary) -> void:
	if _reported:
		return
	_reported = true
	if _pause_btn:
		_pause_btn.disabled = true
	var r := Progress.report_result(game["id"], level_id, int(result["stars"]), int(result["score"]), int(game["base_xp"]), int(game["coins_per_star"]))
	r["detail"] = result.get("detail", "")
	var is_daily := bool(Router.session.get("daily", false))
	if is_daily:
		var d := Progress.try_claim_daily(int(result["stars"]))
		if not d.is_empty():
			r["daily"] = d
			r["achievements"] = (r.get("achievements", []) as Array) + Progress.check_achievements()
		else:
			var ch := Progress.today_challenge()
			r["detail"] = str(r["detail"]) + ("\n" if str(r["detail"]) != "" else "") + "التحدي اليومي يحتاج %d نجوم على الأقل." % int(ch.get("target_stars", 2))
	if int(result["stars"]) > 0:
		await _celebrate(int(result["stars"]))
	var screen := ResultScreen.new()
	add_child(screen)
	var has_next := level_id < int(game["levels"]) and not (is_daily and r.has("daily"))
	screen.show_result(r, Catalog.world_color(game), has_next)
	screen.next_pressed.connect(func(): Router.play_game(game["id"], level_id + 1))
	screen.retry_pressed.connect(func(): Router.play_game(game["id"], level_id, is_daily and not r.has("daily")))
	screen.home_pressed.connect(func(): Router.go("res://meta/home.tscn"))


## Android back during play opens the pause menu (or closes it). After the result: home.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _reported:
			Router.go("res://meta/home.tscn")
		elif _pause_layer != null:
			_close_pause()
		else:
			_open_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not _reported and mini != null:
			_open_pause()


## Win moment shared by every game: flash, confetti from both bottom corners, a beat of pause.
func _celebrate(stars: int) -> void:
	UiKit.flash_screen(self)
	Settings.vibrate(25)
	var vp := get_viewport_rect().size
	if Quality.fancy():
		var amount := 40 + 25 * stars
		UiKit.confetti(self, Vector2(0, vp.y), Vector2(0.45, -1).normalized(), amount)
		UiKit.confetti(self, Vector2(vp.x, vp.y), Vector2(-0.45, -1).normalized(), amount)
	await UiKit.wait(self, 0.45)


## "How to play" card. Shown automatically the first time a game is opened, and from
## the pause menu. The game stays paused while it is open.
func _show_howto(first_time: bool) -> void:
	if _pause_layer != null:
		return
	get_tree().paused = true
	_pause_layer = Control.new()
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(dim)
	var sheet := UiKit.card(2)
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.custom_minimum_size = Vector2(600, 0)
	sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause_layer.add_child(sheet)
	var v := UiKit.vbox(Tokens.SP_M)
	sheet.add_child(v)
	var top := UiKit.hbox(Tokens.SP_S)
	top.add_child(UiKit.icon_rect("hint", 44, Tokens.COIN))
	var h := UiKit.heading("كيف تلعب: %s" % game["title"], Tokens.FS_H2, Catalog.world_color(game))
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(h)
	v.add_child(top)
	if bool(game.get("hard", false)):
		v.add_child(UiKit.chip("لعبة صعبة: النجوم الثلاث للحل الأمثل", Tokens.COIN, "flame", Tokens.ERROR)[0])
	v.add_child(UiKit.label(str(game["howto"]), Tokens.FS_BODY, Tokens.TEXT))
	var go := UiKit.icon_button("play", "ابدأ" if first_time else "عودة للعبة", UiKit.Variant.PRIMARY, Catalog.world_color(game))
	go.pressed.connect(func():
		SaveService.section("howto_seen")[game["id"]] = true
		SaveService.mark_dirty()
		_close_pause())
	v.add_child(go)
	sheet.modulate.a = 0.0
	await get_tree().process_frame   # size known -> pop from the center
	if is_instance_valid(sheet):
		Motion.pop_in(sheet)
