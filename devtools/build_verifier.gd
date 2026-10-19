extends Screen
## Replays the shipped reference solution of every "draw" level in real Godot physics.
## A level passes only if the ball rests in the goal within the timeout.

const TIMEOUT := 12.0
var rows: VBoxContainer
var report := PackedStringArray(["MADAR DRAW VERIFIER"])
var stage: Control


func _ready() -> void:
	back_target = "res://devtools/lab_hub.tscn"
	build_screen("فاحص ارسم الحل", Color("#9BDB4D"))
	rows = UiKit.vbox(Tokens.SP_XS)
	body.add_child(rows)
	var copy := UiKit.button("نسخ التقرير", UiKit.Variant.PRIMARY, Color("#9BDB4D"))
	copy.pressed.connect(func(): DisplayServer.clipboard_set("\n".join(report)))
	body.add_child(copy)
	stage = Control.new()
	stage.custom_minimum_size = Vector2(0, 900)
	body.add_child(stage)
	await get_tree().process_frame
	var g := Catalog.get_game("draw")
	for lvl in range(1, int(g.get("levels", 0)) + 1):
		await _verify(g, lvl)
	_line("انتهى الفحص", Tokens.TEXT)


func _verify(g: Dictionary, lvl: int) -> void:
	var game: MiniGame = load(g["scene"]).instantiate()
	game.set("autoplay", true)
	stage.add_child(game)
	var result := {"done": false, "stars": 0}
	game.finished.connect(func(r: Dictionary):
		result["done"] = true
		result["stars"] = int(r["stars"]))
	game.start(g, lvl)
	var t := 0.0
	while not result["done"] and t < TIMEOUT:
		await get_tree().process_frame
		t += get_process_delta_time()
	var ok: bool = result["done"]
	_line("%s  المرحلة %d  %s" % ["PASS" if ok else "FAIL", lvl, ("(%.1f ث)" % t) if ok else "لم تصل الكرة"], Tokens.SUCCESS if ok else Tokens.ERROR)
	report.append("%s level %d t=%.1f" % ["PASS" if ok else "FAIL", lvl, t])
	game.queue_free()
	await get_tree().process_frame


func _line(text: String, color: Color) -> void:
	rows.add_child(UiKit.label(text, Tokens.FS_BODY, color, Tokens.font_bold))
