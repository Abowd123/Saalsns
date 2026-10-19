extends CanvasLayer
## Autoload "Perf": optional overlay (Settings > show_perf) + per-scene frame stats.

var _label: Label
var _acc := 0.0
var frames := 0
var slow := 0
var worst_ms := 0.0
var scene_name := ""
var boot_ms := 0   # ms from engine start until the boot logo is on screen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working in the pause menu
	layer = 120
	_label = Label.new()
	_label.position = Vector2(12, 12)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	get_tree().tree_changed.connect(_on_tree_changed)


func _on_tree_changed() -> void:
	var cs: Node = get_tree().current_scene if get_tree() else null
	var n: String = String(cs.name) if cs else ""
	if n != scene_name and n != "":
		if scene_name != "" and frames > 0:
			Log.info("perf %s frames=%d slow(>20ms)=%.2f%% worst=%.1fms" % [scene_name, frames, 100.0 * slow / frames, worst_ms])
		scene_name = n
		frames = 0
		slow = 0
		worst_ms = 0.0


func _process(delta: float) -> void:
	var ms := delta * 1000.0
	frames += 1
	if ms > 20.0 and frames > 10:
		slow += 1
	if frames > 10:
		worst_ms = maxf(worst_ms, ms)
	_label.visible = bool(Settings.get_value("show_perf"))
	_acc += delta
	if _label.visible and _acc > 0.5:
		_acc = 0.0
		_label.text = "FPS %d  |  %.1f ms  |  worst %.1f  |  mem %.0f MB  |  draws %d" % [
			int(Engine.get_frames_per_second()), ms, worst_ms,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]
