extends Screen
## Human content review: approve or flag each drafted question on the phone.
## Verdicts live in user://content_reviews.json (never in the shipped bank).
## Copy the JSON and send it back; the build tool merges "ok" verdicts as status=verified.

const CATS := ["all", "culture", "history", "physics", "chemistry", "biology", "english", "football", "geography"]
const CAT_NAMES := {"all": "الكل", "culture": "ثقافة", "history": "تاريخ", "physics": "فيزياء", "chemistry": "كيمياء", "biology": "أحياء", "english": "إنجليزي", "football": "كرة قدم", "geography": "جغرافيا"}

var items: Array = []
var reviews: Dictionary = {}
var queue: Array = []
var pos := 0
var cat := "all"
var flags := {}

var stats_l: Label
var card: PanelContainer
var card_box: VBoxContainer
var note_edit: LineEdit
var cat_btn: OptionButton


func _ready() -> void:
	back_target = "res://devtools/lab_hub.tscn"
	build_screen("مراجعة الأسئلة", Color("#F5B33D"))
	items = ContentLab.load_questions()
	reviews = ContentLab.load_reviews()
	var f = JSON.parse_string(FileAccess.get_file_as_string("res://content/knowledge/flags.json"))
	if f is Dictionary:
		for spec in f["flags"]:
			flags[spec["id"]] = spec

	stats_l = UiKit.label("", Tokens.FS_BODY, Tokens.COIN, Tokens.font_bold)
	body.add_child(stats_l)
	cat_btn = OptionButton.new()
	cat_btn.custom_minimum_size = Vector2(0, 72)
	cat_btn.add_theme_font_override("font", Tokens.font_bold)
	cat_btn.add_theme_font_size_override("font_size", Tokens.FS_BODY)
	for c in CATS:
		cat_btn.add_item(CAT_NAMES[c])
	cat_btn.item_selected.connect(func(i: int):
		cat = CATS[i]
		_rebuild_queue())
	body.add_child(cat_btn)

	card = UiKit.card(2)
	body.add_child(card)
	card_box = UiKit.vbox(Tokens.SP_S)
	card.add_child(card_box)

	note_edit = LineEdit.new()
	note_edit.placeholder_text = "ملاحظة (اختيارية): ما الخطأ؟"
	note_edit.custom_minimum_size = Vector2(0, 72)
	note_edit.add_theme_font_override("font", Tokens.font_body)
	note_edit.add_theme_font_size_override("font_size", Tokens.FS_BODY)
	body.add_child(note_edit)

	var row := UiKit.hbox(Tokens.SP_S)
	body.add_child(row)
	var ok_b := UiKit.button("سليم", UiKit.Variant.PRIMARY, Tokens.SUCCESS, "correct")
	ok_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok_b.pressed.connect(func(): _verdict("ok"))
	var fl_b := UiKit.button("مشكوك", UiKit.Variant.PRIMARY, Tokens.ERROR, "wrong")
	fl_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fl_b.pressed.connect(func(): _verdict("flag"))
	var sk_b := UiKit.button("تخطَّ", UiKit.Variant.SECONDARY, Color("#F5B33D"))
	sk_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sk_b.pressed.connect(_skip)
	row.add_child(ok_b)
	row.add_child(fl_b)
	row.add_child(sk_b)

	var copy := UiKit.button("نسخ ملف المراجعة", UiKit.Variant.SECONDARY, Color("#F5B33D"))
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(JSON.stringify({"reviewer_device": OS.get_model_name(), "bank_version": "0.8.0", "reviews": reviews}, "\t"))
		Sfx.play("correct"))
	body.add_child(copy)
	var hint := UiKit.label("راجع السؤال والإجابة المميزة والشرح. اضغط «سليم» فقط إذا تأكدت من المصدرين المقترحين. «مشكوك» يُخفي السؤال من اللعب فورًا.", Tokens.FS_CAPTION, Tokens.TEXT_MUTED)
	body.add_child(hint)
	_rebuild_queue()


func _rebuild_queue() -> void:
	queue.clear()
	for it in items:
		if cat != "all" and it["category"] != cat:
			continue
		if reviews.has(str(it["id"])):
			continue
		queue.append(it)
	pos = 0
	_show()


func _skip() -> void:
	if queue.is_empty():
		return
	pos = (pos + 1) % queue.size()
	_show()


func _verdict(v: String) -> void:
	if queue.is_empty():
		return
	var it: Dictionary = queue[pos]
	reviews[str(it["id"])] = {"verdict": v, "note": note_edit.text.strip_edges(), "at": Time.get_datetime_string_from_system(true)}
	ContentLab.save_reviews(reviews)
	note_edit.text = ""
	queue.remove_at(pos)
	if pos >= queue.size():
		pos = 0
	_show()


func _show() -> void:
	var r := ContentLab.release_report(items, reviews)
	stats_l.text = "سليم %d  ·  مشكوك %d  ·  متبقٍّ %d  من %d" % [r["verified"], r["flagged"], r["pending"], r["total"]]
	for c in card_box.get_children():
		c.queue_free()
	if queue.is_empty():
		card_box.add_child(UiKit.label("لا توجد أسئلة متبقية في هذا القسم.", Tokens.FS_BODY, Tokens.SUCCESS, Tokens.font_bold))
		return
	var it: Dictionary = queue[pos]
	card_box.add_child(UiKit.label("%s  ·  صعوبة %d  ·  %d/%d" % [CAT_NAMES.get(it["category"], it["category"]), int(it["difficulty"]), pos + 1, queue.size()], Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
	if it.has("flag") and flags.has(it["flag"]):
		var fv := FlagView.new()
		fv.custom_minimum_size = Vector2(0, 220)
		fv.set_spec(flags[it["flag"]])
		card_box.add_child(fv)
	card_box.add_child(UiKit.label(str(it["question"]), Tokens.FS_H2, Tokens.TEXT, Tokens.font_bold))
	var answers: Array = it["answers"]
	for i in answers.size():
		var good := i == int(it["correct"])
		card_box.add_child(UiKit.label(("الصحيحة: " if good else "خطأ: ") + str(answers[i]), Tokens.FS_BODY, Tokens.SUCCESS if good else Tokens.TEXT_MUTED, Tokens.font_bold if good else null))
	card_box.add_child(UiKit.label("الشرح: " + str(it.get("explanation", "")), Tokens.FS_CAPTION, Tokens.TEXT))
	card_box.add_child(UiKit.label("مصادر للتحقق: " + "، ".join(PackedStringArray(it.get("sources_suggested", []))), Tokens.FS_CAPTION, Color("#F5B33D")))
	card_box.add_child(UiKit.label("المعرّف: " + str(it["id"]), Tokens.FS_CAPTION, Tokens.TEXT_MUTED))
