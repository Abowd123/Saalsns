class_name UiKit
## Factory for Madar UI components. All styling comes from Tokens, all motion from Motion.

enum Variant { PRIMARY, SECONDARY, GHOST, ICON }

const WORLD_ICONS := {Tokens.World.KNOWLEDGE: "book", Tokens.World.PUZZLES: "puzzle", Tokens.World.SPEED: "bolt", Tokens.World.BUILD: "gear"}


static func card_style(color := Tokens.SURFACE_1, radius := Tokens.RADIUS_CARD, elevation := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_width_top = 1
	s.border_color = Tokens.HIGHLIGHT
	s.shadow_color = Tokens.SHADOW
	s.shadow_size = [0, 10, 18][clampi(elevation, 0, 2)]
	s.shadow_offset = Vector2(0, [0, 5, 9][clampi(elevation, 0, 2)])
	s.content_margin_left = Tokens.SP_L
	s.content_margin_right = Tokens.SP_L
	s.content_margin_top = Tokens.SP_M
	s.content_margin_bottom = Tokens.SP_M
	s.anti_aliasing = true
	return s


static func label(text: String, size := Tokens.FS_BODY, color := Tokens.TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font if font else Tokens.font_body)
	l.add_theme_font_size_override("font_size", maxi(size, Tokens.FS_MIN))
	l.add_theme_color_override("font_color", color)
	return l


static func heading(text: String, size := Tokens.FS_H1, color := Tokens.TEXT) -> Label:
	var l := label(text, size, color, Tokens.font_display)
	# soft drop shadow gives headings depth on the glowing backgrounds
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.38))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 6)
	return l


static func button(text: String, variant := Variant.PRIMARY, accent := Color("#2CC9B5"), sound := "tap") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(Tokens.TOUCH_MIN if variant == Variant.ICON else 0, Tokens.TOUCH_MIN)
	b.add_theme_font_override("font", Tokens.font_bold)
	b.add_theme_font_size_override("font_size", Tokens.FS_BODY + (8 if variant == Variant.ICON else 2))
	b.focus_mode = Control.FOCUS_NONE
	var normal: StyleBoxFlat
	var fg := Tokens.TEXT
	match variant:
		Variant.PRIMARY:
			normal = card_style(accent, Tokens.RADIUS_BUTTON, 1)
			normal.border_width_top = 0
			normal.border_width_bottom = 5
			normal.border_color = accent.darkened(0.3)
			fg = Tokens.BG
		Variant.SECONDARY:
			normal = card_style(Tokens.SURFACE_2, Tokens.RADIUS_BUTTON, 1)
			normal.border_width_bottom = 4
			normal.border_color = accent
		Variant.GHOST:
			normal = card_style(Color(0, 0, 0, 0), Tokens.RADIUS_BUTTON, 0)
			normal.set_border_width_all(2)
			normal.border_color = Tokens.LINE
			fg = Tokens.TEXT_MUTED
		_:
			normal = card_style(Tokens.SURFACE_2, Tokens.RADIUS_BUTTON, 1)
			normal.content_margin_left = 0
			normal.content_margin_right = 0
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.12) if normal.bg_color.a > 0 else Tokens.SURFACE_1
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(0, 1)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Tokens.SURFACE_1
	disabled.border_color = Tokens.LINE
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Tokens.TEXT_MUTED)
	b.clip_contents = true   # keeps the ripple inside the button
	b.button_down.connect(func(): Motion.press(b))
	b.button_down.connect(func(): Sfx.play(sound))
	b.button_down.connect(func(): ripple(b, Color.WHITE if variant != Variant.PRIMARY else Tokens.BG))
	b.button_up.connect(func(): Motion.release(b))
	return b


static func card(elevation := 1, color := Tokens.SURFACE_1) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style(color, Tokens.RADIUS_CARD, elevation))
	return p


static func vbox(sep := Tokens.SP_S) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := Tokens.SP_S) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


