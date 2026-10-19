class_name ResultScreen
extends Control
## Shared win/lose sheet. Stars already earned show instantly; new ones pop with sound.
## "Next" is always reachable within Motion.NEXT_BUTTON_MAX_DELAY.

signal next_pressed
signal retry_pressed
signal home_pressed

var _sheet: PanelContainer
var _badges: Array[Control] = []
var _buttons: Array = []
var _rays: RaysView
var _row: Control
var _perfect: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_result(r: Dictionary, accent: Color, has_next: bool) -> void:
	var won := int(r["stars"]) > 0
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	Motion.fade_in(dim, Motion.BASE)

	_sheet = UiKit.card(2)
	_sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_sheet.offset_left = Tokens.SP_M
	_sheet.offset_right = -Tokens.SP_M
	_sheet.offset_bottom = -Tokens.SP_XL
	_sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_sheet)
	var v := UiKit.vbox(Tokens.SP_M)
	_sheet.add_child(v)

	var title := UiKit.heading("أحسنت!" if won else "قريب جدًا", Tokens.FS_H1, Tokens.SUCCESS if won else Tokens.ERROR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var row := UiKit.hbox(Tokens.SP_M)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var stars: Array[StarIcon] = []
	for i in 3:
		var s := StarIcon.new()
		s.custom_minimum_size = Vector2(96, 96)
		s.filled = (i + 1) <= int(r["prev_stars"]) and (i + 1) <= int(r["stars"])
		row.add_child(s)
		stars.append(s)
	v.add_child(row)
	_row = row
	if won and Quality.fancy():
		_rays = RaysView.new()
		_rays.color = Store.equipped_color("burst", Tokens.COIN)
		_rays.top_level = true   # free from the row layout, drawn behind the stars
		row.add_child(_rays)
		row.move_child(_rays, 0)
	if int(r["stars"]) == 3:
		_perfect = UiKit.heading("مثالي!", Tokens.FS_H1 + 8, Tokens.COIN)
		_perfect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_perfect.modulate.a = 0.0
		v.add_child(_perfect)

	var xp_l := UiKit.label("+0 XP", Tokens.FS_H2, Tokens.TEXT, Tokens.font_bold)
	xp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_l.text_direction = Control.TEXT_DIRECTION_LTR
	v.add_child(xp_l)
	var info := "+%d عملة" % int(r["coins"]) if int(r["coins"]) > 0 else ""
	if bool(r.get("new_best", false)):
		info += ("  ·  " if info != "" else "") + "رقم قياسي جديد: %d" % int(r["best"])
	if int(r["level_after"]) > int(r["level_before"]):
		info += ("  ·  " if info != "" else "") + "وصلت للمستوى %d" % int(r["level_after"])
	if r.has("daily"):
		info += ("\n" if info != "" else "") + "التحدي اليومي: +%d XP و+%d عملة  ·  سلسلة %d يوم" % [int(r["daily"]["xp"]), int(r["daily"]["coins"]), int(r["daily"]["streak"])]
	if str(r.get("detail", "")) != "":
		info += ("\n" if info != "" else "") + str(r["detail"])
	var info_l := UiKit.label(info, Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	info_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info_l)

	var buttons := UiKit.hbox(Tokens.SP_S)
	var primary_text := "التالي" if (won and has_next) else "حاول مجددًا"
	var primary := UiKit.button(primary_text, UiKit.Variant.PRIMARY, Tokens.SUCCESS if won else accent)
	UiKit.set_icon(primary, "arrow_left" if (won and has_next) else "restart", UiKit.Variant.PRIMARY)
	if won:
		UiKit.shine(primary)
	primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary.pressed.connect(func(): (next_pressed if (won and has_next) else retry_pressed).emit())
	var retry := UiKit.button("إعادة" if (won and has_next) else "الرئيسية", UiKit.Variant.SECONDARY, Tokens.LINE)
	UiKit.set_icon(retry, "restart" if (won and has_next) else "home", UiKit.Variant.SECONDARY)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(func(): (retry_pressed if (won and has_next) else home_pressed).emit())
	buttons.add_child(primary)
	buttons.add_child(retry)
	v.add_child(buttons)
	buttons.modulate.a = 0.0
	primary.disabled = true   # not clickable while invisible
	retry.disabled = true
	_buttons = [primary, retry]
	var achs: Array = r.get("achievements", [])
	for a in achs:
		var badge := UiKit.card(1, Tokens.SURFACE_2)
		var bl := UiKit.label("إنجاز جديد: %s  ·  %s" % [a["title"], a["desc"]], Tokens.FS_CAPTION, Tokens.COIN, Tokens.font_bold)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(bl)
		v.add_child(badge)
		v.move_child(badge, v.get_child_count() - 2)
		badge.modulate.a = 0.0
		_badges.append(badge)

	_animate(stars, r, xp_l, buttons, won)


func _animate(stars: Array[StarIcon], r: Dictionary, xp_l: Label, buttons: Control, won: bool) -> void:
	await get_tree().process_frame
	var target_y := _sheet.position.y
	_sheet.position.y += 400.0
	var tw := _sheet.create_tween()
	tw.tween_property(_sheet, "position:y", target_y, Motion.BASE * 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("win" if won else "wrong")
	UiKit.wait(self, Motion.NEXT_BUTTON_MAX_DELAY).connect(_show_buttons.bind(buttons))
	await UiKit.wait(self, Motion.BASE)
	for i in int(r["stars"]):
		var s := stars[i]
		if not s.filled:
			s.filled = true
			Motion.pop_in(s)
			if not Motion.reduce_motion:
				s.rotation = -0.9
				s.create_tween().tween_property(s, "rotation", 0.0, Motion.POP * 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Sfx.play("star%d" % (i + 1), 1.0 + 0.06 * i)
			UiKit.burst(s, s.size / 2.0, Store.equipped_color("burst", Tokens.COIN), 26)
			Settings.vibrate(15)
			await UiKit.wait(self, Motion.POP)
	if _perfect:
		Motion.pop_in(_perfect)
		Sfx.play("win", 1.15)
		if Quality.fancy():
			UiKit.confetti(self, _perfect.get_global_rect().get_center() - global_position, Vector2(0, -1), 60)
	Motion.count_to(xp_l, 0, int(r["xp"]), "+", " XP")
	if int(r["coins"]) > 0:
		Sfx.play("coin")
	for b in _badges:
		await UiKit.wait(self, Motion.POP)
		Motion.pop_in(b)
		Sfx.play("star3")
		UiKit.burst(b, b.size / 2.0, Store.equipped_color("burst", Tokens.COIN), 30)


func _show_buttons(buttons: Control) -> void:
	for b in _buttons:
		(b as Button).disabled = false
	Motion.fade_in(buttons, Motion.FAST)


func _process(_delta: float) -> void:
	if _rays and _row and _row.is_inside_tree():
		_rays.global_position = _row.get_global_rect().get_center() - _rays.size / 2.0
