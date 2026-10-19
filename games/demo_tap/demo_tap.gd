extends MiniGame
## SYSTEM TEST GAME (dev only). Tap the glowing targets before they fade.
## Exercises: MiniGame contract, input, particles, sfx, haptics, result + rewards + save.

const DURATION := 12.0
var targets_per_level := {1: [6, 10, 14], 2: [8, 12, 16], 3: [10, 14, 18]}
var score := 0
var time_left := DURATION
var running := false
var arena: Control
var hud_l: Label
var spawn_timer := 0.0


func _on_start() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(WorldBg.make(accent))
	hud_l = UiKit.label("", Tokens.FS_H2, Tokens.TEXT, Tokens.font_bold)
	hud_l.position = Vector2(Tokens.SP_L, 80)
	add_child(hud_l)
	arena = Control.new()
	arena.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena.offset_top = 180
	arena.offset_bottom = -60
	add_child(arena)
	var goal: Array = targets_per_level.get(level_id, [6, 10, 14])
	var intro := UiKit.heading("المرحلة %d: اضغط %d هدفًا لنجمة واحدة" % [level_id, goal[0]], Tokens.FS_H2, accent)
	intro.set_anchors_preset(Control.PRESET_CENTER)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.custom_minimum_size = Vector2(600, 0)
	intro.position -= Vector2(300, 40)
	add_child(intro)
	Motion.pop_in(intro)
	await wait(1.2)
	Motion.fade_out(intro).finished.connect(intro.queue_free)
	running = true


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	hud_l.text = "النقاط %d   ·   الوقت %d" % [score, ceili(maxf(time_left, 0.0))]
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = maxf(0.35, 0.8 - (DURATION - time_left) * 0.03)
		_spawn()
	if time_left <= 0.0:
		running = false
		var goal: Array = targets_per_level.get(level_id, [6, 10, 14])
		var stars := 0
		for g in goal:
			if score >= g:
				stars += 1
		finish(stars, score, "أصبت %d هدفًا" % score)


func _spawn() -> void:
	var b := Button.new()
	var sz := randf_range(90, 130)
	b.custom_minimum_size = Vector2(sz, sz)
	b.size = Vector2(sz, sz)
	var st := StyleBoxFlat.new()
	st.bg_color = accent
	st.set_corner_radius_all(int(sz / 2))
	st.shadow_color = Color(accent, 0.5)
	st.shadow_size = 16
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, st)
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(randf_range(20, maxf(arena.size.x - sz - 20, 30)), randf_range(20, maxf(arena.size.y - sz - 20, 30)))
	arena.add_child(b)
	Motion.pop_in(b)
	b.button_down.connect(func():
		if not running:
			return
		score += 1
		Sfx.play("pop", 1.0 + minf(score * 0.02, 0.4))
		Settings.vibrate(12)
		UiKit.burst(arena, b.position + b.size / 2.0, accent, 30)
		b.queue_free())
	var life := b.create_tween()
	life.tween_interval(1.1)
	life.tween_property(b, "modulate:a", 0.0, Motion.BASE)
	life.tween_callback(b.queue_free)
