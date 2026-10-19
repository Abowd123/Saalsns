extends Control
## First scene. Draws every shader/material once (offscreen-tiny) so the first real use
## does not stutter, then shows the logo intro and opens the hub.
## Idea from NeZvers Godot-GameTemplate boot_load (MIT); own implementation.

const WARM_SHADERS := ["res://shaders/world_bg.gdshader", "res://shaders/transition.gdshader"]
const NEXT_SCENE := "res://meta/home.tscn"


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Tokens.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var warm := Control.new()
	add_child(warm)
	for path in WARM_SHADERS:
		var r := ColorRect.new()
		r.size = Vector2(2, 2)
		r.position = Vector2(-1, -1)
		var m := ShaderMaterial.new()
		m.shader = load(path)
		r.material = m
		warm.add_child(r)
	UiKit.burst(warm, Vector2(-50, -50), Tokens.SUCCESS, 4)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/brand/logo_mark_512.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(260, 260)
	logo.size = Vector2(260, 260)
	add_child(logo)
	await get_tree().process_frame
	logo.position = (size - logo.size) / 2.0 - Vector2(0, 60)
	Motion.pop_in(logo)
	Sfx.play("pop")
	_intro_fx(logo.position + logo.size / 2.0)
	await get_tree().process_frame
	warm.queue_free()
	Log.info("boot warmup %d ms" % (Time.get_ticks_msec() - t0))
	Perf.boot_ms = Time.get_ticks_msec()   # engine start -> logo shown
	Music.play("res://assets/music/ambient_menu.ogg")
	await get_tree().create_timer(0.9).timeout
	Router.go(NEXT_SCENE)


## Expanding light ring + sparks behind the logo, then the name fades in.
func _intro_fx(c: Vector2) -> void:
	var ring := Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ring)
	move_child(ring, 1)
	var st := {"t": 0.0}
	ring.draw.connect(func():
		var t: float = st["t"]
		var col := Color("#2CC9B5")
		ring.draw_arc(c, 120.0 + 260.0 * t, 0, TAU, 96, Color(col, 0.55 * (1.0 - t)), 6.0 * (1.0 - t) + 1.0, true)
		ring.draw_circle(c, 150.0, Color(col, 0.10 * (1.0 - t * 0.5))))
	var tw := ring.create_tween()
	tw.tween_method(func(v: float):
		st["t"] = v
		ring.queue_redraw(), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	UiKit.burst(self, c, Color("#2CC9B5"), 50)
	var name_l := UiKit.heading("مدار", Tokens.FS_DISPLAY)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.size = Vector2(size.x, 90)
	name_l.position = Vector2(0, c.y + 150.0)
	add_child(name_l)
	name_l.modulate.a = 0.0
	var tw2 := name_l.create_tween()
	tw2.tween_interval(0.2)
	tw2.tween_property(name_l, "modulate:a", 1.0, Motion.BASE)
	tw2.parallel().tween_property(name_l, "position:y", c.y + 130.0, Motion.BASE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
