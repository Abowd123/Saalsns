class_name RaysView
extends Control
## Slowly turning light rays behind the result stars.

var color := Color("#FFD45C")
var count := 14


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(620, 620)
	pivot_offset = size / 2.0


func _ready() -> void:
	modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, Motion.BASE * 2.0)
	var spin := create_tween().set_loops()
	spin.tween_property(self, "rotation", TAU, 24.0).from(0.0)


func _draw() -> void:
	var c := size / 2.0
	var r := size.x / 2.0
	var w := PI / count * 0.42
	for k in count:
		var a := TAU * k / count
		var pts := PackedVector2Array([c, c + Vector2(cos(a - w), sin(a - w)) * r, c + Vector2(cos(a + w), sin(a + w)) * r])
		draw_colored_polygon(pts, Color(color, 0.10))
	draw_circle(c, r * 0.32, Color(color, 0.10))
	draw_circle(c, r * 0.2, Color(color, 0.08))
