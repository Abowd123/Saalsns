class_name ShapeIcon
extends Control
## Vector shape used where color alone must not carry meaning (colorblind support).
## shape: 0 circle, 1 triangle, 2 square, 3 star.

const NAMES := ["دائرة", "مثلث", "مربع", "نجمة"]

var shape := 0
var color := Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(64, 64)


func set_shape(p_shape: int, p_color: Color) -> void:
	shape = p_shape
	color = p_color
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.42
	match shape:
		0:
			draw_circle(c, r, color)
		1:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.95, r * 0.75), c + Vector2(-r * 0.95, r * 0.75)]), color)
		2:
			draw_rect(Rect2(c - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), color)
		_:
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
			draw_colored_polygon(pts, color)
