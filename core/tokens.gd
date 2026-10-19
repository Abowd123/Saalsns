class_name Tokens
## Madar design tokens. The ONLY place colors, sizes and radii are defined.

# Colors
const BG := Color("#0E1424")
const SURFACE_1 := Color("#161E33")
const SURFACE_2 := Color("#1E2843")
const LINE := Color("#2A3350")
const TEXT := Color("#EEF2FA")
const TEXT_MUTED := Color("#9AA6C2")
const SUCCESS := Color("#3DDC84")
const ERROR := Color("#FF5A5A")
const COIN := Color("#FFD45C")
const HIGHLIGHT := Color(1, 1, 1, 0.08)
const SHADOW := Color(0, 0, 0, 0.38)

enum World { KNOWLEDGE, PUZZLES, SPEED, BUILD }
const WORLD_COLORS := {
	World.KNOWLEDGE: Color("#F5B33D"),
	World.PUZZLES: Color("#2CC9B5"),
	World.SPEED: Color("#FF5E6C"),
	World.BUILD: Color("#9BDB4D"),
}
const WORLD_NAMES := {
	World.KNOWLEDGE: "المعرفة",
	World.PUZZLES: "الألغاز",
	World.SPEED: "السرعة",
	World.BUILD: "البناء",
}

# Radii
const RADIUS_CARD := 20
const RADIUS_WORLD := 24
const RADIUS_BUTTON := 20

# Type scale (px at 720 wide design)
const FS_DISPLAY := 56
const FS_H1 := 36
const FS_H2 := 28
const FS_BODY := 24
const FS_CAPTION := 20
const FS_MIN := 16

# Spacing
const SP_XS := 6
const SP_S := 12
const SP_M := 20
const SP_L := 28
const SP_XL := 44

# Touch
const TOUCH_MIN := 88

# Fonts
# Arabic fonts have no Latin letters (English questions, "XP", chemical symbols, × ÷ °).
# Each font falls back to a bundled Noto Sans Latin subset, so text looks the same on
# every phone instead of depending on the system font.
static var font_latin: Font = load("res://assets/fonts/NotoSansLatin-Regular.ttf")
static var font_latin_bold: Font = load("res://assets/fonts/NotoSansLatin-Bold.ttf")
static var font_display: Font = _with_fallbacks("res://assets/fonts/NotoKufiArabic-Bold.ttf", ["res://assets/fonts/NotoSansArabic-Bold.ttf", "res://assets/fonts/NotoSansLatin-Bold.ttf"])
static var font_body: Font = _with_fallbacks("res://assets/fonts/NotoSansArabic-Regular.ttf", ["res://assets/fonts/NotoSansLatin-Regular.ttf"])
static var font_bold: Font = _with_fallbacks("res://assets/fonts/NotoSansArabic-Bold.ttf", ["res://assets/fonts/NotoSansLatin-Bold.ttf"])


static func _with_fallbacks(path: String, fallback_paths: Array) -> Font:
	var f: FontFile = (load(path) as FontFile).duplicate()
	var fb: Array[Font] = []
	for fp in fallback_paths:
		fb.append(load(fp))
	f.fallbacks = fb
	return f


static func world_color(w: int) -> Color:
	return WORLD_COLORS.get(w, TEXT)
