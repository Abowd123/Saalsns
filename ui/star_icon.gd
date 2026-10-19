class_name StarIcon
extends Control
## Vector star (no texture). filled = earned, otherwise outline slot.

@export var filled := false:
	set(v):
		filled = v
		queue_redraw()
var color := Color("#FFD45C")


func _init() -> void:
	custom_minimum_size = Vector2(84, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := size / 2.0
	var r_out := minf(size.x, size.y) * 0.48
	var r_in := r_out * 0.48
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var r := r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw() -> void:
	var pts := _points()
	if filled:
		draw_colored_polygon(pts, color)
		var hl := PackedVector2Array()
		for p in pts:
			hl.append(size / 2.0 + (p - size / 2.0) * 0.55 + Vector2(0, -size.y * 0.04))
		draw_colored_polygon(hl, color.lightened(0.25))
	else:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Tokens.LINE, 4.0, true)
