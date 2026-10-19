class_name MiniGame
extends Control
## Contract every game implements. The host calls start(); the game emits finished(result).
## result = {"stars": 0..3, "score": int, "won": bool, "detail": String}
## Games must NOT touch Progress, SaveService or other games. The one exception is paid
## hints, and it goes through coins() / spend_coins() below (saved at once by Progress).

signal finished(result: Dictionary)

var game: Dictionary = {}
var level_id := 1
var accent := Color.WHITE
var _finished := false
var hud: HBoxContainer
var title_label: Label


func start(p_game: Dictionary, p_level: int) -> void:
	game = p_game
	level_id = p_level
	accent = Catalog.world_color(game)
	_on_start()


## Override in each game.
func _on_start() -> void:
	pass


## Safe delay (dies with the game if the player leaves; pauses with the game).
func wait(sec: float) -> Signal:
	return UiKit.wait(self, sec)


func finish(stars: int, score: int, detail := "") -> void:
	if _finished:
		return
	_finished = true
	finished.emit({"stars": clampi(stars, 0, 3), "score": maxi(score, 0), "won": stars > 0, "detail": detail})


## Player's coin balance (read-only view for paid-hint buttons).
func coins() -> int:
	return Progress.model.coins()


## Paid hint: takes `amount` coins. False (and nothing spent) if the player cannot afford it.
func spend_coins(amount: int) -> bool:
	return Progress.spend(amount)


# ---------- shared layout (same look in every game) ----------
## Background + title row with HUD chips + content column. Returns the column.
func frame(title: String, side := 24) -> VBoxContainer:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	add_child(WorldBg.make(accent))
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_left", side)
	m.add_theme_constant_override("margin_right", side)
	m.add_theme_constant_override("margin_bottom", 28)
	add_child(m)
	var v := UiKit.vbox(Tokens.SP_S)
	m.add_child(v)
	var top := UiKit.hbox(Tokens.SP_S)
	title_label = UiKit.heading(title, Tokens.FS_H2, accent)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(title_label)
	hud = UiKit.hbox(Tokens.SP_XS)
	top.add_child(hud)
	v.add_child(top)
	return v


## Adds a HUD pill to the title row and returns its label.
func chip(text := "", icon_name := "", color := Tokens.TEXT) -> Label:
	var c := UiKit.chip(text, color, icon_name, accent)
	hud.add_child(c[0])
	return c[1]


## Bottom row of equal-width buttons.
func action_bar(buttons: Array) -> HBoxContainer:
	var h := UiKit.hbox(Tokens.SP_S)
	for b in buttons:
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	return h
