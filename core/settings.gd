extends Node
## Autoload "Settings": persisted user preferences, applied to engine/audio/motion.

signal changed

const DEFAULTS := {
	"music": 0.6,
	"sfx": 0.9,
	"haptics": true,
	"reduce_motion": false,
	"colorblind": false,
	"fps": 60,
	"quality": "auto",   # auto | high | balanced | low
	"show_perf": false,
}

var s: Dictionary


func _ready() -> void:
	s = SaveService.section("settings")
	for k in DEFAULTS:
		if not s.has(k):
			s[k] = DEFAULTS[k]
	_ensure_buses()
	apply()


## Re-reads the settings section (after a save import).
func rebind() -> void:
	s = SaveService.section("settings")
	for k in DEFAULTS:
		if not s.has(k):
			s[k] = DEFAULTS[k]
	apply()
	changed.emit()


func get_value(key: String):
	return s.get(key, DEFAULTS.get(key))


func set_value(key: String, value) -> void:
	match key:
		"music", "sfx":
			value = clampf(float(value), 0.0, 1.0)
		"fps":
			value = 30 if int(value) <= 30 else 60
		"quality":
			if not (value in ["auto", "high", "balanced", "low"]):
				value = "auto"
	s[key] = value
	apply()
	SaveService.mark_dirty()
	changed.emit()


func apply() -> void:
	_set_bus("Music", float(s["music"]))
	_set_bus("SFX", float(s["sfx"]))
	Engine.max_fps = int(s["fps"])
	Motion.reduce_motion = bool(s["reduce_motion"])


func vibrate(ms := 20) -> void:
	if bool(s.get("haptics", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func _ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


func _set_bus(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))
