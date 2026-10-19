class_name Daily
## Offline daily challenge: the same date gives the same challenge on every device.
## No network. Clock rollback is handled by ProgressModel.daily_status().

const BASE_XP := 60
const BASE_COINS := 25
const STREAK_BONUS := 5     # extra coins per streak day
const STREAK_CAP := 7


## games: catalog entries (non-dev). Returns {} if no games.
static func challenge_for(day_key: int, games: Array) -> Dictionary:
	var pool := []
	for g in games:
		if not bool(g.get("dev_only", false)):
			pool.append(g)
	if pool.is_empty():
		return {}
	pool.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("madar-daily-%d" % day_key)
	var g: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var max_level := mini(int(g["levels"]), 5)
	var level := rng.randi_range(1, max_level)
	var target := 2 if int(g["levels"]) > 1 else 1
	return {"day": day_key, "game": g["id"], "title": g["title"], "level": level, "target_stars": target}


static func reward(streak_after: int) -> Dictionary:
	return {"xp": BASE_XP, "coins": BASE_COINS + STREAK_BONUS * mini(maxi(streak_after - 1, 0), STREAK_CAP)}
