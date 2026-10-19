extends Screen
## In-app automated tests for core systems. Run on the phone; copy the report to chat.
## Uses separate test files (user://test_*.json); never touches the real save.

const MazeScript := preload("res://games/maze/maze_game.gd")
const EscapeScript := preload("res://games/escape/escape_game.gd")
const LightningScript := preload("res://games/lightning/lightning_game.gd")
const HunterScript := preload("res://games/hunter/hunter_game.gd")
const FP_SEED := 2026
const GuessScript := preload("res://games/guess_picture/guess_picture_game.gd")
const PackingScript := preload("res://games/packing/packing_game.gd")
const PipeCostScript := preload("res://games/pipe_cost/pipe_cost_game.gd")
const PhysicsLabScript := preload("res://games/physics_lab/physics_lab_game.gd")
const BridgeScript := preload("res://games/bridge/bridge_game.gd")   # same seed as tools/speed_check.py

var results: Array = []   # [name, ok, note]
var list: VBoxContainer
var summary: Label


func _ready() -> void:
	back_target = "res://devtools/lab_hub.tscn"
	build_screen("اختبارات الأنظمة", Color("#9BDB4D"))
	summary = UiKit.label("جارٍ التشغيل...", Tokens.FS_H2, Tokens.TEXT, Tokens.font_bold)
	body.add_child(summary)
	var copy := UiKit.button("نسخ التقرير", UiKit.Variant.PRIMARY, Color("#9BDB4D"))
	copy.pressed.connect(_copy)
	body.add_child(copy)
	list = UiKit.vbox(Tokens.SP_XS)
	body.add_child(list)
	await get_tree().process_frame
	_run_all()


func check(test_name: String, ok: bool, note := "") -> void:
	results.append([test_name, ok, note])


func _run_all() -> void:
	var t0 := Time.get_ticks_msec()
	for m in get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_"):
			var before := results.size()
			call(n)
			if results.size() == before:
				check(n, false, "no checks ran")
	var passed := 0
	for r in results:
		var row := UiKit.label(("PASS  " if r[1] else "FAIL  ") + r[0] + ("" if r[2] == "" else "  (" + str(r[2]) + ")"), Tokens.FS_CAPTION, Tokens.SUCCESS if r[1] else Tokens.ERROR)
		row.text_direction = Control.TEXT_DIRECTION_LTR
		list.add_child(row)
		if r[1]:
			passed += 1
	summary.text = "%d / %d نجح  ·  %d ms" % [passed, results.size(), Time.get_ticks_msec() - t0]
	summary.add_theme_color_override("font_color", Tokens.SUCCESS if passed == results.size() else Tokens.ERROR)
	Log.info("tests %d/%d passed" % [passed, results.size()])


func _copy() -> void:
	var lines := PackedStringArray(["MADAR TESTS v" + str(ProjectSettings.get_setting("application/config/version")), summary.text])
	for r in results:
		lines.append(("PASS " if r[1] else "FAIL ") + r[0] + ("" if r[2] == "" else " | " + str(r[2])))
	lines.append("--- last log lines ---")
	var log_lines := Log.read_all().split("\n")
	for i in range(maxi(0, log_lines.size() - 25), log_lines.size()):
		lines.append(log_lines[i])
	DisplayServer.clipboard_set("\n".join(lines))
	Sfx.play("correct")


# ---------------- Save ----------------
func test_save_roundtrip() -> void:
	var s := SaveStore.new("user://test_rt.json")
	s.delete_all()
	s.load_or_create()
	check("save: fresh on first load", s.loaded_from == "fresh")
	s.data["progress"] = {"xp": 42, "name": "مدار"}
	check("save: write ok", s.save())
	var s2 := SaveStore.new("user://test_rt.json")
	s2.load_or_create()
	check("save: reload from main", s2.loaded_from == "main", s2.loaded_from)
	check("save: values survive", int(s2.data["progress"]["xp"]) == 42 and s2.data["progress"]["name"] == "مدار")
	s.delete_all()


func test_save_corruption_recovery() -> void:
	var s := SaveStore.new("user://test_cr.json")
	s.delete_all()
	s.load_or_create()
	s.data["progress"] = {"xp": 1}
	s.save()
	s.data["progress"] = {"xp": 2}
	s.save()
	var f := FileAccess.open("user://test_cr.json", FileAccess.WRITE)
	f.store_string("MADAR1 deadbeef\n{\"broken\":")
	f.close()
	var s2 := SaveStore.new("user://test_cr.json")
	s2.load_or_create()
	check("save: corrupt main falls back to bak1", s2.loaded_from == "bak1", s2.loaded_from)
	check("save: bak1 holds previous value", int(s2.data["progress"].get("xp", -1)) == 1)
	for p in ["user://test_cr.json", "user://test_cr.bak1", "user://test_cr.bak2"]:
		var g := FileAccess.open(p, FileAccess.WRITE)
		g.store_string("garbage")
		g.close()
	var s3 := SaveStore.new("user://test_cr.json")
	s3.load_or_create()
	check("save: all corrupt gives fresh", s3.loaded_from == "fresh")
	s.delete_all()


