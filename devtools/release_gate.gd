extends Screen
## Release gate: everything that must be true before a public APK.
## Automatic checks + a manual checklist (saved on the device). Copy the report to chat.

const CHECK_PATH := "user://qa_checklist.json"
const SMOKE_SECONDS := 0.6
const MANUAL := [
	["install", "ثُبّتت نسخة Release على الجوال وفُتحت بدون أخطاء"],
	["fresh", "بعد حذف بيانات التطبيق: الترحيب يظهر والحفظ يبدأ من الصفر"],
	["kill", "أغلقت التطبيق بالقوة بعد ربح مرحلة: النجوم والعملات بقيت"],
	["back", "زر الرجوع في أندرويد يعمل في كل الشاشات ولا يغلق التطبيق فجأة أثناء اللعب"],
	["rtl", "كل النصوص العربية متصلة وصحيحة الاتجاه، ولا توجد مربعات بدل الحروف"],
	["latin", "أسئلة الإنجليزي ورموز الكيمياء (CO₂) وكلمة XP تظهر بخط واضح"],
	["all_games", "لعبت المرحلة الأولى من كل لعبة في العوالم الأربعة"],
	["result", "شاشة النتيجة: النجوم والعملات وزر التالي يظهر خلال أقل من ثانية"],
	["daily", "أنجزت التحدي اليومي: الجائزة صُرفت مرة واحدة، والبطاقة صارت «أنجزت»"],
	["clock", "أرجعت تاريخ الجوال يومًا: التحدي لم يُصرف مرتين"],
	["store", "اشتريت عنصرًا واستخدمته، ورصيد العملات صحيح"],
	["export", "صدّرت الحفظ، حذفت بيانات التطبيق، استوردته: رجع كل التقدم"],
	["audio", "الموسيقى والمؤثرات تعمل، وأزرار الصوت في الإعدادات تتحكم بها"],
	["mute", "وضع الصامت في الجوال والاهتزاز يعملان كما هو متوقع"],
	["quality", "جودة منخفضة: الخلفيات تتوقف عن الحركة"],
	["reduce_motion", "تقليل الحركة: لا اهتزاز للشاشة ولا انزلاقات"],
	["colorblind", "وضع عمى الألوان: التعليمات المتغيرة قابلة للعب بالأشكال"],
	["bench", "فحص الأداء: كل المراحل PASS أو أُرسل التقرير"],
	["battery", "لعبت 20 دقيقة: الجوال لم يسخن بشكل مزعج"],
	["airplane", "وضع الطيران: كل شيء يعمل بدون إنترنت"],
	["notch", "لا شيء مقطوع تحت الكاميرا أو أطراف الشاشة"],
	["keystore", "نسخة Release موقعة بمفتاح الإصدار، والمفتاح محفوظ في مكانين آمنين"],
]

var manual: Dictionary = {}
var auto_rows: VBoxContainer
var verdict: Label
var stage: Control
var report := PackedStringArray()
var auto_results: Array = []   # [name, ok, note]
var running := false


