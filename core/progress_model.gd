class_name ProgressModel
extends RefCounted
## Pure progression logic over a Dictionary (the "progress" save section).
## Every reward goes through grant(): a key can be granted ONCE, ever.

const REPLAY_XP_FACTOR := 0.25
const REPLAY_XP_MAX := 5   # paid replays per level; after that replays give no XP (no grinding)
const HISTORY_MAX := 50

var d: Dictionary


func _init(section: Dictionary) -> void:
	d = section
	for k in ["ledger", "levels", "best", "stats"]:
		if not d.has(k):
			d[k] = {}
	if not d.has("history"):
		d["history"] = []
	if not d.has("xp"):
		d["xp"] = 0
	if not d.has("coins"):
		d["coins"] = 0
	if not d.has("daily_max_seen"):
		d["daily_max_seen"] = 0
	for k in ["daily_total", "daily_streak", "daily_streak_best", "daily_last"]:
		if not d.has(k):
			d[k] = 0


# ---------- XP and levels ----------
static func xp_to_next(level: int) -> int:
	return int(100.0 * pow(float(level), 1.5))


static func level_from_xp(total_xp: int) -> Dictionary:
	var level := 1
	var rest := total_xp
	while rest >= xp_to_next(level):
		rest -= xp_to_next(level)
		level += 1
	return {"level": level, "into": rest, "needed": xp_to_next(level)}


func xp() -> int: return int(d["xp"])
func coins() -> int: return int(d["coins"])
func level() -> int: return int(level_from_xp(xp())["level"])


# ---------- Ledger ----------
func has_key(key: String) -> bool:
	return d["ledger"].has(key)


## Returns true only the first time a key is granted.
func grant(key: String, add_xp := 0, add_coins := 0) -> bool:
	if has_key(key):
		return false
	d["ledger"][key] = int(Time.get_unix_time_from_system())
	d["xp"] = xp() + maxi(add_xp, 0)
	d["coins"] = coins() + maxi(add_coins, 0)
	return true


func spend(amount: int) -> bool:
	if amount <= 0 or coins() < amount:
		return false
	d["coins"] = coins() - amount
	return true


# ---------- Level results ----------
func level_key(game_id: String, level_id: int) -> String:
	return "%s:%d" % [game_id, level_id]


func stars_for(game_id: String, level_id: int) -> int:
	var rec: Dictionary = d["levels"].get(level_key(game_id, level_id), {})
	return int(rec.get("stars", 0))


## stars 0..3. base_xp is for a 1-star first clear. Coins are paid once for the first star only.
## Returns a summary used by the result screen.
func report_result(game_id: String, level_id: int, stars: int, score: int, base_xp: int, coins_per_star: int) -> Dictionary:
	stars = clampi(stars, 0, 3)
	var lk := level_key(game_id, level_id)
	var level_before := level()
	var rec: Dictionary = d["levels"].get(lk, {"stars": 0, "best": 0, "plays": 0})
	var prev_stars := int(rec.get("stars", 0))
	var gained_xp := 0
	var gained_coins := 0
	var new_stars: Array[int] = []
	var first_clear := false
	if stars > 0:
		var full_xp := int(round(base_xp * (1.0 + 0.25 * (stars - 1))))
		if grant("clear:" + lk, full_xp, 0):
			gained_xp += full_xp
			first_clear = true
		elif int(rec.get("paid_replays", 0)) < REPLAY_XP_MAX:
			var replay := int(round(full_xp * REPLAY_XP_FACTOR))
			d["xp"] = xp() + replay
			gained_xp += replay
			rec["paid_replays"] = int(rec.get("paid_replays", 0)) + 1
		for s in range(1, stars + 1):
			if grant("star:%s:%d" % [lk, s], 0, 0):
				new_stars.append(s)
		if stars >= 1 and grant("coin:first_star:%s" % lk, 0, coins_per_star):
			gained_coins += coins_per_star
	rec["stars"] = maxi(prev_stars, stars)
	var new_best := score > int(rec.get("best", 0))
	rec["best"] = maxi(int(rec.get("best", 0)), score)
	rec["plays"] = int(rec.get("plays", 0)) + 1
	d["levels"][lk] = rec
	_push_history({"g": game_id, "l": level_id, "s": stars, "sc": score, "t": int(Time.get_unix_time_from_system())})
	var level_after := level()
	return {
		"stars": stars, "prev_stars": prev_stars, "new_stars": new_stars,
		"xp": gained_xp, "coins": gained_coins, "first_clear": first_clear,
		"best": int(rec["best"]), "new_best": new_best and int(rec["plays"]) > 1,
		"level_before": level_before, "level_after": level_after,
	}


