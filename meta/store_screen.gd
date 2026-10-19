extends Screen
## Cosmetics store: avatars, ring colors, celebration colors. Cosmetic only.

var coins_l: Label
var grid_box: VBoxContainer
var tab := "avatar"
const TAB_NAMES := {"avatar": "الصور", "ring": "الحلقات", "burst": "الاحتفال"}


func _ready() -> void:
	back_target = "res://meta/profile_screen.tscn"
	build_screen("المتجر", Tokens.COIN)
	coins_l = UiKit.label("", Tokens.FS_H2, Tokens.COIN, Tokens.font_bold)
	body.add_child(coins_l)
	body.add_child(UiKit.label("عناصر شكلية فقط، لا تعطي أفضلية في اللعب. بعضها يُفتح بالإنجازات.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	var tabs := UiKit.hbox(Tokens.SP_S)
	body.add_child(tabs)
	var tab_buttons: Array[Button] = []
	for k in Store.KINDS:
		var b := UiKit.button(TAB_NAMES[k], UiKit.Variant.SECONDARY, Tokens.COIN)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = k == tab
		tabs.add_child(b)
		tab_buttons.append(b)
	for i in tab_buttons.size():
		var kind: String = Store.KINDS[i]
		tab_buttons[i].pressed.connect(func():
			tab = kind
			for j in tab_buttons.size():
				tab_buttons[j].set_pressed_no_signal(j == i)
			_render())
	grid_box = UiKit.vbox(Tokens.SP_S)
	body.add_child(grid_box)
	_render()


func _render() -> void:
	coins_l.text = "%d عملة" % Progress.model.coins()
	for c in grid_box.get_children():
		c.queue_free()
	var m := Progress.model
	var prof := SaveService.section("profile")
	var current := Store.equipped(m, prof, tab)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Tokens.SP_S)
	grid.add_theme_constant_override("v_separation", Tokens.SP_S)
	grid_box.add_child(grid)
	for it in Store.items():
		if it["kind"] != tab:
			continue
		grid.add_child(_card(it, m, prof, current))


func _preview(it: Dictionary) -> Control:
	if it["kind"] == "avatar":
		var av := AvatarView.new()
		av.custom_minimum_size = Vector2(0, 120)
		av.set_item(it)
		return av
	var sw := Control.new()
	sw.custom_minimum_size = Vector2(0, 120)
	var col := Color(it["color"])
	var is_ring: bool = it["kind"] == "ring"
	sw.draw.connect(func():
		var c := sw.size / 2.0
		if is_ring:
			sw.draw_arc(c, 44.0, 0.0, TAU, 64, col, 9.0, true)
		else:
			for k in 12:
				var a := TAU * k / 12.0
				sw.draw_circle(c + Vector2(cos(a), sin(a)) * (26.0 + 18.0 * (k % 2)), 6.0 - 2.0 * (k % 2), col))
	return sw


func _card(it: Dictionary, m: ProgressModel, prof: Dictionary, current: Dictionary) -> Control:
	var c := UiKit.card(1, Tokens.SURFACE_2 if it["id"] == current.get("id", "") else Tokens.SURFACE_1)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(Tokens.SP_XS)
	c.add_child(v)
	v.add_child(_preview(it))
	var t := UiKit.label(str(it["title"]), Tokens.FS_BODY, Tokens.TEXT, Tokens.font_bold)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := Store.state(m, it)
	var b: Button
	if it["id"] == current.get("id", ""):
		b = UiKit.button("مُستخدم", UiKit.Variant.GHOST)
		b.disabled = true
	elif st == "owned":
		b = UiKit.button("استخدم", UiKit.Variant.SECONDARY, Tokens.SUCCESS)
		b.pressed.connect(func():
			Store.equip(m, prof, it)
			SaveService.save_now()
			Sfx.play("pop")
			_render())
	elif st == "locked":
		var req := {}
		for a in Achievements.defs():
			if a["id"] == it["requires"]:
				req = a
		b = UiKit.button("يُفتح بإنجاز: " + str(req.get("title", "")), UiKit.Variant.GHOST)
		b.disabled = true
	else:
		var price := int(it["price"])
		b = UiKit.button(("مجاني" if price == 0 else "%d عملة" % price), UiKit.Variant.PRIMARY, Tokens.COIN)
		b.disabled = st == "poor"
		b.pressed.connect(func():
			if Progress.buy(it):
				Store.equip(Progress.model, prof, it)
				SaveService.save_now()
				Sfx.play("coin")
				UiKit.burst(self, c.global_position - global_position + c.size / 2.0, Color(it["color"]), 40)
				Progress.check_achievements()
				_render()
			else:
				Sfx.play("wrong"))
	b.add_theme_font_size_override("font_size", Tokens.FS_CAPTION)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(b)
	return c
