class_name Motion
## Madar motion system. Every animation in the app goes through these tokens.
## Raw durations anywhere else in the code are a review failure.

const TAP := 0.08
const FAST := 0.16
const BASE := 0.28
const POP := 0.32
const SCENE := 0.45
const CELEBRATE := 1.1
const STAGGER := 0.06
const NEXT_BUTTON_MAX_DELAY := 0.6

static var reduce_motion := false


static func _center_pivot(c: Control) -> void:
	c.pivot_offset = c.size / 2.0


static func press(c: Control) -> void:
	_center_pivot(c)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * 0.94, TAP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func release(c: Control) -> void:
	_center_pivot(c)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, BASE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func fade_in(c: CanvasItem, duration := FAST) -> Tween:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw


static func fade_out(c: CanvasItem, duration := FAST) -> Tween:
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	return tw


## Cards slide up 40px and fade in, one after another.
static func enter_stagger(items: Array, offset := Vector2(0, 40)) -> void:
	for i in items.size():
		var c: Control = items[i]
		var target := c.position
		c.modulate.a = 0.0
		c.position = target + (Vector2.ZERO if reduce_motion else offset)
		var tw := c.create_tween().set_parallel(true)
		tw.tween_property(c, "modulate:a", 1.0, BASE).set_delay(i * STAGGER)
		tw.tween_property(c, "position", target, BASE).set_delay(i * STAGGER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Reward pop: scale 0 -> overshoot -> 1.
static func pop_in(c: Control, delay := 0.0) -> Tween:
	_center_pivot(c)
	c.scale = Vector2.ZERO
	c.modulate.a = 1.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, POP).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Wrong answer: short horizontal shake. Disabled under reduce_motion (color + icon still show).
static func shake(c: Control, strength := 14.0) -> void:
	if reduce_motion:
		return
	var base := c.position
	var tw := c.create_tween()
	for k in [1.0, -0.8, 0.6, -0.4, 0.2, 0.0]:
		tw.tween_property(c, "position:x", base.x + strength * k, TAP * 0.6)


## Correct answer: brief glow flash using modulate (cheap, no shader).
static func flash(c: CanvasItem, color: Color) -> void:
	var original := c.modulate
	var tw := c.create_tween()
	tw.tween_property(c, "modulate", color.lightened(0.35), FAST)
	tw.tween_property(c, "modulate", original, BASE)


## Number counter for XP and coins.
static func count_to(label: Label, from: int, to: int, prefix := "", suffix := "", duration := BASE * 2.5) -> Tween:
	var tw := label.create_tween()
	tw.tween_method(func(v: float): label.text = "%s%d%s" % [prefix, int(round(v)), suffix], float(from), float(to), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw


## Gentle idle pulse for "play me" items (daily challenge).
static func idle_pulse(c: Control) -> Tween:
	_center_pivot(c)
	var tw := c.create_tween().set_loops()
	tw.tween_interval(3.5)
	tw.tween_property(c, "scale", Vector2.ONE * 1.03, FAST).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, BASE).set_trans(Tween.TRANS_SINE)
	return tw


## Tiny scale punch for changing numbers (chips, counters).
static func bump(c: Control, amount := 1.12) -> void:
	if reduce_motion or not c.is_inside_tree():
		return
	_center_pivot(c)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * amount, TAP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, BASE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shakes a whole screen/game area (fail moments). Respects reduce motion.
static func shake_area(c: Control, strength := 10.0) -> void:
	if reduce_motion or not c.is_inside_tree():
		return
	var base := c.position
	var tw := c.create_tween()
	for k in [1.0, -0.9, 0.7, -0.5, 0.3, 0.0]:
		tw.tween_property(c, "position", base + Vector2(strength * k, strength * 0.4 * -k), TAP * 0.55)


## Gentle endless float (emblems). Respects reduce motion.
static func float_idle(c: Control, dy := 6.0, period := 2.6) -> void:
	if reduce_motion:
		return
	var base := c.position.y
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "position:y", base - dy, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "position:y", base, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Slow "breathing" scale loop for emblems (safe inside containers). Respects reduce motion.
static func breathe(c: Control, amount := 1.07, period := 2.8) -> void:
	if reduce_motion:
		return
	if not c.is_inside_tree():   # tweens need the tree; start once the node is shown
		c.tree_entered.connect(func(): breathe(c, amount, period), CONNECT_ONE_SHOT)
		return
	c.pivot_offset = c.size / 2.0
	c.resized.connect(func(): c.pivot_offset = c.size / 2.0)
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2.ONE * amount, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
