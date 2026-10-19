class_name FlagView
extends Control
## Draws a simplified geometric flag from content/knowledge/flags.json.

var spec: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_spec(s: Dictionary) -> void:
	spec = s
	queue_redraw()


func flag_rect() -> Rect2:
	var ratio := float(spec.get("ratio", 1.5))
	var w := size.x
	var h := w / ratio
	if h > size.y:
		h = size.y
		w = h * ratio
	return Rect2((size - Vector2(w, h)) / 2.0, Vector2(w, h))


func _draw() -> void:
	if spec.is_empty():
		return
	var r := flag_rect()
	draw_rect(Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.35))
	var stripes: Array = spec.get("stripes", ["#FFFFFF"])
	var weights: Array = spec.get("weights", [])
	if weights.is_empty():
		for i in stripes.size():
			weights.append(1)
	var total := 0.0
	for w in weights:
		total += float(w)
	var vertical := str(spec.get("kind", "h")) == "v"
	var acc := 0.0
	for i in stripes.size():
		var f0 := acc / total
		acc += float(weights[i])
		var f1 := acc / total
		var rr := Rect2(r.position + Vector2(r.size.x * f0, 0), Vector2(r.size.x * (f1 - f0) + 0.5, r.size.y)) if vertical else Rect2(r.position + Vector2(0, r.size.y * f0), Vector2(r.size.x, r.size.y * (f1 - f0) + 0.5))
		draw_rect(rr, Color(stripes[i]))
	if spec.has("hoist_band"):
		var hb: Dictionary = spec["hoist_band"]
		draw_rect(Rect2(r.position, Vector2(r.size.x * float(hb["frac"]), r.size.y)), Color(hb["color"]))
	if spec.has("triangle"):
		var tr: Dictionary = spec["triangle"]
		draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x * float(tr["frac"]), r.size.y / 2.0), r.position + Vector2(0, r.size.y)]), Color(tr["color"]))
	if spec.has("disc"):
		var d: Dictionary = spec["disc"]
		draw_circle(r.position + Vector2(r.size.x * float(d["x"]), r.size.y / 2.0), r.size.y * float(d["r"]), Color(d["color"]))
	if spec.has("nordic"):
		var n: Dictionary = spec["nordic"]
		var cx := r.position.x + r.size.x * 0.36
		var cy := r.position.y + r.size.y / 2.0
		if n.has("border"):
			var bw := r.size.y * 0.25
			draw_rect(Rect2(cx - bw / 2.0, r.position.y, bw, r.size.y), Color(n["border"]))
			draw_rect(Rect2(r.position.x, cy - bw / 2.0, r.size.x, bw), Color(n["border"]))
		var w2 := r.size.y * (0.125 if n.has("border") else 0.2)
		draw_rect(Rect2(cx - w2 / 2.0, r.position.y, w2, r.size.y), Color(n["color"]))
		draw_rect(Rect2(r.position.x, cy - w2 / 2.0, r.size.x, w2), Color(n["color"]))
	if spec.has("swiss"):
		var s: Dictionary = spec["swiss"]
		var c := r.get_center()
		var arm := r.size.y * 0.2
		var ln := r.size.y * 0.6
		draw_rect(Rect2(c.x - arm / 2.0, c.y - ln / 2.0, arm, ln), Color(s["color"]))
		draw_rect(Rect2(c.x - ln / 2.0, c.y - arm / 2.0, ln, arm), Color(s["color"]))
	draw_rect(r, Color(1, 1, 1, 0.12), false, 2.0)
