extends MiniGame
## Balance tower: a block swings above the tower; tap to drop it.
## Win: tower reaches `target` blocks high (by count of resting blocks above the base) and
## stays still for 2.5 seconds. Lose: a block falls off the platform, or blocks run out.

const SHAPES := {
	"wide": {"size": Vector2(190, 44), "mass": 1.0, "color": "wood"},
	"mid": {"size": Vector2(140, 44), "mass": 1.0, "color": "wood"},
	"small": {"size": Vector2(100, 44), "mass": 0.8, "color": "wood"},
	"stone": {"size": Vector2(130, 50), "mass": 2.6, "color": "stone"},
}
const SETTLE_SECONDS := 2.5
const SWING_AMPLITUDE := 190.0

var defs: Array = []
var lv: Dictionary = {}
var world: Node2D
var arena: Control
var info: Label
var hint_label: Label
var queue: Array = []
var dropped: Array[RigidBody2D] = []
var hanging: Node2D
var hanging_shape := ""
var t := 0.0
var platform_y := 0.0
var platform_x := 0.0
var still_time := 0.0
var idle_time := 0.0
var over := false
var waiting_drop := false
var target_line: Line2D


func _on_start() -> void:
	var v := frame("برج التوازن")
	info = chip()
	hint_label = UiKit.label("اضغط في أي مكان لإسقاط القطعة.", Tokens.FS_BODY, Tokens.TEXT, Tokens.font_bold)
	v.add_child(hint_label)
	arena = Control.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.custom_minimum_size = Vector2(0, 900)
	arena.clip_contents = true
	arena.layout_direction = Control.LAYOUT_DIRECTION_LTR
	arena.gui_input.connect(_on_input)
	v.add_child(arena)
	world = Node2D.new()
	arena.add_child(world)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/build/balance_levels.json"))
	if parsed is Dictionary:
		defs = parsed["levels"]
	lv = defs[clampi(level_id - 1, 0, defs.size() - 1)]
	queue = lv["shapes"].duplicate()
	await get_tree().process_frame
	_build_platform()
	_next_block()
	_update_info()


func _build_platform() -> void:
	platform_x = arena.size.x / 2.0
	platform_y = arena.size.y - 60.0
	var body := StaticBody2D.new()
	body.position = Vector2(platform_x, platform_y)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(240, 40)
	cs.shape = rect
	body.add_child(cs)
	var vis := Polygon2D.new()
	vis.polygon = _rect_poly(Vector2(240, 40))
	vis.color = Tokens.SURFACE_2
	body.add_child(vis)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(-120, -20), Vector2(120, -20)])
	edge.width = 4
	edge.default_color = accent
	body.add_child(edge)
	world.add_child(body)
	# target height guide: each layer is about 46px
	var target_y := platform_y - 20.0 - float(lv["target"]) * 46.0
	target_line = Line2D.new()
	target_line.points = PackedVector2Array([Vector2(20, target_y), Vector2(arena.size.x - 20, target_y)])
	target_line.width = 3
	target_line.default_color = Color(Tokens.COIN, 0.7)
	world.add_child(target_line)


func _rect_poly(sz: Vector2) -> PackedVector2Array:
	var h := sz / 2.0
	return PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])


func _material_color(kind: String) -> Color:
	return Color("#C9894B") if kind == "wood" else Color("#8D99AE")


func _next_block() -> void:
	if queue.is_empty():
		hanging = null
		return
	hanging_shape = str(queue.pop_front())
	var spec: Dictionary = SHAPES[hanging_shape]
	hanging = Node2D.new()
	hanging.add_child(_block_visual(spec))
	var rope := Line2D.new()
	rope.points = PackedVector2Array([Vector2(0, -400), Vector2(0, -spec["size"].y / 2.0)])
	rope.width = 2
	rope.default_color = Color(Tokens.TEXT_MUTED, 0.5)
	hanging.add_child(rope)
	hanging.position = Vector2(platform_x, 120)
	world.add_child(hanging)
	waiting_drop = false


func _on_input(event: InputEvent) -> void:
	# Touch arrives as emulated mouse too; reading only mouse avoids double drops.
	var pressed: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if pressed and hanging != null and not over and not waiting_drop:
		_drop()


func _drop() -> void:
	var spec: Dictionary = SHAPES[hanging_shape]
	var body := RigidBody2D.new()
	body.mass = float(spec["mass"])
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.02
	body.physics_material_override = pm
	body.position = hanging.position
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = spec["size"]
	cs.shape = rect
	body.add_child(cs)
	body.add_child(_block_visual(spec))
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.body_entered.connect(func(_b): _on_land(body), CONNECT_ONE_SHOT)
	world.add_child(body)
	dropped.append(body)
	hanging.queue_free()
	hanging = null
	waiting_drop = true
	still_time = 0.0
	Sfx.play("whoosh")
	_update_info()
	wait(0.9).connect(func():
		if not over:
			_next_block())


