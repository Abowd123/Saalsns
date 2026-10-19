class_name GearView
extends Control
## Procedural gear: real teeth, hub, shading. Rotation is driven by the game.

var radius := 40.0
var color := Color("#9BDB4D")
var angle := 0.0
var jammed := false
var fixed := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(r: float, c: Color, is_fixed := false) -> void:
	radius = r
	color = c
	fixed = is_fixed
	size = Vector2(r * 2.0 + 24.0, r * 2.0 + 24.0)
	pivot_offset = size / 2.0
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var teeth := int(round(radius / 5.0))
	var pts := PackedVector2Array()
	var steps := teeth * 4
	for i in steps:
		var a := angle + TAU * float(i) / float(steps)
		var phase := i % 4
		var r := radius + (8.0 if phase == 1 or phase == 2 else 0.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var body := Tokens.ERROR if jammed else color
	draw_colored_polygon(pts, body.darkened(0.15))
	draw_circle(c, radius - 4.0, body)
	draw_circle(c, radius * 0.55, body.darkened(0.25))
	for k in 4:
		var a2 := angle + k * PI / 2.0
		draw_line(c, c + Vector2(cos(a2), sin(a2)) * (radius * 0.5), body.lightened(0.15), 4.0, true)
	draw_circle(c, 9.0, Tokens.BG if not fixed else Tokens.COIN)
