extends Node
## Autoload "Quality": turns the "quality" setting into concrete costs.
##   high     : animated backgrounds, full particles
##   balanced : animated backgrounds, 60% particles
##   low      : static backgrounds, 30% particles
## "auto" starts at high and steps DOWN (never up in the same session) when the
## measured frame rate stays under 85% of the cap for two 3-second windows.
## Loading frames during scene changes are ignored.

signal tier_changed(tier: String)

const TIERS := ["high", "balanced", "low"]
const WINDOW := 3.0

var _acc := 0.0
var _frames := 0
var _bad_windows := 0
var _skip := 0


func tier() -> String:
	var q := str(Settings.get_value("quality"))
	if q == "auto":
		var t := str(SaveService.section("settings").get("auto_tier", "high"))
		return t if t in TIERS else "high"
	return q if q in TIERS else "high"


func particle_scale() -> float:
	match tier():
		"balanced":
			return 0.6
		"low":
			return 0.3
	return 1.0


## 0..1 amount of visual extras (aurora, stars, grain, ripples, light rays, shine).
func detail() -> float:
	match tier():
		"balanced":
			return 0.6
		"low":
			return 0.0
	return 1.0


func fancy() -> bool:
	return detail() > 0.0 and not bool(Settings.get_value("reduce_motion"))


func bg_motion() -> float:
	if bool(Settings.get_value("reduce_motion")) or tier() == "low":
		return 0.0
	return 1.0


## Lets the player retry auto-detection (Settings button).
func reset_auto() -> void:
	SaveService.section("settings")["auto_tier"] = "high"
	SaveService.mark_dirty()
	_bad_windows = 0
	tier_changed.emit(tier())


func _ready() -> void:
	get_tree().tree_changed.connect(func(): _skip = 20)   # scene load spikes


func _process(delta: float) -> void:
	if str(Settings.get_value("quality")) != "auto":
		return
	if _skip > 0:
		_skip -= 1
		return
	_acc += delta
	_frames += 1
	if _acc < WINDOW:
		return
	var fps := _frames / _acc
	_acc = 0.0
	_frames = 0
	var cap := float(Engine.max_fps if Engine.max_fps > 0 else 60)
	if fps < cap * 0.85:
		_bad_windows += 1
	else:
		_bad_windows = 0
	if _bad_windows >= 2:
		_bad_windows = 0
		var i := TIERS.find(tier())
		if i < TIERS.size() - 1:
			var next: String = TIERS[i + 1]
			SaveService.section("settings")["auto_tier"] = next
			SaveService.mark_dirty()
			Log.warn("quality auto: %.0f fps < %.0f, stepping down to %s" % [fps, cap * 0.85, next])
			tier_changed.emit(next)