func test_save_tamper_detected() -> void:
	var s := SaveStore.new("user://test_tp.json")
	s.delete_all()
	s.load_or_create()
	s.data["progress"] = {"coins": 10}
	s.save()
	var text := FileAccess.get_file_as_string("user://test_tp.json").replace("10", "99999")
	var f := FileAccess.open("user://test_tp.json", FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var s2 := SaveStore.new("user://test_tp.json")
	s2.load_or_create()
	check("save: edited file rejected by checksum", s2.loaded_from != "main", s2.loaded_from)
	s.delete_all()


func test_migration_v0() -> void:
	var m := SaveStore.migrate({"launch_count": 3})
	check("migrate: v0 -> v1 schema", int(m["schema"]) == 1)
	check("migrate: legacy kept", m.has("legacy") and int(m["legacy"]["launch_count"]) == 3)
	check("migrate: sections exist", m.has("settings") and m.has("progress"))


# ---------------- Progress ----------------
func test_level_curve() -> void:
	check("xp: level 1 needs 100", ProgressModel.xp_to_next(1) == 100)
	check("xp: level 4 needs 800", ProgressModel.xp_to_next(4) == 800)
	var l := ProgressModel.level_from_xp(100 + 282)
	check("xp: 382 xp -> level 3", int(l["level"]) == 3, str(l))


func test_ledger_idempotent() -> void:
	var p := ProgressModel.new({})
	check("ledger: first grant true", p.grant("k1", 10, 5))
	check("ledger: second grant false", not p.grant("k1", 10, 5))
	check("ledger: paid once", p.xp() == 10 and p.coins() == 5)


func test_report_result_rules() -> void:
	var p := ProgressModel.new({})
	var r1 := p.report_result("g", 1, 2, 50, 40, 5)
	check("result: first clear 2 stars xp = 50", int(r1["xp"]) == 50, str(r1["xp"]))
	check("result: first star pays 5 coins", int(r1["coins"]) == 5)
	var r2 := p.report_result("g", 1, 2, 60, 40, 5)
	check("result: replay xp = 25%", int(r2["xp"]) == 13, str(r2["xp"]))
	check("result: replay pays no coins", int(r2["coins"]) == 0)
	check("result: new best detected", bool(r2["new_best"]))
	var r3 := p.report_result("g", 1, 3, 10, 40, 5)
	check("result: upgrade pays no coins", int(r3["coins"]) == 0 and r3["new_stars"].size() == 1 and int(r3["new_stars"][0]) == 3)
	check("result: stars kept at max", p.stars_for("g", 1) == 3)
	var r4 := p.report_result("g", 1, 0, 0, 40, 5)
	check("result: loss gives nothing", int(r4["xp"]) == 0 and int(r4["coins"]) == 0)
	check("result: loss keeps 3 stars", p.stars_for("g", 1) == 3)


func test_spend() -> void:
	var p := ProgressModel.new({"coins": 10})
	check("spend: cannot overspend", not p.spend(11) and p.coins() == 10)
	check("spend: valid spend", p.spend(4) and p.coins() == 6)
	check("spend: zero/negative rejected", not p.spend(0) and not p.spend(-5))


func test_daily_guard() -> void:
	var p := ProgressModel.new({})
	check("daily: available", p.daily_status(20261018) == "available")
	check("daily: claim once", p.claim_daily(20261018, 30, 10))
	check("daily: second claim blocked", not p.claim_daily(20261018, 30, 10))
	check("daily: clock rollback blocked", p.daily_status(20261017) == "clock_rollback")
	check("daily: next day available", p.claim_daily(20261019, 30, 10))


func test_history_cap() -> void:
	var p := ProgressModel.new({})
	for i in 60:
		p.report_result("g", 1, 1, i, 10, 1)
	check("history: capped at 50", p.d["history"].size() == 50)


# ---------------- Settings / Catalog ----------------
func test_settings_clamp() -> void:
	var old_music = Settings.get_value("music")
	Settings.set_value("music", 5.0)
	check("settings: volume clamped to 1", is_equal_approx(float(Settings.get_value("music")), 1.0))
	Settings.set_value("fps", 45)
	check("settings: fps snaps to 60", int(Settings.get_value("fps")) == 60)
	Settings.set_value("fps", 60)
	Settings.set_value("music", old_music)
	check("settings: audio buses exist", AudioServer.get_bus_index("Music") != -1 and AudioServer.get_bus_index("SFX") != -1)


func test_catalog() -> void:
	check("catalog: loaded without errors", Catalog.errors.is_empty(), str(Catalog.errors))
	check("catalog: demo game present", not Catalog.get_game("demo_tap").is_empty())
	check("catalog: rejects missing fields", Catalog.validate({"id": "x"}, {}) != "")
	check("catalog: rejects bad world", Catalog.validate({"id": "x", "world": "moon", "title": "", "scene": "res://games/demo_tap/demo_tap.tscn", "levels": 1, "base_xp": 1, "coins_per_star": 1}, {}) != "")
	check("catalog: rejects duplicate id", Catalog.validate({"id": "demo_tap"}, {"demo_tap": true}) != "")


func test_stats_helpers() -> void:
	var p := ProgressModel.new({})
	p.report_result("a", 1, 3, 10, 10, 1)
	p.report_result("a", 2, 1, 30, 10, 1)
	p.report_result("b", 1, 0, 5, 10, 1)
	check("stats: stars in game a = 4", p.stars_in_game("a") == 4)
	check("stats: total stars = 4", p.total_stars() == 4)
	check("stats: total plays = 3", p.total_plays() == 3)
	check("stats: best in a = 30", p.best_in_game("a") == 30)
	check("stats: last played is b", str(p.last_played().get("g", "")) == "b")
	var rg := p.recent_games()
	check("stats: recent order b,a", rg.size() == 2 and rg[0] == "b" and rg[1] == "a")
	check("stats: resume a -> level 3", p.resume_level("a", 5) == 3)
	check("stats: resume capped", p.resume_level("a", 2) == 2)
	check("stats: resume b after loss -> 1", p.resume_level("b", 5) == 1)



# ---------------- Phase 8: knowledge content ----------------
func test_content_bank_valid() -> void:
	var items := ContentLab.load_questions()
	check("content: bank loaded", items.size() >= 500, str(items.size()))
	var errs := ContentLab.validate(items)
	check("content: 0 validation errors", errs.is_empty(), "" if errs.is_empty() else "%d: %s" % [errs.size(), errs[0]])
	var cats := {}
	for it in items:
		cats[it["category"]] = int(cats.get(it["category"], 0)) + 1
	for c in ["culture", "history", "physics", "chemistry", "biology", "english", "football"]:
		check("content: %s has >= 10" % c, int(cats.get(c, 0)) >= 10, str(cats.get(c, 0)))


func test_content_validator_catches_bad() -> void:
	var bad := [{"id": "x1", "question": "س؟", "answers": ["أ", "أ", "ب", "ج"], "correct": 5, "explanation": "", "sources_suggested": []}]
	check("content: validator rejects bad item", ContentLab.validate(bad).size() >= 3, str(ContentLab.validate(bad).size()))
	var dup := [
		{"id": "d1", "question": "ما عاصمة مصر؟", "answers": ["1", "2", "3", "4"], "correct": 0, "explanation": "x", "sources_suggested": ["a", "b"]},
		{"id": "d2", "question": "ما عاصمةُ مصر", "answers": ["1", "2", "3", "4"], "correct": 0, "explanation": "x", "sources_suggested": ["a", "b"]}]
	check("content: near-duplicate detected", ContentLab.validate(dup).size() == 1)


func test_shuffle_keeps_answer() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var items := ContentLab.load_questions()
	var bad := 0
	var at_zero := 0
	for i in 400:
		var it: Dictionary = items[i % items.size()]
		var q := ContentLab.shuffled(it, rng)
		if str(q["answers"][int(q["correct"])]) != str(it["answers"][int(it["correct"])]):
			bad += 1
		if int(q["correct"]) == 0:
			at_zero += 1
	check("shuffle: correct answer preserved x400", bad == 0, str(bad))
	check("shuffle: correct not stuck at index 0", at_zero < 160, str(at_zero))


func test_arith_gen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var bad := 0
	var neg := 0
	for lv in range(1, 11):
		for i in 1000:
			var p := ArithGen.make(lv, rng)
			if not ArithGen.check(p):
				bad += 1
			if int(p["answer"]) < 0:
				neg += 1
	check("math: 10000 problems correct", bad == 0, str(bad))
	check("math: no negative answers", neg == 0, str(neg))
	check("math: level 1 only addition", ArithGen.make(1, rng)["op"] == "+")


func test_flags_match_countries() -> void:
	var f = JSON.parse_string(FileAccess.get_file_as_string("res://content/knowledge/flags.json"))
	var ids := {}
	for line in FileAccess.get_file_as_string("res://content/knowledge/countries.tsv").split("\n"):
		var cols: PackedStringArray = line.split("\t")
		if cols.size() >= 4 and cols[0] != "id":
			ids[cols[0]] = true
	check("geo: countries >= 130", ids.size() >= 130, str(ids.size()))
	var missing := []
	for spec in f["flags"]:
		if not ids.has(spec["id"]):
			missing.append(spec["id"])
	check("geo: every flag has a country", missing.is_empty(), str(missing))


func test_review_gate() -> void:
	var items := [{"id": "a", "status": "ai_drafted"}, {"id": "b", "status": "verified"}, {"id": "c", "status": "ai_drafted"}, {"id": "d", "status": "flagged"}]
	var r := ContentLab.release_report(items, {"a": {"verdict": "ok"}, "c": {"verdict": "flag"}})
	check("review: counts verified", int(r["verified"]) == 2, str(r))
	check("review: counts flagged", int(r["flagged"]) == 2, str(r))
	check("review: pending 0", int(r["pending"]) == 0, str(r))


func test_knowledge_catalog() -> void:
	for id in ["quiz", "geo", "math"]:
		var g := Catalog.get_game(id)
		check("catalog: %s present" % id, not g.is_empty())
		if not g.is_empty():
			check("catalog: %s scene exists" % id, ResourceLoader.exists(str(g["scene"])))


# ---------------- Phase 9: meta systems ----------------
func test_prev_day() -> void:
	check("date: prev of 20261019", ProgressModel.prev_day(20261019) == 20261018)
	check("date: month boundary", ProgressModel.prev_day(20261101) == 20261031)
	check("date: year boundary", ProgressModel.prev_day(20270101) == 20261231)
	check("date: leap day", ProgressModel.prev_day(20280301) == 20280229)


func test_daily_streak() -> void:
	var p := ProgressModel.new({})
	p.claim_daily(20261018, 1, 1)
	p.claim_daily(20261019, 1, 1)
	p.claim_daily(20261020, 1, 1)
	check("streak: 3 consecutive days", int(p.d["daily_streak"]) == 3)
	check("streak: current on same day", p.current_streak(20261020) == 3)
	check("streak: still alive next day", p.current_streak(20261021) == 3)
	check("streak: broken after a gap", p.current_streak(20261023) == 0)
	p.claim_daily(20261023, 1, 1)
	check("streak: restarts at 1", int(p.d["daily_streak"]) == 1)
	check("streak: best kept", int(p.d["daily_streak_best"]) == 3)
	check("streak: total counted", int(p.d["daily_total"]) == 4)


func test_daily_challenge_deterministic() -> void:
	var a := Daily.challenge_for(20261019, Catalog.games)
	var b := Daily.challenge_for(20261019, Catalog.games)
	check("daily: same date same challenge", a == b and not a.is_empty(), str(a))
	var g := Catalog.get_game(str(a.get("game", "")))
	check("daily: game exists, level in range", not g.is_empty() and int(a["level"]) >= 1 and int(a["level"]) <= int(g["levels"]))
	var different := 0
	for i in 14:
		if Daily.challenge_for(20261101 + i, Catalog.games) != a:
			different += 1
	check("daily: varies across days", different >= 10, str(different))
	check("daily: streak bonus capped", int(Daily.reward(50)["coins"]) == Daily.BASE_COINS + Daily.STREAK_BONUS * Daily.STREAK_CAP)


func test_achievements() -> void:
	var p := ProgressModel.new({})
	var gw := {"quiz": "knowledge", "sokoban": "puzzles", "dodge": "speed", "gears": "build"}
	check("ach: none on empty save", Achievements.evaluate(p, gw).is_empty())
	p.report_result("quiz", 1, 3, 10, 10, 1)
	var got := Achievements.evaluate(p, gw)
	var ids := []
	for a in got:
		ids.append(a["id"])
	check("ach: first_win unlocked", "first_win" in ids, str(ids))
	check("ach: never twice", Achievements.evaluate(p, gw).is_empty())
	for g in ["sokoban", "dodge", "gears"]:
		p.report_result(g, 1, 1, 1, 10, 1)
	ids.clear()
	for a in Achievements.evaluate(p, gw):
		ids.append(a["id"])
	check("ach: all_worlds unlocked", "all_worlds" in ids, str(ids))
	var defs_ok := true
	for a in Achievements.defs():
		var pr := Achievements.progress_of(a, p, gw)
		if pr.size() != 2 or int(pr[1]) <= 0:
			defs_ok = false
	check("ach: every definition evaluable", defs_ok and Achievements.defs().size() >= 20, str(Achievements.defs().size()))


func test_store() -> void:
	var p := ProgressModel.new({"coins": 100})
	var prof := {}
	var hex := Store.get_item("av_hex_gold")
	check("store: item found", not hex.is_empty())
	check("store: buy ok", Store.buy(p, hex) and p.coins() == 40, str(p.coins()))
	check("store: no double charge", not Store.buy(p, hex) and p.coins() == 40)
	var star := Store.get_item("av_star_gold")
	check("store: too poor", Store.state(p, star) == "poor" and not Store.buy(p, star))
	var orbit := Store.get_item("av_orbit")
	check("store: locked without achievement", Store.state(p, orbit) == "locked" and not Store.buy(p, orbit))
	p.grant("ach:all_worlds")
	check("store: unlocked after achievement, free", Store.buy(p, orbit) and p.coins() == 40)
	check("store: equip owned", Store.equip(p, prof, hex) and Store.equipped(p, prof, "avatar")["id"] == "av_hex_gold")
	check("store: cannot equip unowned", not Store.equip(p, prof, star))
	check("store: default for every kind", not Store.default_for("avatar").is_empty() and not Store.default_for("ring").is_empty() and not Store.default_for("burst").is_empty())
	var all_ok := true
	for it in Store.items():
		if not (it["kind"] in Store.KINDS) or not it.has("color"):
			all_ok = false
		if it.has("requires"):
			var found := false
			for a in Achievements.defs():
				if a["id"] == it["requires"]:
					found = true
			all_ok = all_ok and found
	check("store: items valid, requirements exist", all_ok)


func test_save_transfer() -> void:
	var data := SaveStore.fresh_data()
	data["progress"] = {"xp": 500, "coins": 77, "name": "مدار"}
	var text := SaveTransfer.encode(data)
	var back := SaveTransfer.decode(text)
	check("transfer: roundtrip ok", bool(back["ok"]) and int(back["data"]["progress"]["coins"]) == 77)
	check("transfer: survives line breaks", bool(SaveTransfer.decode(text.insert(20, "\n  "))["ok"]))
	var broken := text.substr(0, text.length() - 30) + text.right(20)
	check("transfer: truncated rejected", not bool(SaveTransfer.decode(broken)["ok"]))
	check("transfer: garbage rejected", not bool(SaveTransfer.decode("hello")["ok"]))
	var future := SaveStore.fresh_data()
	future["schema"] = 99
	check("transfer: newer schema rejected", not bool(SaveTransfer.decode(SaveTransfer.encode(future))["ok"]))
	check("transfer: summary readable", SaveTransfer.summary(back["data"]).find("عملة") != -1)



# ---------------- Phase 10: performance and size ----------------
func test_font_fallbacks() -> void:
	check("fonts: body has Latin fallback", Tokens.font_body.fallbacks.size() >= 1)
	check("fonts: bold has Latin fallback", Tokens.font_bold.fallbacks.size() >= 1)
	check("fonts: display falls back to Arabic + Latin", Tokens.font_display.fallbacks.size() >= 2)
	var latin: Font = Tokens.font_latin
	var ok := true
	for ch in "AZaz09+-×÷°²₂%XP":
		if not latin.has_char(ch.unicode_at(0)):
			ok = false
	check("fonts: Latin subset covers symbols used", ok)


func test_quality_tiers() -> void:
	var old_q = Settings.get_value("quality")
	Settings.set_value("quality", "low")
	check("quality: low freezes background", Quality.bg_motion() == 0.0)
	check("quality: low particles 30%", is_equal_approx(Quality.particle_scale(), 0.3))
	Settings.set_value("quality", "balanced")
	check("quality: balanced particles 60%", is_equal_approx(Quality.particle_scale(), 0.6))
	Settings.set_value("quality", "high")
	check("quality: high full", is_equal_approx(Quality.particle_scale(), 1.0) and Quality.bg_motion() == (0.0 if bool(Settings.get_value("reduce_motion")) else 1.0))
	var p := UiKit.burst(self, Vector2(-100, -100), Color.WHITE, 60)
	check("quality: burst respects scale", p.amount == 60)
	p.queue_free()
	Settings.set_value("quality", old_q)


func test_dot_texture_cached() -> void:
	check("perf: particle texture shared", UiKit.dot_texture() == UiKit.dot_texture())


# ---------------- v0.12 fixes ----------------
func test_daily_wrong_future_date_recovers() -> void:
	var p := ProgressModel.new({})
	p.observe_date(20301231)   # phone once showed a wrong far-future date
	check("daily: wrong future date does not lock forever", p.daily_status(20261019) == "available")
	p.claim_daily(20261019, 1, 1)
	check("daily: rollback before last claim still blocked", p.daily_status(20261018) == "clock_rollback")


func test_replay_xp_capped() -> void:
	var p := ProgressModel.new({})
	p.report_result("g", 1, 1, 0, 40, 1)
	var paid := 0
	for i in 8:
		paid += int(p.report_result("g", 1, 1, 0, 40, 1)["xp"])
	check("result: replay xp capped at %d replays" % ProgressModel.REPLAY_XP_MAX, paid == 10 * ProgressModel.REPLAY_XP_MAX, str(paid))


func test_transfer_rejects_bad_types() -> void:
	var data := SaveStore.fresh_data()
	data["progress"] = {"ledger": "oops", "xp": 5}
	check("transfer: wrong types rejected", not bool(SaveTransfer.decode(SaveTransfer.encode(data))["ok"]))
	data["progress"] = {"levels": {"g:1": 3}}
	check("transfer: broken level record rejected", not bool(SaveTransfer.decode(SaveTransfer.encode(data))["ok"]))


func _levels_of(path: String) -> Array:
	var p = JSON.parse_string(FileAccess.get_file_as_string(path))
	return p["levels"] if p is Dictionary and p.has("levels") else []


func test_puzzle_level_data() -> void:
	var sok := _levels_of("res://content/sokoban_levels.json")
	var sok_ok := sok.size() >= int(Catalog.get_game("sokoban").get("levels", 99))
	for lv in sok:
		var b := 0
		var g := 0
		for row in lv["map"]:
			for ch in str(row):
				if ch == "$" or ch == "*":
					b += 1
				if ch == "." or ch == "*" or ch == "+":
					g += 1
		sok_ok = sok_ok and b == g and b > 0 and int(lv.get("par", 0)) > 0
	check("sokoban: boxes == goals, par set, enough levels", sok_ok)
	var pipes := _levels_of("res://content/pipes/levels.json")
	var pipes_ok := pipes.size() >= int(Catalog.get_game("pipes").get("levels", 99))
	for lv in pipes:
		var n := int(lv["size"])
		pipes_ok = pipes_ok and lv["layout"].size() == n and lv["start"].size() == n and lv["solution"].size() == n and int(lv["par"]) > 0
	check("pipes: grids complete, par set, enough levels", pipes_ok)
	var ms := _levels_of("res://content/matchsticks/levels.json")
	var ms_ok := ms.size() >= int(Catalog.get_game("matchsticks").get("levels", 99))
	for lv in ms:
		ms_ok = ms_ok and (lv["solution"] as Array).size() == int(lv["move"]) and int(lv["target"]) > 0
	check("matchsticks: solution length == moves, enough levels", ms_ok)


func test_quiz_all_counts_categories() -> void:
	var p := ProgressModel.new({})
	var a := {}
	for d in Achievements.defs():
		if d["id"] == "quiz_all":
			a = d
	for lvl in [1, 8, 15, 2]:   # levels 8 and 15 repeat category 1
		p.report_result("quiz", lvl, 1, 0, 10, 1)
	check("ach: quiz_all counts the 7 categories, not any 7 levels", not a.is_empty() and int(Achievements.progress_of(a, p, {})[0]) == 2)


# ---------------- v0.14 hard games ----------------
func test_hard_games_data() -> void:
	for id in ["crypt", "rush", "nback", "laser"]:
		check("catalog: %s present" % id, not Catalog.get_game(id).is_empty())
	var rush := _levels_of("res://content/rush/levels.json")
	var rush_ok := rush.size() >= 8
	for lv in rush:
		rush_ok = rush_ok and int(lv["par"]) > 0 and (lv["cars"] as Array).size() > 1 and int(lv["cars"][0]["y"]) == 2 and bool(lv["cars"][0]["h"])
	check("rush: 8 levels, red car on exit row, par set", rush_ok)
	var crypt := _levels_of("res://content/crypt/levels.json")
	var crypt_ok := crypt.size() >= 8
	for lv in crypt:
		var s: Dictionary = lv["solution"]
		var vals := []
		for w in [str(lv["a"]), str(lv["b"]), str(lv["c"])]:
			var v := 0
			for ch in w:
				v = v * 10 + int(s.get(ch, -100))
			vals.append(v)
		crypt_ok = crypt_ok and int(vals[0]) + int(vals[1]) == int(vals[2])
	check("crypt: stored solutions add up", crypt_ok)
	var laser := _levels_of("res://content/laser/levels.json")
	var laser_ok := laser.size() >= 8
	for lv in laser:
		laser_ok = laser_ok and int(lv["par"]) > 0 and (lv["targets"] as Array).size() > 0
	check("laser: 8 levels with targets and par", laser_ok)


# ---------------- v0.16 ----------------
func test_catalog_howto_and_hard() -> void:
	var all_have := true
	var hard := 0
	for g in Catalog.games:
		if str(g.get("howto", "")) == "":
			all_have = false
		if bool(g.get("hard", false)):
			hard += 1
	check("catalog: every game has a how-to text", all_have)
	check("catalog: 4 hard games flagged", hard == 4, str(hard))
	var masters := 0
	for a in Achievements.defs():
		if str(a["id"]).ends_with("_master"):
			masters += 1
	check("ach: one master achievement per hard game", masters == 4, str(masters))


func test_icons_render() -> void:
	var ok := true
	for k in Icons.SVG:
		if Icons.tex(str(k), 32) == null:
			ok = false
	check("icons: every icon renders from SVG", ok and Icons.SVG.size() >= 20)


# ---------------- v0.17 batch 1: maze + escape ----------------
func test_batch1_catalog_scenes() -> void:
	for id in ["maze", "escape"]:
		var g := Catalog.get_game(id)
		check("catalog: %s present in puzzles" % id, not g.is_empty() and str(g.get("world", "")) == "puzzles")
		if g.is_empty():
			continue
		var packed := load(str(g["scene"])) as PackedScene
		var inst: Node = packed.instantiate() if packed else null
		check("%s: scene instantiates a MiniGame" % id, inst is MiniGame)
		if inst:
			inst.free()


func test_maze_levels() -> void:
	var lv := _levels_of("res://content/maze/levels.json")
	var want := int(Catalog.get_game("maze").get("levels", -1))
	check("maze: 15 levels, matches catalog", lv.size() == 15 and lv.size() == want, "%d / %d" % [lv.size(), want])
	if lv.is_empty():
		return
	check("maze: sizes grow 5x5 -> 15x15", int(lv[0]["size"]) == 5 and int(lv[-1]["size"]) == 15)
	var bad := []
	var prev := 0
	var growing := true
	for rec in lv:
		var n := int(rec["size"])
		var rows: Array = rec["cells"]
		var ok := rows.size() == n
		for y in n:
			ok = ok and str(rows[y]).length() == n
		if ok:
			for y in n:
				for x in n:
					var m := str(rows[y])[x].hex_to_int()
					if (x == 0 and (m & 8) != 0) or (x == n - 1 and (m & 2) != 0) or (y == 0 and (m & 1) != 0) or (y == n - 1 and (m & 4) != 0):
						ok = false   # opening through the outer wall
					if x < n - 1 and bool(m & 2) != bool(str(rows[y])[x + 1].hex_to_int() & 8):
						ok = false   # one-way wall
					if y < n - 1 and bool(m & 4) != bool(str(rows[y + 1])[x].hex_to_int() & 1):
						ok = false
		var s := Vector2i(int(rec["start"][0]), int(rec["start"][1]))
		var e := Vector2i(int(rec["exit"][0]), int(rec["exit"][1]))
		var steps: int = MazeScript.bfs_steps(rows, s, e) if ok else -1
		if not ok or steps <= 0 or steps != int(rec["par"]):
			bad.append("%s (bfs %d par %s)" % [rec["id"], steps, rec["par"]])
		growing = growing and steps > prev
		prev = steps
	check("maze: every level solvable by BFS, par = shortest path", bad.is_empty(), str(bad))
	check("maze: shortest path grows every level", growing)


func test_escape_rooms() -> void:
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/escape/levels.json"))
	var rooms: Array = p["rooms"] if p is Dictionary and p.has("rooms") else []
	var want := int(Catalog.get_game("escape").get("levels", -1))
	check("escape: 6 rooms, matches catalog", rooms.size() == 6 and rooms.size() == want, "%d / %d" % [rooms.size(), want])
	var unsolvable := []
	var wrong_answers := []
	var counts := []
	var hint_gaps := []
	for rm in rooms:
		if not EscapeScript.simulate(rm):
			unsolvable.append(rm["id"])
		var puzzles := 0
		var ids := {}
		for o in rm["objects"]:
			ids[o["id"]] = true
			var a: Dictionary = o["action"]
			var t := str(a["type"])
			if t != "look":
				puzzles += 1
			if t == "code" or t == "symbols":
				var got: String = EscapeScript.derive_answer(rm, a)
				var stored := str(a["answer"]) if t == "code" else ",".join(PackedStringArray(a["answer"]))
				if got != stored:
					wrong_answers.append("%s/%s: %s != %s" % [rm["id"], o["id"], got, stored])
		counts.append(puzzles)
		if puzzles < 3 or puzzles > 4:
			hint_gaps.append("%s: %d puzzles" % [rm["id"], puzzles])
		for h in rm["hints"]:
			if not ids.has(h["until"]):
				hint_gaps.append("%s: hint for missing %s" % [rm["id"], h["until"]])
	check("escape: every room can be escaped with its own clues", unsolvable.is_empty(), str(unsolvable))
	check("escape: code/symbol answers match the clues in the room", wrong_answers.is_empty(), str(wrong_answers))
	check("escape: 3-4 puzzles per room, hints point at real objects", hint_gaps.is_empty(), str(counts) + " " + str(hint_gaps))
	check("escape: hint has a price", p is Dictionary and int(p.get("hint_cost", 0)) > 0)


func test_batch1_stars_saved() -> void:
	var p := ProgressModel.new({})   # in-memory model: the real save is never touched
	p.report_result("maze", 3, MazeScript.stars_for(21, 21), 900, 60, 8)
	check("maze: shortest run = 3 stars, saved", p.stars_for("maze", 3) == 3)
	check("maze: long detour = 1 star", MazeScript.stars_for(200, 21) == 1)
	check("maze: small detour = 2 stars", MazeScript.stars_for(40, 21) == 2)
	p.report_result("escape", 2, EscapeScript.stars_for(0), 1000, 80, 10)
	check("escape: no mistakes = 3 stars, saved", p.stars_for("escape", 2) == 3)
	p.report_result("escape", 2, EscapeScript.stars_for(9), 100, 80, 10)
	check("escape: worse replay keeps 3 stars", p.stars_for("escape", 2) == 3 and EscapeScript.stars_for(9) == 1)


# ---------------- v0.18 batch 2: lightning + hunter ----------------
func test_batch2_catalog_scenes() -> void:
	for id in ["lightning", "hunter"]:
		var g := Catalog.get_game(id)
		check("catalog: %s present in speed" % id, not g.is_empty() and str(g.get("world", "")) == "speed" and not bool(g.get("dev_only", true)))
		if g.is_empty():
			continue
		var packed := load(str(g["scene"])) as PackedScene
		var inst: Node = packed.instantiate() if packed else null
		check("%s: scene instantiates a MiniGame" % id, inst is MiniGame)
		if inst:
			inst.free()
	var demo := Catalog.get_game("demo_tap")
	check("catalog: demo_tap still hidden (dev only)", demo.is_empty() or bool(demo.get("dev_only", false)))


func test_lcg_matches_python() -> void:
	# First values of the shared RNG for seed 1 (also printed by Python: Lcg(1).next() x3).
	var r = LightningScript.Lcg.new(1)
	var a: float = r.next()
	var b: float = r.next()
	check("rng: deterministic", is_equal_approx(a, 1103527590 / 2147483648.0) and b != a, "%f %f" % [a, b])
	var h = HunterScript.Lcg.new(1)
	check("rng: same in both games", is_equal_approx(h.next(), a))


func test_lightning_levels() -> void:
	var lv := _levels_of("res://content/lightning/levels.json")
	var want := int(Catalog.get_game("lightning").get("levels", -1))
	check("lightning: 8 levels, matches catalog", lv.size() == 8 and lv.size() == want, "%d / %d" % [lv.size(), want])
	var fp_bad := []
	var rule_bad := []
	var modes := {}
	for rec in lv:
		modes[str(rec["mode"]) + "/" + str(rec["decoy"]) + ("/move" if float(rec["move"]) > 0.0 else "")] = true
		var fp: int = LightningScript.fingerprint(rec, FP_SEED)
		if fp != int(rec["fingerprint"]):
			fp_bad.append("%s: %d != %d" % [rec["id"], fp, int(rec["fingerprint"])])
		if not (int(rec["rounds"]) == 10 and int(rec["t3"]) < int(rec["t2"]) and float(rec["dmin"]) < float(rec["dmax"])):
			rule_bad.append(rec["id"])
		var r = LightningScript.Lcg.new(7)
		for i in 30:
			var p: Dictionary = LightningScript.plan_round(r, rec)
			var d := float(p["delay"])
			if d < float(rec["dmin"]) or d > float(rec["dmax"]):
				rule_bad.append("%s delay" % rec["id"])
			var last := -10.0
			for dc in p["decoys"]:
				var t := float(dc["t"])
				if t < 0.3 or t - last < 0.45 or d - t < 0.45:
					rule_bad.append("%s decoy" % rec["id"])
				last = t
	check("lightning: GDScript rounds == verified Python rounds (fingerprint)", fp_bad.is_empty(), str(fp_bad))
	check("lightning: 10 rounds, delays and decoys within rules", rule_bad.is_empty(), str(rule_bad))
	check("lightning: at least 5 different level types", modes.size() >= 5, str(modes.keys()))


func test_hunter_levels() -> void:
	var lv := _levels_of("res://content/hunter/levels.json")
	var want := int(Catalog.get_game("hunter").get("levels", -1))
	check("hunter: 8 levels, matches catalog", lv.size() == 8 and lv.size() == want, "%d / %d" % [lv.size(), want])
	var fp_bad := []
	var bad := []
	var prev_speed := 0.0
	var prev_count := 0
	for rec in lv:
		var fp: int = HunterScript.fingerprint(rec, FP_SEED)
		if fp != int(rec["fingerprint"]):
			fp_bad.append("%s: %d != %d" % [rec["id"], fp, int(rec["fingerprint"])])
		var gl: Array = rec["goals"]
		if not (int(gl[0]) < int(gl[1]) and int(gl[1]) < int(gl[2]) and int(gl[2]) <= int(rec["goods"])):
			bad.append("%s goals" % rec["id"])
		if float(rec["smax"]) < prev_speed or int(rec["count"]) <= prev_count:
			bad.append("%s not harder" % rec["id"])
		prev_speed = float(rec["smax"])
		prev_count = int(rec["count"])
		for seed_v in [1, 99, 12345]:
			var plan: Array = HunterScript.make_plan(rec, seed_v)
			var goods := 0
			var last_t := 0.0
			for sp in plan:
				if bool(sp["good"]):
					goods += 1
				if float(sp["t"]) < last_t or float(sp["t"]) > float(rec["duration"]):
					bad.append("%s spawn order" % rec["id"])
				last_t = float(sp["t"])
			if plan.size() != int(rec["count"]) or goods != int(rec["goods"]):
				bad.append("%s counts seed %d" % [rec["id"], seed_v])
	check("hunter: GDScript spawns == verified Python spawns (fingerprint)", fp_bad.is_empty(), str(fp_bad))
	check("hunter: goals ordered, each level harder, fixed target counts", bad.is_empty(), str(bad))


func test_batch2_stars_saved() -> void:
	var lv := _levels_of("res://content/lightning/levels.json")
	if lv.is_empty():
		check("lightning: levels for star test", false)
		return
	var l1: Dictionary = lv[0]
	check("lightning: fast avg = 3 stars", LightningScript.stars_for(float(l1["t3"]) - 1.0, 0, l1) == 3)
	check("lightning: slow avg = 1 star", LightningScript.stars_for(float(l1["t2"]) + 200.0, 0, l1) == 1)
	check("lightning: 3 mistakes drop a star", LightningScript.stars_for(float(l1["t3"]) - 1.0, 3, l1) == 2)
	check("lightning: 6 mistakes = loss", LightningScript.stars_for(100.0, 6, l1) == 0)
	var hl := _levels_of("res://content/hunter/levels.json")
	var gl: Array = hl[0]["goals"] if not hl.is_empty() else [1, 2, 3]
	check("hunter: goals -> 0..3 stars", HunterScript.stars_for(int(gl[0]) - 1, gl) == 0 and HunterScript.stars_for(int(gl[2]), gl) == 3)
	var p := ProgressModel.new({})   # in-memory: the real save is never touched
	p.report_result("lightning", 1, LightningScript.stars_for(200.0, 0, l1), 1600, 60, 8)
	p.report_result("hunter", 1, HunterScript.stars_for(int(gl[1]), gl), 300, 65, 8)
	check("batch2: stars saved per game", p.stars_for("lightning", 1) == 3 and p.stars_for("hunter", 1) == 2)


# ---------------- v0.19 batch 3: knowledge + build ----------------
func test_batch3_catalog_scenes() -> void:
	for id in ["guess_picture", "bridge", "pipe_cost", "packing", "physics_lab"]:
		var g := Catalog.get_game(id)
		var world := "knowledge" if id == "guess_picture" else "build"
		check("catalog: %s present in %s" % [id, world], not g.is_empty() and str(g.get("world", "")) == world)
		if g.is_empty():
			continue
		var packed := load(str(g["scene"])) as PackedScene
		var inst: Node = packed.instantiate() if packed else null
		check("%s: scene instantiates a MiniGame" % id, inst is MiniGame)
		if inst:
			inst.free()


func test_guess_picture_content() -> void:
	var p = JSON.parse_string(FileAccess.get_file_as_string("res://content/guess_picture/items.json"))
	var l = JSON.parse_string(FileAccess.get_file_as_string("res://content/guess_picture/levels.json"))
	var items: Array = p["items"] if p is Dictionary else []
	check("guess: >= 150 items", items.size() >= 150, str(items.size()))
	var ids := {}
	var names := {}
	var svg_bad := []
	var flag_bad := []
	var flags := {}
	var f = JSON.parse_string(FileAccess.get_file_as_string("res://content/knowledge/flags.json"))
	for sp in f["flags"]:
		flags[sp["id"]] = true
	for it in items:
		ids[it["id"]] = true
		names[str(it["name"])] = true
		if it.has("svg"):
			if GuessScript.svg_texture(str(it["svg"]), 64) == null:
				svg_bad.append(it["id"])
		elif it.has("flag") and not flags.has(str(it["flag"])):
			flag_bad.append(it["id"])
	check("guess: ids and names unique", ids.size() == items.size() and names.size() == items.size(), "%d/%d/%d" % [ids.size(), names.size(), items.size()])
	check("guess: every picture renders in Godot (SVG)", svg_bad.is_empty(), str(svg_bad))
	check("guess: every flag reference exists", flag_bad.is_empty(), str(flag_bad))
	var levels: Array = l["levels"] if l is Dictionary else []
	check("guess: 10 levels, matches catalog", levels.size() == 10 and int(Catalog.get_game("guess_picture").get("levels", -1)) == 10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var pool_bad := []
	for lvl in levels:
		var pool: Array = GuessScript.build_pool(items, lvl["cats"], l["questions"], rng)
		if pool.size() < 10:
			pool_bad.append("%s size" % lvl["id"])
		for q in pool:
			var ans: Array = q["answers"]
			var uniq := {}
			for a in ans:
				uniq[str(a)] = true
			if ans.size() != 4 or uniq.size() != 4 or str(ans[int(q["correct"])]) != str(q["item"]["name"]):
				pool_bad.append(str(q["id"]))
	check("guess: every level has >= 10 questions, 4 different answers, right one correct", pool_bad.is_empty(), str(pool_bad.slice(0, 5)))


func test_packing_levels() -> void:
	var lv := _levels_of("res://content/packing/levels.json")
	check("packing: 10 levels, matches catalog", lv.size() == 10 and int(Catalog.get_game("packing").get("levels", -1)) == 10)
	var bad := []
	for rec in lv:
		var w := int(rec["w"])
		var h := int(rec["h"])
		var holes := {}
		for hp in rec["holes"]:
			holes[Vector2i(int(hp[0]), int(hp[1]))] = true
		var seen := {}
		var ok := int(rec["solutions"]) >= 1
		var used := {}
		for s in rec["solution"]:
			used[int(s[0])] = true
			for c in rec["pieces"][int(s[0])]:
				var cell := Vector2i(int(c[0]) + int(s[1]), int(c[1]) + int(s[2]))
				if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h or holes.has(cell) or seen.has(cell):
					ok = false
				seen[cell] = true
		ok = ok and used.size() == (rec["pieces"] as Array).size() and seen.size() == w * h - holes.size()
		if not ok:
			bad.append(rec["id"])
	check("packing: stored solution fills every board exactly, no overlap", bad.is_empty(), str(bad))
	check("packing: stars by hints and pick-ups", PackingScript.stars_for(0, 0) == 3 and PackingScript.stars_for(1, 3) == 2 and PackingScript.stars_for(3, 0) == 1)


func test_pipe_cost_levels() -> void:
	var lv := _levels_of("res://content/pipe_cost/levels.json")
	check("pipe_cost: 6 levels, matches catalog", lv.size() == 6 and int(Catalog.get_game("pipe_cost").get("levels", -1)) == 6)
	var bad := []
	for rec in lv:
		var rows: Array = rec["grid"]
		var opt: int = PipeCostScript.steiner_cost(rows)
		var pipes := {}
		var c := 0
		for p in rec["solution"]:
			var cell := Vector2i(int(p[0]), int(p[1]))
			pipes[cell] = true
			c += PipeCostScript.cell_cost(rows, cell)
		# flood from the source through pipes and houses
		var src := Vector2i(-1, -1)
		var houses := []
		for y in rows.size():
			for x in rows.size():
				var ch := str(rows[y])[x]
				if ch == "S":
					src = Vector2i(x, y)
				elif ch in ["A", "B", "C", "D"]:
					houses.append(Vector2i(x, y))
		var wet := {src: true}
		var st: Array = [src]
		while not st.is_empty():
			var q: Vector2i = st.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nq: Vector2i = q + d
				if not wet.has(nq) and (pipes.has(nq) or nq in houses):
					wet[nq] = true
					st.append(nq)
		var all_wet := true
		for hs in houses:
			all_wet = all_wet and wet.has(hs)
		if opt != int(rec["optimal"]) or c != opt or not all_wet:
			bad.append("%s: dp %d stored %d solution %d connected %s" % [rec["id"], opt, int(rec["optimal"]), c, all_wet])
	check("pipe_cost: exact optimum re-solved in Godot == stored, stored network reaches it", bad.is_empty(), str(bad))
	check("pipe_cost: stars by cost", PipeCostScript.stars_for(10, 10) == 3 and PipeCostScript.stars_for(12, 10) == 2 and PipeCostScript.stars_for(20, 10) == 1)


func test_physics_lab_levels() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://content/physics_lab/levels.json"))
	var lv: Array = data["levels"] if data is Dictionary else []
	check("physics_lab: 6 levels, matches catalog", lv.size() == 6 and int(Catalog.get_game("physics_lab").get("levels", -1)) == 6)
	var kinds := {}
	var bad := []
	for rec in lv:
		kinds[rec["kind"]] = true
		if PhysicsLabScript.run(data, rec, rec["solution"]) != 1:
			bad.append("%s solution" % rec["id"])
		if PhysicsLabScript.run(data, rec, PhysicsLabScript.start_choice(rec)) != -1:
			bad.append("%s start wins" % rec["id"])
	check("physics_lab: 6 different challenge types", kinds.size() == 6, str(kinds.keys()))
	check("physics_lab: Godot simulation: stored solution wins, start setting fails", bad.is_empty(), str(bad))


func test_bridge_levels() -> void:
	var lv := _levels_of("res://content/bridge/levels.json")
	check("bridge: 6 levels, matches catalog", lv.size() == 6 and int(Catalog.get_game("bridge").get("levels", -1)) == 6)
	var bad := []
	for rec in lv:
		var best: Array = rec["best"]
		var c := 0
		for b in best:
			c += BridgeScript.beam_cost(rec, int(b[0]), int(b[1]))
			if not BridgeScript.valid_beam(rec, int(b[0]), int(b[1])):
				bad.append("%s invalid beam" % rec["id"])
		if c != int(rec["best_cost"]) or c > int(rec["budget"]):
			bad.append("%s cost %d" % [rec["id"], c])
		if BridgeScript.run(rec, best, 1.0) != 1 or BridgeScript.run(rec, best, 1.2) != 1:
			bad.append("%s best design fails" % rec["id"])
		if BridgeScript.run(rec, rec["road"], 1.0) != -1:
			bad.append("%s road alone holds" % rec["id"])
	check("bridge: Godot physics: best design carries the car (+20%), road alone breaks", bad.is_empty(), str(bad))
	check("bridge: stars by cost", BridgeScript.stars_for(100, 100) == 3 and BridgeScript.stars_for(125, 100) == 2 and BridgeScript.stars_for(200, 100) == 1)


func test_batch3_stars_saved() -> void:
	var p := ProgressModel.new({})   # in-memory: the real save is never touched
	p.report_result("bridge", 2, BridgeScript.stars_for(130, 130), 1000, 85, 10)
	p.report_result("pipe_cost", 1, PipeCostScript.stars_for(10, 10), 1000, 80, 10)
	p.report_result("packing", 4, PackingScript.stars_for(0, 1), 1000, 75, 9)
	p.report_result("physics_lab", 3, PhysicsLabScript.stars_for(3), 700, 80, 10)
	p.report_result("guess_picture", 1, 2, 800, 60, 8)
	check("batch3: stars saved per game", p.stars_for("bridge", 2) == 3 and p.stars_for("pipe_cost", 1) == 3 and p.stars_for("packing", 4) == 3 and p.stars_for("physics_lab", 3) == 2 and p.stars_for("guess_picture", 1) == 2)