func _on_land(body: RigidBody2D) -> void:
	if over:
		return
	Sfx.play("pop", 0.8 if body.mass > 2.0 else 1.0)
	Settings.vibrate(14)
	UiKit.burst(world, body.position + Vector2(0, 20), Tokens.TEXT_MUTED, 14)


func _height_layers() -> int:
	var top := platform_y
	for b in dropped:
		if is_instance_valid(b):
			top = minf(top, b.position.y)
	return int(round((platform_y - 20.0 - top + 22.0) / 46.0))


func _physics_process(delta: float) -> void:
	if over or arena == null:
		return
	t += delta
	if hanging != null:
		hanging.position.x = platform_x + sin(t * float(lv["swing"]) * 1.6) * SWING_AMPLITUDE
	# lose: a block fell off
	for b in dropped:
		if is_instance_valid(b) and b.position.y > platform_y + 160.0:
			_lose("سقطت قطعة من المنصة")
			return
	# win: reached target and settled
	var moving := false
	for b in dropped:
		if is_instance_valid(b) and (b.linear_velocity.length() > 6.0 or absf(b.angular_velocity) > 0.15):
			moving = true
	var layers := _height_layers()
	if layers >= int(lv["target"]) and not moving:
		still_time += delta
		hint_label.text = "ثبات... %.1f" % maxf(SETTLE_SECONDS - still_time, 0.0)
		if still_time >= SETTLE_SECONDS:
			_win()
		return
	still_time = 0.0
	hint_label.text = "اضغط في أي مكان لإسقاط القطعة."
	var out_of_blocks := hanging == null and queue.is_empty() and dropped.size() >= int(lv["blocks"])
	if out_of_blocks and not moving:
		idle_time += delta
		if idle_time >= 1.5:
			_lose("انتهت القطع قبل الوصول للخط الذهبي")
	else:
		idle_time = 0.0


func _win() -> void:
	over = true
	Sfx.play("win")
	UiKit.burst(world, Vector2(platform_x, platform_y - float(lv["target"]) * 46.0), Tokens.COIN, 80)
	var left := queue.size() + (1 if hanging != null else 0)
	var stars := 3 if left >= 2 else (2 if left >= 1 else 1)
	if hanging != null:
		hanging.queue_free()
	await wait(1.0)
	finish(stars, 500 + left * 150, "وصلت للهدف وبقي %d قطع" % left)


func _lose(why: String) -> void:
	over = true
	Sfx.play("wrong")
	Motion.shake(arena)
	await wait(1.0)
	finish(0, dropped.size() * 20, why)


func _update_info() -> void:
	UiKit.set_chip(info, "الهدف %d طبقات  ·  القطع %d" % [int(lv["target"]), queue.size() + (1 if hanging != null else 0)])


## Wood or stone block drawn with code: body, dark outline, grain or speckles, top light.
func _block_visual(spec: Dictionary) -> Node2D:
	var sz: Vector2 = spec["size"]
	var h := sz / 2.0
	var base := _material_color(str(spec["color"]))
	var n := Node2D.new()
	var body := Polygon2D.new()
	body.polygon = _rect_poly(sz)
	body.color = base
	n.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(spec["color"]) + str(sz))
	if str(spec["color"]) == "wood":
		for k in 3:
			var y := -h.y + sz.y * (0.3 + 0.2 * k) + rng.randf_range(-3, 3)
			var grain := Line2D.new()
			grain.points = PackedVector2Array([Vector2(-h.x + 8, y), Vector2(-h.x * 0.2, y + rng.randf_range(-3, 3)), Vector2(h.x - 8, y)])
			grain.width = 2
			grain.default_color = base.darkened(0.22)
			n.add_child(grain)
	else:
		for k in 7:
			var dot := Polygon2D.new()
			var c := Vector2(rng.randf_range(-h.x + 10, h.x - 10), rng.randf_range(-h.y + 8, h.y - 8))
			var r := rng.randf_range(2.5, 5.0)
			dot.polygon = PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r)])
			dot.color = base.darkened(0.25) if k % 2 == 0 else base.lightened(0.18)
			n.add_child(dot)
	var top := Line2D.new()
	top.points = PackedVector2Array([Vector2(-h.x + 5, -h.y + 4), Vector2(h.x - 5, -h.y + 4)])
	top.width = 4
	top.default_color = Color(1, 1, 1, 0.28)
	n.add_child(top)
	var outline := Line2D.new()
	var pts := _rect_poly(sz)
	pts.append(pts[0])
	outline.points = pts
	outline.width = 3
	outline.default_color = base.darkened(0.45)
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	n.add_child(outline)
	return n
