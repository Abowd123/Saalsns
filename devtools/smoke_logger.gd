extends Logger
## Captures engine/script errors during the release gate smoke test.
## Loaded only if the engine has the Logger class (Godot 4.5+).

var errors: PackedStringArray = []
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	if errors.size() < 200:
		errors.append("%s:%d %s %s" % [file.get_file(), line, function, rationale if rationale != "" else code])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func take() -> PackedStringArray:
	_mutex.lock()
	var out := errors.duplicate()
	errors.clear()
	_mutex.unlock()
	return out
