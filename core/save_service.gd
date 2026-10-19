extends Node
## Autoload "SaveService": owns the single save file. Systems mark it dirty; it writes
## after a short debounce, and immediately when the app is paused or closed.

const DEBOUNCE := 0.5

var store := SaveStore.new("user://save.json")
var _dirty := false
var _timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working in the pause menu
	store.load_or_create()
	Log.info("save loaded from: %s" % store.loaded_from)
	if store.loaded_from != "main" and store.loaded_from != "fresh":
		Log.warn("main save was invalid, recovered from %s" % store.loaded_from)


func section(name: String) -> Dictionary:
	if not store.data.has(name):
		store.data[name] = {}
	return store.data[name]


## Replaces the whole save (import). The current save is kept in user://pre_import.json first.
func replace_all(new_data: Dictionary) -> bool:
	var keep := SaveStore.new("user://pre_import.json")
	keep.data = store.data.duplicate(true)
	if not keep.save():
		Log.error("import: could not back up current save")
		return false
	store.data = new_data
	save_now()
	Progress.rebind()
	Settings.rebind()
	Log.info("import: save replaced")
	return true


func mark_dirty() -> void:
	_dirty = true
	_timer = DEBOUNCE


func save_now() -> void:
	if store.save():
		_dirty = false
	else:
		Log.error("save failed")


func _process(delta: float) -> void:
	if _dirty:
		_timer -= delta
		if _timer <= 0.0:
			save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty:
			save_now()
