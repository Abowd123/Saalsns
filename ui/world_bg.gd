class_name WorldBg
extends ColorRect
## Animated world background (shared shader). Follows quality and reduce-motion changes live.

var _mat: ShaderMaterial


static func make(accent: Color) -> WorldBg:
	var bg := WorldBg.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg._mat = ShaderMaterial.new()
	bg._mat.shader = UiKit.BG_SHADER
	bg._mat.set_shader_parameter("accent", accent)
	bg.material = bg._mat
	bg._apply()
	return bg


func _ready() -> void:
	Quality.tier_changed.connect(_on_tier_changed)
	Settings.changed.connect(_apply)


func _on_tier_changed(_tier: String) -> void:
	_apply()


func _apply() -> void:
	if _mat:
		_mat.set_shader_parameter("motion", Quality.bg_motion())
		_mat.set_shader_parameter("detail", Quality.detail())
