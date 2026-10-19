extends Node
## Autoload "Log": writes to user://madar.log (rotates at 256 KB) and to the console.
## Send this file when reporting bugs.

const PATH := "user://madar.log"
const OLD_PATH := "user://madar.old.log"
const MAX_BYTES := 262144


func _ready() -> void:
	_rotate_if_needed()
	info("--- session start | %s | %s %s ---" % [ProjectSettings.get_setting("application/config/version"), OS.get_name(), OS.get_model_name()])


func info(msg: String) -> void:
	_write("INFO", msg)


func warn(msg: String) -> void:
	push_warning(msg)
	_write("WARN", msg)


func error(msg: String) -> void:
	push_error(msg)
	_write("ERROR", msg)


func read_all() -> String:
	if _file:
		_file.flush()
	if not FileAccess.file_exists(PATH):
		return ""
	return FileAccess.get_file_as_string(PATH)


var _file: FileAccess


## The file stays open for the session (opening it per line was slow on phones).
func _write(level: String, msg: String) -> void:
	var line := "%s [%s] %s" % [Time.get_datetime_string_from_system(), level, msg]
	if OS.is_debug_build():
		print(line)
	if _file == null:
		_file = FileAccess.open(PATH, FileAccess.READ_WRITE) if FileAccess.file_exists(PATH) else FileAccess.open(PATH, FileAccess.WRITE)
		if _file == null:
			return
		_file.seek_end()
	_file.store_line(line)
	_file.flush()


func _rotate_if_needed() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var size := f.get_length()
	f.close()
	if size < MAX_BYTES:
		return
	var d := DirAccess.open("user://")
	if d:
		if d.file_exists(OLD_PATH.get_file()):
			d.remove(OLD_PATH.get_file())
		d.rename(PATH.get_file(), OLD_PATH.get_file())
