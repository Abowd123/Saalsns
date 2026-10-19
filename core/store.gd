class_name Store
## Cosmetics only (no gameplay advantage). Ownership = ledger key "own:<id>" so an item
## is paid once. Equipped items live in the "profile" save section.

const PATH := "res://content/store.json"
const KINDS := ["avatar", "ring", "burst"]

static var _items: Array = []


static func items() -> Array:
	if _items.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_items = parsed["items"]
	return _items


static func get_item(id: String) -> Dictionary:
	for it in items():
		if it["id"] == id:
			return it
	return {}


static func default_for(kind: String) -> Dictionary:
	for it in items():
		if it["kind"] == kind and bool(it.get("default", false)):
			return it
	return {}


static func owns(m: ProgressModel, it: Dictionary) -> bool:
	return bool(it.get("default", false)) or m.has_key("own:" + str(it["id"]))


## "owned" | "buy" | "locked" | "poor"
static func state(m: ProgressModel, it: Dictionary) -> String:
	if owns(m, it):
		return "owned"
	if it.has("requires") and not m.has_key("ach:" + str(it["requires"])):
		return "locked"
	if m.coins() < int(it["price"]):
		return "poor"
	return "buy"


## Spends coins and records ownership. Free achievement items are claimed with price 0.
static func buy(m: ProgressModel, it: Dictionary) -> bool:
	if state(m, it) != "buy":
		return false
	var price := int(it["price"])
	if price > 0 and not m.spend(price):
		return false
	return m.grant("own:" + str(it["id"]))


static func equip(m: ProgressModel, profile: Dictionary, it: Dictionary) -> bool:
	if not owns(m, it):
		return false
	profile["equip_" + str(it["kind"])] = it["id"]
	return true


static func equipped(m: ProgressModel, profile: Dictionary, kind: String) -> Dictionary:
	var it := get_item(str(profile.get("equip_" + kind, "")))
	if it.is_empty() or not owns(m, it):
		return default_for(kind)
	return it


static func equipped_color(kind: String, fallback: Color) -> Color:
	var it := equipped(Progress.model, SaveService.section("profile"), kind)
	return Color(it["color"]) if it.has("color") else fallback
