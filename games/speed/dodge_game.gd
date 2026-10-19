extends MiniGame
## Dodge: drag the player sideways while obstacles fall. Each level is longer and faster.
## Stars by how long you survive: 50% = 1, 75% = 2, full time = 3. Each dodged block scores.

var arena: Control
var player: Panel
var score_label: Label
var time_chip: Label
var glow: Panel
var duration := 18.0
var time_left := 18.0
var base_speed := 180.0
var score := 0
var running := false
var spawn := 0.0
var dragging := false


func _on_start() -> void:
	duration = 15.0 + 3.0 * level_id
	time_left = duration
	base_speed = 170.0 + 25.0 * (level_id - 1)
	var v := frame("تفادَ")
	score_label = chip("", "bolt", Tokens.COIN)
	time_chip = chip("", "flame", Tokens.ERROR)
	arena = Control.new()
	arena.custom_minimum_size = Vector2(0, 720)
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.clip_contents = true
	arena.gui_input.connect(_arena_input)
	v.add_child(arena)
	var arena_bg := Panel.new()
	arena_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_bg.add_theme_stylebox_override("panel", UiKit.card_style(Color(Tokens.SURFACE_1, 0.5), Tokens.RADIUS_CARD, 0))
	arena.add_child(arena_bg)
	v.add_child(UiKit.label("اسحب إصبعك يمينًا ويسارًا لتتفادى العقبات.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	glow = Panel.new()
	glow.size = Vector2(130, 130)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", _round_style(Color(accent, 0.18), 65, Color(0, 0, 0, 0)))
	arena.add_child(glow)
	player = Panel.new()
	player.size = Vector2(76, 76)
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := _round_style(Tokens.TEXT, 38, accent)
	ps.set_border_width_all(5)
	player.add_theme_stylebox_override("panel", ps)
	arena.add_child(player)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	player.position = Vector2((arena.size.x - player.size.x) / 2.0, arena.size.y - player.size.y - 40.0)
	running = true


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	spawn -= delta
	var t := duration - time_left
	time_chip.text = "%02d" % ceili(maxf(time_left, 0.0))
	UiKit.set_chip(score_label, str(score))
	glow.position = player.position + player.size / 2.0 - glow.size / 2.0
	if spawn <= 0:
		spawn = maxf(0.22, 0.75 - t * 0.02 - 0.03 * (level_id - 1))
		_spawn_obstacle()
	var speed := base_speed + t * 8.0
	for n in arena.get_children():
		if n.is_in_group("obstacle"):
			var o := n as Control
			o.position.y += speed * delta
			if o.position.y > arena.size.y + 10:
				o.queue_free()
				score += 10
			elif Rect2(o.position, o.size).grow(-6).intersects(Rect2(player.position, player.size)):
				_crash(t)
				return
	if time_left <= 0:
		running = false
		finish(3, score + 500, "نجوت حتى النهاية (%d ثانية)" % int(duration))


func _crash(t: float) -> void:
	running = false
	Sfx.play("wrong")
	Settings.vibrate(50)
	Motion.shake_area(self, 14.0)
	UiKit.burst(arena, player.position + player.size / 2.0, Tokens.ERROR, 40)
	var ratio := t / duration
	var stars := 2 if ratio >= 0.75 else (1 if ratio >= 0.5 else 0)
	await wait(0.6)
	finish(stars, score, "نجوت %d من %d ثانية" % [int(t), int(duration)])


func _spawn_obstacle() -> void:
	var o := Panel.new()
	o.add_to_group("obstacle")
	var col := Tokens.world_color(Tokens.World.SPEED)
	var st := _round_style(col, 14, col.darkened(0.35))
	st.border_width_bottom = 6
	st.shadow_color = Color(col, 0.35)
	st.shadow_size = 10
	o.add_theme_stylebox_override("panel", st)
	o.size = Vector2(randf_range(70, 150 + 6 * level_id), 46)
	o.position = Vector2(randf_range(0, maxf(arena.size.x - o.size.x, 1)), -60)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(o)


func _arena_input(event: InputEvent) -> void:
	# Touch arrives as emulated mouse too; reading only mouse avoids duplicates.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if event.pressed:
			_move_player(event.position.x)
	elif event is InputEventMouseMotion and dragging:
		_move_player(event.position.x)


func _move_player(x: float) -> void:
	if running:
		player.position.x = clampf(x - player.size.x / 2.0, 0.0, arena.size.x - player.size.x)


func _round_style(bg: Color, radius: int, border: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_corner_radius_all(radius)
	st.border_color = border
	st.anti_aliasing = true
	return st
