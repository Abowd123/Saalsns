extends Node
## Autoload "Catalog": the list of games, loaded from content/catalog.json.
## Adding a game = new folder under games/ + one entry here. No core code changes.

const PATH := "res://content/catalog.json"
const WORLD_IDS := {"knowledge": Tokens.World.KNOWLEDGE, "puzzles": Tokens.World.PUZZLES, "speed": Tokens.World.SPEED, "build": Tokens.World.BUILD}

var games: Array[Dictionary] = []
var errors: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	games.clear()
	errors.clear()
	var text := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary) or not parsed.has("games"):
		errors.append("catalog.json is invalid")
		Log.error(errors[-1])
		return
	var seen := {}
	for g in parsed["games"]:
		if g is Dictionary and bool(g.get("dev_only", false)) and not OS.is_debug_build():
			continue   # dev-only games are excluded from release exports
		var e := validate(g, seen)
		if e != "":
			errors.append(e)
			Log.error("catalog: " + e)
			continue
		seen[g["id"]] = true
		games.append(g)
	Log.info("catalog: %d games, %d errors" % [games.size(), errors.size()])


static func validate(g, seen: Dictionary) -> String:
	if not (g is Dictionary):
		return "entry is not an object"
	for k in ["id", "world", "title", "scene", "levels", "base_xp", "coins_per_star"]:
		if not g.has(k):
			return "%s: missing %s" % [g.get("id", "?"), k]
	if seen.has(g["id"]):
		return "%s: duplicate id" % g["id"]
	if not WORLD_IDS.has(g["world"]):
		return "%s: unknown world %s" % [g["id"], g["world"]]
	if not ResourceLoader.exists(g["scene"]):
		return "%s: scene not found %s" % [g["id"], g["scene"]]
	return ""


func get_game(id: String) -> Dictionary:
	for g in games:
		if g["id"] == id:
			return g
	return {}


func world_color(g: Dictionary) -> Color:
	return Tokens.world_color(WORLD_IDS.get(g.get("world", ""), Tokens.World.PUZZLES))
