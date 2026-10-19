class_name Screen
extends Control
## Base for every full screen: RTL, animated world background, safe margins, scroll body.

var accent := Color("#2CC9B5")
var body: VBoxContainer
var scroll: ScrollContainer
var header: HBoxContainer
var back_target := "res://meta/home.tscn"
var _has_back := false


func build_screen(title: String, world_accent: Color, show_back := true) -> void:
	accent = world_accent
	set_anchors_preset(Control.PRESET_FULL_RECT)
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	add_child(WorldBg.make(accent))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe := DisplayServer.get_display_safe_area()
	var top_inset := 0
	if safe.size.y > 0:
		var scale_y := get_viewport_rect().size.y / float(DisplayServer.window_get_size().y)
		top_inset = int(safe.position.y * scale_y)
	margin.add_theme_constant_override("margin_top", maxi(top_inset, 24) + Tokens.SP_M)
	margin.add_theme_constant_override("margin_bottom", Tokens.SP_L)
	margin.add_theme_constant_override("margin_left", Tokens.SP_L)
	margin.add_theme_constant_override("margin_right", Tokens.SP_L)
	add_child(margin)

	var outer := UiKit.vbox(Tokens.SP_M)
	margin.add_child(outer)
	header = UiKit.hbox(Tokens.SP_M)
	outer.add_child(header)
	var t := UiKit.heading(title, Tokens.FS_H1)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	_has_back = show_back
	get_tree().set_quit_on_go_back(not show_back)
	if show_back:
		var back := UiKit.icon_button("back", "رجوع", UiKit.Variant.GHOST)
		back.custom_minimum_size = Vector2(150, 72)
		back.pressed.connect(go_back)
		header.add_child(back)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	body = UiKit.vbox(Tokens.SP_M)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)


func section(title: String) -> void:
	body.add_child(UiKit.label(title, Tokens.FS_H2, Tokens.TEXT_MUTED, Tokens.font_display))


func go_back() -> void:
	Router.go(back_target, accent)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _has_back:
		go_back()
