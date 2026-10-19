class_name LevelRing
extends Control
## Circular XP ring with the level number inside. animate_to() fills the arc.

var level := 1
var fraction := 0.0
var color := Color("#F5B33D")
var _label: Label


func _init() -> void:
	custom_minimum_size = Vector2(84, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UiKit.label("1", Tokens.FS_BODY, Tokens.TEXT, Tokens.font_display)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)


func set_values(p_level: int, p_fraction: float) -> void:
	color = Store.equipped_color("ring", Color("#F5B33D"))
	level = p_level
	fraction = clampf(p_fraction, 0.0, 1.0)
	_label.text = str(level)
	queue_redraw()


func animate_to(p_fraction: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float):
		fraction = v
		queue_redraw(), 0.0, clampf(p_fraction, 0.0, 1.0), Motion.BASE * 3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 6.0
	draw_circle(c, r + 4.0, Tokens.SURFACE_2)
	draw_arc(c, r, 0.0, TAU, 64, Tokens.LINE, 7.0, true)
	if fraction > 0.0:
		var end_a := -PI / 2.0 + TAU * fraction
		draw_arc(c, r, -PI / 2.0, end_a, 64, Color(color, 0.22), 16.0, true)   # glow
		draw_arc(c, r, -PI / 2.0, end_a, 64, color, 7.0, true)
		draw_circle(c + Vector2(cos(end_a), sin(end_a)) * r, 6.0, color.lightened(0.4))   # bright tip
