class_name Achievements
## Data-driven achievements (content/achievements.json). Unlocking goes through the
## ledger key "ach:<id>", so each reward is paid exactly once, even after reinstall+import.

const PATH := "res://content/achievements.json"

static var _defs: Array = []


static func defs() -> Array:
	if _defs.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_defs = parsed["achievements"]
	return _defs


## game_world: {game_id: world_key}. Returns [current, target].
static func progress_of(a: Dictionary, m: ProgressModel, game_world: Dictionary) -> Array:
	var target := int(a["target"])
	var cur := 0
	match str(a["type"]):
		"total_wins":
			cur = m.total_wins()
		"total_stars":
			cur = m.total_stars()
		"total_plays":
			cur = m.total_plays()
		"player_level":
			cur = m.level()
		"distinct_games":
			cur = m.distinct_games()
		"perfect_levels":
			cur = m.perfect_levels()
		"daily_total":
			cur = int(m.d["daily_total"])
		"daily_streak_best":
			cur = int(m.d["daily_streak_best"])
		"items_owned":
			cur = m.items_owned()
		"level_stars":
			cur = m.stars_for(str(a["game"]), int(a["level"]))
		"game_levels_won":
			cur = m.levels_won_in_game(str(a["game"]))
		"levels_won":
			for lvl in a["levels"]:
				if m.stars_for(str(a["game"]), int(lvl)) > 0:
					cur += 1
		"world_stars":
			for k in m.d["levels"]:
				if game_world.get(str(k).get_slice(":", 0), "") == str(a["world"]):
					cur += int(m.d["levels"][k].get("stars", 0))
		"worlds_won":
			var w := {}
			for k in m.d["levels"]:
				if int(m.d["levels"][k].get("stars", 0)) > 0:
					var wk: String = game_world.get(str(k).get_slice(":", 0), "")
					if wk != "":
						w[wk] = true
			cur = w.size()
	return [mini(cur, target), target]


static func is_unlocked(a: Dictionary, m: ProgressModel) -> bool:
	return m.has_key("ach:" + str(a["id"]))


## Grants every newly satisfied achievement. Loops because a grant can raise the
## player level and satisfy a level achievement. Returns the newly unlocked defs.
static func evaluate(m: ProgressModel, game_world: Dictionary) -> Array:
	var out := []
	for _pass in 3:
		var any := false
		for a in defs():
			if is_unlocked(a, m):
				continue
			var p := progress_of(a, m, game_world)
			if p[0] >= p[1] and m.grant("ach:" + str(a["id"]), int(a["xp"]), int(a["coins"])):
				out.append(a)
				any = true
		if not any:
			break
	return out