## World card: title in world color, subtitle, progress bar, soft glow.
static func world_card(world: int, games: int, progress: float) -> PanelContainer:
	var accent := Tokens.world_color(world)
	var p := PanelContainer.new()
	var st := card_style(Tokens.SURFACE_1, Tokens.RADIUS_WORLD, 1)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(0, 200)
	p.clip_contents = true
	var glow := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(accent, 0.30))
	g.set_color(1, Color(accent, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.15, 1.0)
	gt.fill_to = Vector2(0.9, 0.2)
	glow.texture = gt
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(stack)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -Tokens.SP_L
	glow.offset_right = Tokens.SP_L
	glow.offset_top = -Tokens.SP_M
	glow.offset_bottom = Tokens.SP_M
	stack.add_child(glow)
	var v := vbox(Tokens.SP_XS)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(v)
	var top := hbox(Tokens.SP_S)
	var name_l := heading(Tokens.WORLD_NAMES[world], Tokens.FS_H2 + 2, accent)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var emblem := icon_rect(WORLD_ICONS.get(world, "star"), 56, accent)
	top.add_child(emblem)
	Motion.breathe(emblem, 1.08, 3.2 + 0.4 * world)
	v.add_child(top)
	v.add_child(label("%d ألعاب" % games, Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.value = progress * 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Tokens.SURFACE_2
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	v.add_child(bar)
	return p


const BG_SHADER := preload("res://shaders/world_bg.gdshader")
static var _dot: Texture2D


static func dot_texture() -> Texture2D:
	if _dot:
		return _dot
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 32
	t.height = 32
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_dot = t
	return t


## One-shot burst for rewards. Returns the node so callers can position it.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 60) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = maxi(4, int(amount * Quality.particle_scale()))
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	p.texture = dot_texture()
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 380.0
	p.gravity = Vector2(0, 420)
	p.damping_min = 30.0
	p.damping_max = 60.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.9
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Feedback text (+12, −3 ث, ...) that rises and fades above a point.
## Off on low quality and with reduce motion (the HUD still shows the same value).
static func float_text(parent: Control, pos: Vector2, text: String, color := Tokens.COIN) -> void:
	if not Quality.fancy() or parent == null or not parent.is_inside_tree():
		return
	var l := label(text, Tokens.FS_H2, color, Tokens.font_bold)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 5
	parent.add_child(l)
	l.size = l.get_combined_minimum_size()
	l.position = pos - l.size / 2.0
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70.0, Motion.BASE * 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, Motion.BASE).set_delay(Motion.BASE)
	tw.chain().tween_callback(l.queue_free)


## Expanding ring at a point (hit, placement, success). Off on low quality / reduce motion.
static func ring(parent: Control, pos: Vector2, color: Color, radius := 70.0) -> void:
	if not Quality.fancy() or parent == null or not parent.is_inside_tree():
		return
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = pos
	c.z_index = 4
	parent.add_child(c)
	var k := [0.0]
	c.draw.connect(func():
		var t: float = k[0]
		c.draw_arc(Vector2.ZERO, radius * (0.25 + 0.75 * t), 0, TAU, 48, Color(color, 0.9 * (1.0 - t)), 2.0 + 6.0 * (1.0 - t), true))
	var tw: Tween = c.create_tween()
	tw.tween_method(func(v: float):
		k[0] = v
		c.queue_redraw(), 0.0, 1.0, Motion.BASE * 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(c.queue_free)


## Safe delay: a child Timer of `node`. If the node is freed (player left the screen),
## the timer dies with it and the awaiting code simply never resumes (no errors).
## Pauses with the node, unlike SceneTree timers.
static func wait(node: Node, sec: float) -> Signal:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = maxf(sec, 0.01)
	t.autostart = true
	node.add_child(t)
	t.timeout.connect(t.queue_free)
	return t.timeout


# ---------- icons and chips ----------
static func fg_for(variant: int) -> Color:
	match variant:
		Variant.PRIMARY:
			return Tokens.BG
		Variant.GHOST:
			return Tokens.TEXT_MUTED
	return Tokens.TEXT


## Puts a vector icon on a button, colored like the button text.
static func set_icon(b: Button, icon_name: String, variant := Variant.SECONDARY, px := 34) -> void:
	b.icon = Icons.tex(icon_name, px, fg_for(variant))
	b.expand_icon = false
	b.add_theme_constant_override("h_separation", Tokens.SP_S)


## Button with an icon (and optional text). Icon-only buttons are square.
static func icon_button(icon_name: String, text := "", variant := Variant.GHOST, accent := Color("#2CC9B5"), sound := "tap") -> Button:
	var b := button(text, variant, accent, sound)
	set_icon(b, icon_name, variant)
	if text == "":
		b.custom_minimum_size = Vector2(Tokens.TOUCH_MIN, Tokens.TOUCH_MIN)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


static func icon_rect(icon_name: String, px := 28, color := Tokens.TEXT) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Icons.tex(icon_name, px, color)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Rounded pill for HUD values (time, score, moves, coins). Returns [panel, label].
static func chip(text: String, color := Tokens.TEXT, icon_name := "", icon_color := Tokens.TEXT) -> Array:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(Tokens.SURFACE_2, 0.92)
	st.set_corner_radius_all(999)
	st.border_width_top = 1
	st.border_color = Tokens.HIGHLIGHT
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	st.anti_aliasing = true
	p.add_theme_stylebox_override("panel", st)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := hbox(Tokens.SP_XS)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	if icon_name != "":
		h.add_child(icon_rect(icon_name, 26, icon_color))
	var l := label(text, Tokens.FS_CAPTION, color, Tokens.font_bold)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return [p, l]


## Updates a chip label and gives the pill a small pop when the value changes.
static func set_chip(l: Label, text: String, pop := true) -> void:
	if l == null or l.text == text:
		return
	l.text = text
	if pop and l.get_parent() and l.get_parent().get_parent() is Control:
		Motion.bump(l.get_parent().get_parent() as Control)



# ---------- premium effects (all off on low quality / reduce motion) ----------
## Material-style ripple from the touch point.
static func ripple(b: Control, color := Color.WHITE) -> void:
	if not Quality.fancy() or not b.is_inside_tree():
		return
	var r := Control.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(r)
	var center := b.get_local_mouse_position()
	var max_r := b.size.length()
	var state := {"t": 0.0}
	r.draw.connect(func():
		var t: float = state["t"]
		r.draw_circle(center, max_r * (0.15 + 0.85 * t), Color(color, 0.22 * (1.0 - t))))
	var tw := r.create_tween()
	tw.tween_method(func(v: float):
		state["t"] = v
		r.queue_redraw(), 0.0, 1.0, Motion.BASE * 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(r.queue_free)


## A diagonal light streak that sweeps across a call-to-action every few seconds.
static func shine(b: Control, every := 3.6) -> void:
	if not Quality.fancy():
		return
	if not b.is_inside_tree():
		b.tree_entered.connect(func(): shine(b, every), CONNECT_ONE_SHOT)
		return
	b.clip_contents = true
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.add_point(0.5, Color(1, 1, 1, 0.38))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 8
	var streak := TextureRect.new()
	streak.texture = gt
	streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	streak.stretch_mode = TextureRect.STRETCH_SCALE
	streak.size = Vector2(90, b.size.y * 2.2)
	streak.rotation = 0.35
	streak.position = Vector2(-160, -b.size.y * 0.6)
	b.add_child(streak)
	var tw := streak.create_tween().set_loops()
	tw.tween_interval(every)
	tw.tween_callback(func():
		streak.size.y = b.size.y * 2.2
		streak.position = Vector2(-160, -b.size.y * 0.6))
	# travel is computed each frame: the button may still be 0 wide when the tween is built
	tw.tween_method(func(k: float): streak.position.x = lerpf(-160.0, b.size.x + 160.0, k), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static var _confetti_tex: Texture2D


## Confetti: spinning paper bits in the world colors. Fires from `pos` toward `dir`.
static func confetti(parent: Node, pos: Vector2, dir := Vector2(0, -1), amount := 70) -> CPUParticles2D:
	if _confetti_tex == null:
		var img := Image.create(8, 14, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_confetti_tex = ImageTexture.create_from_image(img)
	var p := CPUParticles2D.new()
	p.amount = maxi(6, int(amount * Quality.particle_scale()))
	p.lifetime = 2.2
	p.one_shot = true
	p.explosiveness = 0.92
	p.texture = _confetti_tex
	p.direction = dir
	p.spread = 28.0
	p.initial_velocity_min = 700.0
	p.initial_velocity_max = 1150.0
	p.gravity = Vector2(0, 1100)
	p.damping_min = 120.0
	p.damping_max = 220.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Tokens.WORLD_COLORS[Tokens.World.KNOWLEDGE])
	ramp.add_point(0.33, Tokens.WORLD_COLORS[Tokens.World.PUZZLES])
	ramp.add_point(0.66, Tokens.WORLD_COLORS[Tokens.World.SPEED])
	ramp.set_color(ramp.get_point_count() - 1, Tokens.WORLD_COLORS[Tokens.World.BUILD])
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT   # crisp separate colors
	p.color_initial_ramp = ramp
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.add_point(0.8, Color.WHITE)
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Full-screen white flash (wins). Returns nothing; frees itself.
static func flash_screen(parent: Control, color := Color(1, 1, 1, 0.32)) -> void:
	if bool(Settings.get_value("reduce_motion")):
		return
	var f := ColorRect.new()
	f.color = color
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "modulate:a", 0.0, Motion.BASE * 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(f.queue_free)
