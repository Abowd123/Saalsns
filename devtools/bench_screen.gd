extends Screen
## Performance bench: 4 stress stages, 5 seconds each, on the real phone.
## Reports average FPS, 1% low (99th percentile frame time), worst frame, memory.
## Targets (S22 Ultra, 60 FPS cap): avg >= 58, p99 <= 25 ms.

const STAGE_TIME := 5.0
var stage: Control
var rows: VBoxContainer
var report := PackedStringArray()
var running := false


func _ready() -> void:
	back_target = "res://devtools/lab_hub.tscn"
	build_screen("فحص الأداء", Color("#FF5E6C"))
	body.add_child(UiKit.label("لا تلمس الشاشة أثناء الفحص. المدة 20 ثانية تقريبًا.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	var start := UiKit.button("ابدأ الفحص", UiKit.Variant.PRIMARY, Color("#FF5E6C"))
	body.add_child(start)
	var copy := UiKit.button("نسخ التقرير", UiKit.Variant.SECONDARY, Color("#FF5E6C"))
	copy.pressed.connect(func():
		DisplayServer.clipboard_set("\n".join(report))
		Sfx.play("correct"))
	body.add_child(copy)
	rows = UiKit.vbox(Tokens.SP_XS)
	body.add_child(rows)
	stage = Control.new()
	stage.custom_minimum_size = Vector2(0, 1000)
	stage.clip_contents = true
	body.add_child(stage)
	start.pressed.connect(func():
		if not running:
			_run())


func _line(text: String, color := Tokens.TEXT) -> void:
	var l := UiKit.label(text, Tokens.FS_CAPTION, color, Tokens.font_bold)
	l.text_direction = Control.TEXT_DIRECTION_LTR
	rows.add_child(l)


func _run() -> void:
	running = true
	for c in rows.get_children():
		c.queue_free()
	report = PackedStringArray([
		"MADAR BENCH v%s" % ProjectSettings.get_setting("application/config/version"),
		"device: %s | %s | cores %d" % [OS.get_model_name(), OS.get_name(), OS.get_processor_count()],
		"renderer: %s | adapter: %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()],
		"window: %s | fps cap %d | quality %s (%s)" % [str(DisplayServer.window_get_size()), Engine.max_fps, Settings.get_value("quality"), Quality.tier()],
		"boot to logo: %d ms" % Perf.boot_ms])
	for l in report:
		_line(l, Tokens.TEXT_MUTED)
	await _stage("background+ui", _setup_ui)
	await _stage("particles", _setup_particles)
	await _stage("physics80", _setup_physics)
	await _stage("arabic_text", _setup_text)
	var mem := "memory static %.1f MB | video %.1f MB | objects %d" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_COUNT))]
	report.append(mem)
	_line(mem)
	running = false
	Sfx.play("win")


func _stage(name_: String, setup: Callable) -> void:
	for c in stage.get_children():
		c.queue_free()
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	setup.call()
	var setup_ms := (Time.get_ticks_usec() - t0) / 1000.0
	for i in 10:
		await get_tree().process_frame   # settle
	var times: Array[float] = []
	var elapsed := 0.0
	var spawn := 0.0
	while elapsed < STAGE_TIME:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		elapsed += dt
		times.append(dt * 1000.0)
		if name_ == "particles":
			spawn += dt
			if spawn > 0.25:
				spawn = 0.0
				UiKit.burst(stage, Vector2(randf_range(100, 900), randf_range(200, 800)), Tokens.world_color(randi() % 4), 60)
	times.sort()
	var avg := 0.0
	for t in times:
		avg += t
	avg /= maxf(times.size(), 1)
	var p99 := times[int(times.size() * 0.99) - 1] if times.size() > 10 else 0.0
	var worst := times[-1] if times.size() > 0 else 0.0
	var ok := 1000.0 / avg >= float(Engine.max_fps if Engine.max_fps > 0 else 60) * 0.95 and p99 <= 25.0
	var line := "%s %-13s avg %.1f fps | p99 %.1f ms | worst %.1f ms | setup %.0f ms" % ["PASS" if ok else "WARN", name_, 1000.0 / avg, p99, worst, setup_ms]
	report.append(line)
	_line(line, Tokens.SUCCESS if ok else Tokens.COIN)


func _setup_ui() -> void:
	var v := UiKit.vbox(Tokens.SP_S)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(v)
	for i in 8:
		var c := UiKit.world_card(i % 4, 3, 0.5)
		c.custom_minimum_size = Vector2(0, 110)
		v.add_child(c)
		Motion.idle_pulse(c)


func _setup_particles() -> void:
	pass   # spawned during the stage loop


func _setup_physics() -> void:
	var w := stage.size.x
	for spec in [[Vector2(w / 2.0, 980), Vector2(w, 40)], [Vector2(10, 500), Vector2(20, 1000)], [Vector2(w - 10, 500), Vector2(20, 1000)]]:
		var body_s := StaticBody2D.new()
		body_s.position = spec[0]
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = spec[1]
		cs.shape = rect
		body_s.add_child(cs)
		stage.add_child(body_s)
	for i in 80:
		var rb := RigidBody2D.new()
		rb.position = Vector2(60 + (i % 10) * ((w - 120) / 10.0), 40 + int(i / 10.0) * 50)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36, 36)
		cs.shape = rect
		rb.add_child(cs)
		var vis := ColorRect.new()
		vis.size = Vector2(36, 36)
		vis.position = Vector2(-18, -18)
		vis.color = Tokens.world_color(i % 4)
		rb.add_child(vis)
		stage.add_child(rb)


func _setup_text() -> void:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(sc)
	var v := UiKit.vbox(Tokens.SP_XS)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var qs := ContentLab.load_questions()
	for i in mini(300, qs.size()):
		v.add_child(UiKit.label("%d. %s  (%s)" % [i + 1, qs[i]["question"], qs[i]["answers"][0]], Tokens.FS_CAPTION if i % 2 else Tokens.FS_BODY))
	var tw := sc.create_tween().set_loops()
	tw.tween_method(func(y: float): sc.scroll_vertical = int(y), 0.0, 6000.0, 2.5)
	tw.tween_method(func(y: float): sc.scroll_vertical = int(y), 6000.0, 0.0, 2.5)
