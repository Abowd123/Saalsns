extends CanvasLayer
## Autoload: scene changes with a radial wipe that hides loading.
## Touch is blocked during transitions (prevents double taps on rewards).

var _cover: ColorRect
var _mat: ShaderMaterial
var _busy := false
var session := {}
var params := {}
var _queued: Dictionary = {}


func play_game(id: String, level: int, daily := false) -> void:
	session = {"id": id, "level": level, "daily": daily}
	var g := Catalog.get_game(id)
	go("res://games/game_host.tscn", Catalog.world_color(g) if not g.is_empty() else Color("#2CC9B5"))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working in the pause menu
	layer = 100
	_cover = ColorRect.new()
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/transition.gdshader")
	_cover.material = _mat
	add_child(_cover)
	_set_progress(0.0)
	Progress.leveled_up.connect(func(lvl: int): toast("وصلت للمستوى %d" % lvl, "trophy", Tokens.COIN))


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)


func go(path: String, accent: Color = Color("#2CC9B5"), origin := Vector2(0.5, 0.5)) -> void:
	if _busy:
		_queued = {"path": path, "accent": accent, "origin": origin}
		return
	_busy = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	_mat.set_shader_parameter("origin", origin)
	_mat.set_shader_parameter("rim", accent)
	Sfx.play("whoosh")
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, Motion.SCENE * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		Log.error("router: cannot open %s (%d)" % [path, err])
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_method(_set_progress, 1.0, 0.0, Motion.SCENE * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw2.finished
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	if not _queued.is_empty():
		var next := _queued
		_queued = {}
		call_deferred("go", next["path"], next["accent"], next["origin"])


## Slide-down notification at the top of the screen (level ups, unlocks).
func toast(text: String, icon_name := "star", color := Tokens.COIN) -> void:
	var c := UiKit.chip(text, Tokens.TEXT, icon_name, color)
	var p: Control = c[0]
	(c[1] as Label).add_theme_font_size_override("font_size", Tokens.FS_BODY)
	var st := (p.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	st.bg_color = Tokens.SURFACE_2
	st.border_color = color
	st.set_border_width_all(2)
	st.shadow_color = Color(color, 0.35)
	st.shadow_size = 18
	st.content_margin_left = 26
	st.content_margin_right = 26
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", st)
	p.layout_direction = Control.LAYOUT_DIRECTION_RTL
	add_child(p)
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	p.position = Vector2((vp.x - p.size.x) / 2.0, -p.size.y - 20.0)
	Sfx.play("star3")
	var tw := p.create_tween()
	tw.tween_property(p, "position:y", 70.0, Motion.BASE * 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(p, "position:y", -p.size.y - 20.0, Motion.BASE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.queue_free)