func _ready() -> void:
	back_target = "res://devtools/lab_hub.tscn"
	build_screen("بوابة الإصدار", Tokens.SUCCESS)
	if FileAccess.file_exists(CHECK_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CHECK_PATH))
		if parsed is Dictionary:
			manual = parsed
	verdict = UiKit.heading("", Tokens.FS_H2, Tokens.TEXT)
	body.add_child(verdict)
	var run := UiKit.button("شغّل الفحوص التلقائية (دقيقة تقريبًا)", UiKit.Variant.PRIMARY, Tokens.SUCCESS)
	run.pressed.connect(func():
		if not running:
			_run_auto())
	body.add_child(run)
	var copy := UiKit.button("نسخ تقرير البوابة", UiKit.Variant.SECONDARY, Tokens.SUCCESS)
	copy.pressed.connect(func():
		_build_report()
		DisplayServer.clipboard_set("\n".join(report))
		Sfx.play("correct"))
	body.add_child(copy)
	section("فحوص تلقائية")
	auto_rows = UiKit.vbox(Tokens.SP_XS)
	body.add_child(auto_rows)
	auto_rows.add_child(UiKit.label("لم تُشغّل بعد.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	section("فحوص يدوية")
	for item in MANUAL:
		body.add_child(_manual_row(item[0], item[1]))
	stage = Control.new()
	stage.custom_minimum_size = Vector2(1080, 1600)
	stage.position = Vector2(-5000, 0)   # offscreen, still processed and drawn
	stage.visible = true
	add_child(stage)
	_update_verdict()


func _manual_row(key: String, text: String) -> Control:
	var c := UiKit.card(0)
	var t := CheckButton.new()
	t.text = text
	t.button_pressed = bool(manual.get(key, false))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_override("font", Tokens.font_body)
	t.add_theme_font_size_override("font_size", Tokens.FS_CAPTION)
	for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		t.add_theme_color_override(k, Tokens.TEXT)
	t.focus_mode = Control.FOCUS_NONE
	t.toggled.connect(func(on: bool):
		manual[key] = on
		var f := FileAccess.open(CHECK_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(manual))
			f.close()
		_update_verdict())
	c.add_child(t)
	return c


func _add_auto(name_: String, ok: bool, note := "") -> void:
	auto_results.append([name_, ok, note])
	var l := UiKit.label(("PASS  " if ok else "FAIL  ") + name_ + ("" if note == "" else "  (" + note + ")"), Tokens.FS_CAPTION, Tokens.SUCCESS if ok else Tokens.ERROR, Tokens.font_bold)
	l.text_direction = Control.TEXT_DIRECTION_LTR
	auto_rows.add_child(l)


func _run_auto() -> void:
	running = true
	auto_results.clear()
	for c in auto_rows.get_children():
		c.queue_free()
	# 1. build identity
	var ver := str(ProjectSettings.get_setting("application/config/version"))
	_add_auto("version " + ver, ver != "" and not ver.contains("dev"))
	# 2. catalog
	_add_auto("catalog has no errors", Catalog.errors.is_empty(), str(Catalog.errors.size()))
	var public_games := 0
	for g in Catalog.games:
		if not bool(g.get("dev_only", false)):
			public_games += 1
	_add_auto("25 public games", public_games >= 25, str(public_games))
	# 3. content
	var items := ContentLab.load_questions()
	var errs := ContentLab.validate(items)
	_add_auto("question bank valid", errs.is_empty(), "" if errs.is_empty() else errs[0])
	var rr := ContentLab.release_report(items, ContentLab.load_reviews())
	_add_auto("all questions human-verified", int(rr["pending"]) == 0, "verified %d, flagged %d, pending %d" % [rr["verified"], rr["flagged"], rr["pending"]])
	# 4. data files
	_add_auto("achievements loaded", Achievements.defs().size() >= 20, str(Achievements.defs().size()))
	_add_auto("store loaded", Store.items().size() >= 10, str(Store.items().size()))
	# 5. unit tests (reuses the test runner offscreen)
	await _run_unit_tests()
	# 6. smoke: every level of every public game
	await _smoke()
	running = false
	_update_verdict()
	Sfx.play("win")


func _run_unit_tests() -> void:
	var tr: Node = load("res://devtools/test_runner.tscn").instantiate()
	stage.add_child(tr)
	var waited := 0
	while waited < 600:
		await get_tree().process_frame
		waited += 1
		if (tr.get("results") as Array).size() > 0 and waited > 5:
			break
	var results: Array = tr.get("results")
	var failed := []
	for r in results:
		if not r[1]:
			failed.append(r[0])
	_add_auto("unit tests %d/%d" % [results.size() - failed.size(), results.size()], failed.is_empty() and results.size() > 50, ", ".join(PackedStringArray(failed.slice(0, 3))))
	tr.queue_free()
	await get_tree().process_frame


func _smoke() -> void:
	var logger = null
	if ClassDB.class_exists("Logger"):
		var scr = load("res://devtools/smoke_logger.gd")
		if scr is GDScript and scr.can_instantiate():
			logger = scr.new()
			OS.add_logger(logger)
	var total := 0
	var bad := []
	for g in Catalog.games:
		if bool(g.get("dev_only", false)):
			continue
		for lvl in range(1, int(g["levels"]) + 1):
			total += 1
			var packed: PackedScene = load(g["scene"])
			var game := packed.instantiate() as MiniGame
			if game == null:
				bad.append("%s: not a MiniGame" % g["id"])
				break
			stage.add_child(game)
			game.start(g, lvl)
			var t := 0.0
			while t < SMOKE_SECONDS:
				await get_tree().process_frame
				t += get_process_delta_time()
			game.queue_free()
			await get_tree().process_frame
			if logger:
				var e: PackedStringArray = logger.take()
				if e.size() > 0:
					bad.append("%s:%d %s" % [g["id"], lvl, e[0]])
	if logger:
		OS.remove_logger(logger)
	_add_auto("smoke %d levels start without errors" % total, bad.is_empty(), ("error capture unavailable" if logger == null else "") + ("" if bad.is_empty() else "%d bad, first: %s" % [bad.size(), bad[0]]))
	for b in bad.slice(0, 8):
		report.append("SMOKE " + str(b))


func _update_verdict() -> void:
	var manual_done := 0
	for item in MANUAL:
		if bool(manual.get(item[0], false)):
			manual_done += 1
	var auto_ok := not auto_results.is_empty()
	for r in auto_results:
		auto_ok = auto_ok and bool(r[1])
	var ready := auto_ok and manual_done == MANUAL.size()
	verdict.text = ("جاهز للإصدار" if ready else "غير جاهز") + "  ·  يدوي %d/%d  ·  تلقائي %s" % [manual_done, MANUAL.size(), ("لم يُشغّل" if auto_results.is_empty() else ("ناجح" if auto_ok else "فيه فشل"))]
	verdict.add_theme_color_override("font_color", Tokens.SUCCESS if ready else Tokens.COIN)


func _build_report() -> void:
	var smoke_lines := []
	for l in report:
		if l.begins_with("SMOKE"):
			smoke_lines.append(l)
	report = PackedStringArray(["MADAR RELEASE GATE v%s | %s | debug=%s" % [ProjectSettings.get_setting("application/config/version"), OS.get_model_name(), str(OS.is_debug_build())], verdict.text])
	for r in auto_results:
		report.append(("PASS " if r[1] else "FAIL ") + str(r[0]) + ("" if str(r[2]) == "" else " | " + str(r[2])))
	for l in smoke_lines:
		report.append(l)
	for item in MANUAL:
		report.append(("[x] " if bool(manual.get(item[0], false)) else "[ ] ") + item[0])
