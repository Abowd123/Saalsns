extends Node
## Autoload "Progress": ProgressModel bound to the save file, plus change signals for UI.

signal changed
signal leveled_up(new_level: int)

var model: ProgressModel


func _ready() -> void:
	model = ProgressModel.new(SaveService.section("progress"))
	model.observe_date(today_key())
	SaveService.mark_dirty()


func rebind() -> void:
	model = ProgressModel.new(SaveService.section("progress"))
	model.observe_date(today_key())
	changed.emit()


func game_world_map() -> Dictionary:
	var out := {}
	for g in Catalog.games:
		out[g["id"]] = g["world"]
	return out


## Grants newly satisfied achievements, saves, and returns them.
func check_achievements() -> Array:
	var got := Achievements.evaluate(model, game_world_map())
	if not got.is_empty():
		SaveService.save_now()
		for a in got:
			Log.info("achievement " + str(a["id"]))
		changed.emit()
	return got


## Today's challenge. The level is capped at the player's highest unlocked level (no
## skipping ahead), and fixed for the day once chosen so it does not shift after playing.
func today_challenge() -> Dictionary:
	var day := today_key()
	var ch := Daily.challenge_for(day, Catalog.games)
	if ch.is_empty():
		return ch
	var pick: Dictionary = model.d.get("daily_pick", {})
	if int(pick.get("day", 0)) == day and str(pick.get("game", "")) == str(ch["game"]):
		ch["level"] = int(pick["level"])
		return ch
	var g := Catalog.get_game(str(ch["game"]))
	ch["level"] = mini(int(ch["level"]), model.resume_level(str(ch["game"]), int(g.get("levels", 1))))
	model.d["daily_pick"] = {"day": day, "game": ch["game"], "level": ch["level"]}
	SaveService.mark_dirty()
	return ch


## Called by GameHost after a daily run. Returns {} if not claimed.
func try_claim_daily(stars: int) -> Dictionary:
	var ch := today_challenge()
	var day := today_key()
	if ch.is_empty() or stars < int(ch["target_stars"]) or model.daily_status(day) != "available":
		return {}
	var streak_after: int = model.current_streak(day) + 1 if int(model.d["daily_last"]) == ProgressModel.prev_day(day) else 1
	var rw := Daily.reward(streak_after)
	var level_before := model.level()
	if not model.claim_daily(day, int(rw["xp"]), int(rw["coins"])):
		return {}
	SaveService.save_now()
	changed.emit()
	if model.level() > level_before:
		leveled_up.emit(model.level())
	return {"xp": rw["xp"], "coins": rw["coins"], "streak": int(model.d["daily_streak"])}


func buy(item: Dictionary) -> bool:
	var ok := Store.buy(model, item)
	if ok:
		SaveService.save_now()
		changed.emit()
	return ok


func today_key() -> int:
	return ProgressModel.date_key(Time.get_date_dict_from_system())


func report_result(game_id: String, level_id: int, stars: int, score: int, base_xp: int, coins_per_star: int) -> Dictionary:
	var r := model.report_result(game_id, level_id, stars, score, base_xp, coins_per_star)
	r["achievements"] = Achievements.evaluate(model, game_world_map())
	r["level_after"] = model.level()
	SaveService.save_now()   # results are saved immediately, not debounced
	Log.info("result %s:%d stars=%d score=%d xp+%d coins+%d" % [game_id, level_id, stars, score, r["xp"], r["coins"]])
	changed.emit()
	if r["level_after"] > r["level_before"]:
		leveled_up.emit(r["level_after"])
	return r


func spend(amount: int) -> bool:
	var ok := model.spend(amount)
	if ok:
		SaveService.save_now()
		changed.emit()
	return ok
