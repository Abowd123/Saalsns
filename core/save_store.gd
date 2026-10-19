class_name SaveStore
extends RefCounted
## Crash-safe JSON save file.
## File format: line 1 = "MADAR1 <sha256 of body>", line 2+ = JSON body.
## Write: tmp -> verify -> rotate backups, then promote tmp with rollback protection.
## Load: main -> bak1 -> bak2 -> fresh. Each candidate must pass checksum + parse.

const CURRENT_SCHEMA := 1
const MAGIC := "MADAR1"

var path: String
var data: Dictionary = {}
var loaded_from := "none"   # main | bak1 | bak2 | fresh


func _init(p_path: String) -> void:
	path = p_path


func _tmp() -> String: return path.get_basename() + ".tmp"
func _bak(n: int) -> String: return path.get_basename() + ".bak%d" % n


static func fresh_data() -> Dictionary:
	return {
		"schema": CURRENT_SCHEMA,
		"created_unix": int(Time.get_unix_time_from_system()),
		"settings": {},
		"progress": {},
	}


func load_or_create() -> Dictionary:
	for candidate in [[path, "main"], [_bak(1), "bak1"], [_bak(2), "bak2"]]:
		var parsed = _read_verified(candidate[0])
		if parsed is Dictionary:
			data = migrate(parsed)
			loaded_from = candidate[1]
			return data
	data = fresh_data()
	loaded_from = "fresh"
	return data


func _read_verified(p: String):
	if not FileAccess.file_exists(p):
		return null
	var text := FileAccess.get_file_as_string(p)
	var nl := text.find("\n")
	if nl <= 0:
		return null
	var header := text.substr(0, nl).split(" ")
	var body := text.substr(nl + 1)
	if header.size() != 2 or header[0] != MAGIC or header[1] != body.sha256_text():
		return null
	var parsed = JSON.parse_string(body)
	return parsed if parsed is Dictionary else null


func save() -> bool:
	data["schema"] = CURRENT_SCHEMA
	data["saved_unix"] = int(Time.get_unix_time_from_system())
	var body := JSON.stringify(data)
	var text := "%s %s\n%s" % [MAGIC, body.sha256_text(), body]
	var f := FileAccess.open(_tmp(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	if not (_read_verified(_tmp()) is Dictionary):
		return false
	var d := DirAccess.open(path.get_base_dir())
	if d == null:
		return false
	var main_f := path.get_file()
	var b1 := _bak(1).get_file()
	var b2 := _bak(2).get_file()
	if d.file_exists(b2):
		d.remove(b2)
	if d.file_exists(b1):
		d.rename(b1, b2)
	var moved_old := false
	if d.file_exists(main_f):
		moved_old = d.rename(main_f, b1) == OK
	var promoted := d.rename(_tmp().get_file(), main_f) == OK
	if promoted:
		return true
	# Never leave the app without a valid main save if promotion fails.
	if moved_old and not d.file_exists(main_f):
		d.rename(b1, main_f)
	return false


func delete_all() -> void:
	var d := DirAccess.open(path.get_base_dir())
	if d == null:
		return
	for p in [path, _bak(1), _bak(2), _tmp()]:
		if d.file_exists(p.get_file()):
			d.remove(p.get_file())


## Schema migrations. Add a new "elif" block for every schema bump. Never edit old ones.
static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("schema", 0))
	if v < 1:
		# v0 (phase 0 test file) had flat keys. Wrap into the v1 layout.
		var m := fresh_data()
		m["legacy"] = d
		d = m
		v = 1
	d["schema"] = v
	if not d.has("settings"):
		d["settings"] = {}
	if not d.has("progress"):
		d["progress"] = {}
	return d