func _push_history(entry: Dictionary) -> void:
	var h: Array = d["history"]
	h.append(entry)
	while h.size() > HISTORY_MAX:
		h.pop_front()


# ---------- Stats ----------
func stars_in_game(game_id: String) -> int:
	var total := 0
	for k in d["levels"]:
		if str(k).begins_with(game_id + ":"):
			total += int(d["levels"][k].get("stars", 0))
	return total


func total_stars() -> int:
	var total := 0
	for k in d["levels"]:
		total += int(d["levels"][k].get("stars", 0))
	return total


func total_plays() -> int:
	var total := 0
	for k in d["levels"]:
		total += int(d["levels"][k].get("plays", 0))
	return total


func total_wins() -> int:
	var n := 0
	for k in d["levels"]:
		if int(d["levels"][k].get("stars", 0)) > 0:
			n += 1
	return n


func perfect_levels() -> int:
	var n := 0
	for k in d["levels"]:
		if int(d["levels"][k].get("stars", 0)) >= 3:
			n += 1
	return n


func distinct_games() -> int:
	var seen := {}
	for k in d["levels"]:
		seen[str(k).get_slice(":", 0)] = true
	return seen.size()


func levels_won_in_game(game_id: String) -> int:
	var n := 0
	for k in d["levels"]:
		if str(k).begins_with(game_id + ":") and int(d["levels"][k].get("stars", 0)) > 0:
			n += 1
	return n


func items_owned() -> int:
	var n := 0
	for k in d["ledger"]:
		if str(k).begins_with("own:"):
			n += 1
	return n


func best_in_game(game_id: String) -> int:
	var best := 0
	for k in d["levels"]:
		if str(k).begins_with(game_id + ":"):
			best = maxi(best, int(d["levels"][k].get("best", 0)))
	return best


## Most recent history entry, or {} if none.
func last_played() -> Dictionary:
	var h: Array = d["history"]
	return h[-1] if h.size() > 0 else {}


## Unique game ids from newest to oldest.
func recent_games(limit := 6) -> Array[String]:
	var out: Array[String] = []
	var h: Array = d["history"]
	for i in range(h.size() - 1, -1, -1):
		var g := str(h[i].get("g", ""))
		if g != "" and not (g in out):
			out.append(g)
			if out.size() >= limit:
				break
	return out


## Level to resume: next level after the last win, or the same level after a loss.
func resume_level(game_id: String, level_count: int) -> int:
	var best_cleared := 0
	for k in d["levels"]:
		if str(k).begins_with(game_id + ":") and int(d["levels"][k].get("stars", 0)) > 0:
			best_cleared = maxi(best_cleared, int(str(k).get_slice(":", 1)))
	return clampi(best_cleared + 1, 1, maxi(level_count, 1))


# ---------- Daily challenge (offline, clock-rollback guarded) ----------
static func date_key(date: Dictionary) -> int:
	return int(date["year"]) * 10000 + int(date["month"]) * 100 + int(date["day"])


## Rollback = the device date is before the last CLAIMED day. (Comparing with the
## highest date ever seen locked players out for good after one wrong forward date.)
func daily_status(today_key: int) -> String:
	if today_key < int(d["daily_last"]):
		return "clock_rollback"
	if has_key("daily:%d" % today_key):
		return "claimed"
	return "available"


func claim_daily(today_key: int, add_xp: int, add_coins: int) -> bool:
	if daily_status(today_key) != "available":
		return false
	if not grant("daily:%d" % today_key, add_xp, add_coins):
		return false
	d["daily_max_seen"] = maxi(int(d["daily_max_seen"]), today_key)
	d["daily_streak"] = (int(d["daily_streak"]) + 1) if int(d["daily_last"]) == prev_day(today_key) else 1
	d["daily_streak_best"] = maxi(int(d["daily_streak_best"]), int(d["daily_streak"]))
	d["daily_total"] = int(d["daily_total"]) + 1
	d["daily_last"] = today_key
	return true


## Streak shown to the player: broken if the last claim is older than yesterday.
func current_streak(today_key: int) -> int:
	var last := int(d["daily_last"])
	if last == today_key or last == prev_day(today_key):
		return int(d["daily_streak"])
	return 0


static func prev_day(key: int) -> int:
	var dt := {"year": key / 10000, "month": (key / 100) % 100, "day": key % 100, "hour": 12, "minute": 0, "second": 0}
	var unix := Time.get_unix_time_from_datetime_dict(dt) - 86400
	return date_key(Time.get_date_dict_from_unix_time(unix))


func observe_date(today_key: int) -> void:
	d["daily_max_seen"] = maxi(int(d["daily_max_seen"]), today_key)
