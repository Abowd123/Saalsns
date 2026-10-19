class_name SaveTransfer
## Export / import of the whole save as one text block (clipboard friendly).
## Format: MADARX1.<base64 of JSON>.<first 16 hex of sha256(JSON)>
## The checksum catches broken copy/paste. It is not anti-cheat (the game is offline).

const PREFIX := "MADARX1"


static func encode(data: Dictionary) -> String:
	var body := JSON.stringify(data)
	return "%s.%s.%s" % [PREFIX, Marshalls.utf8_to_base64(body), body.sha256_text().left(16)]


## Returns {"ok": true, "data": Dictionary} or {"ok": false, "error": String (Arabic)}.
static func decode(text: String) -> Dictionary:
	text = text.strip_edges().replace("\n", "").replace(" ", "")
	var parts := text.split(".")
	if parts.size() != 3 or parts[0] != PREFIX:
		return {"ok": false, "error": "النص ليس ملف حفظ من مدار."}
	var body := Marshalls.base64_to_utf8(parts[1])
	if body == "" or body.sha256_text().left(16) != parts[2]:
		return {"ok": false, "error": "النص ناقص أو تغيّر أثناء النسخ."}
	var parsed = JSON.parse_string(body)
	if not (parsed is Dictionary):
		return {"ok": false, "error": "محتوى الحفظ تالف."}
	if int(parsed.get("schema", 0)) > SaveStore.CURRENT_SCHEMA:
		return {"ok": false, "error": "هذا الحفظ من نسخة أحدث من التطبيق. حدّث التطبيق أولًا."}
	if not _shape_ok(parsed):
		return {"ok": false, "error": "محتوى الحفظ تالف."}
	return {"ok": true, "data": SaveStore.migrate(parsed)}


## Types that the game reads without checks must have the right shape, or the app
## would crash after import.
static func _shape_ok(d: Dictionary) -> bool:
	for k in ["settings", "progress", "profile"]:
		if d.has(k) and not (d[k] is Dictionary):
			return false
	var p = d.get("progress", {})
	if not (p is Dictionary):
		return false
	for k in ["ledger", "levels", "best", "stats"]:
		if p.has(k) and not (p[k] is Dictionary):
			return false
	if p.has("history") and not (p["history"] is Array):
		return false
	for k in ["xp", "coins", "daily_total", "daily_streak", "daily_streak_best", "daily_last", "daily_max_seen"]:
		if p.has(k) and not (p[k] is int or p[k] is float):
			return false
	if p.has("levels"):
		for lk in p["levels"]:
			if not (p["levels"][lk] is Dictionary):
				return false
	return true


## Short human summary shown before the player confirms an import.
static func summary(data: Dictionary) -> String:
	var m := ProgressModel.new((data.get("progress", {}) as Dictionary).duplicate(true))
	var lv := ProgressModel.level_from_xp(m.xp())
	var when := Time.get_datetime_string_from_unix_time(int(data.get("saved_unix", 0))).replace("T", " ").left(16)
	return "المستوى %d  ·  %d نجمة  ·  %d عملة  ·  آخر حفظ %s" % [lv["level"], m.total_stars(), m.coins(), when]
