class_name AvatarView
extends Control
## Vector avatar drawn from a store item (no image assets, crisp at any size).

var item: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_item(it: Dictionary) -> void:
	item = it
	queue_redraw()


func _poly(c: Vector2, r: float, n: int, rot := -PI / 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 4.0
	draw_circle(c, r + 2.0, Tokens.SURFACE_2)
	if item.is_empty():
		return
	var col := Color(item.get("color", "#EEF2FA"))
	var inner := r * 0.62
	match str(item.get("shape", "circle")):
		"circle":
			draw_circle(c, inner, col)
		"hex":
			draw_colored_polygon(_poly(c, inner, 6, 0.0), col)
		"square":
			draw_colored_polygon(_poly(c, inner * 1.1, 4, PI / 4.0), col)
		"diamond":
			draw_colored_polygon(_poly(c, inner * 1.1, 4), col)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + TAU * i / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * (inner * (1.0 if i % 2 == 0 else 0.45)))
			draw_colored_polygon(pts, col)
		"orbit":
			draw_circle(c, inner * 0.35, col)
			draw_arc(c, inner, 0.0, TAU, 48, col, 4.0, true)
			for k in 4:
				var a := TAU * k / 4.0 + PI / 4.0
				draw_circle(c + Vector2(cos(a), sin(a)) * inner, inner * 0.16, Tokens.world_color(k))
		"crown":
			var w := inner * 1.5
			var top := c.y - inner * 0.55
			var base := c.y + inner * 0.55
			draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - w / 2.0, base), Vector2(c.x - w / 2.0, top), Vector2(c.x - w / 4.0, c.y),
				Vector2(c.x, top - inner * 0.2), Vector2(c.x + w / 4.0, c.y), Vector2(c.x + w / 2.0, top),
				Vector2(c.x + w / 2.0, base)]), col)
	draw_arc(c, r, 0.0, TAU, 64, Store.equipped_color("ring", Color("#F5B33D")), 4.0, true)
