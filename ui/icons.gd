class_name Icons
## Built-in vector icon set (own drawings, 24x24 grid). Rendered from SVG text at the
## exact pixel size needed, so icons stay sharp on every screen. No image files to import.

const TPL := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="{C}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">%s</svg>'

const SVG := {
	"back": '<path d="M5 12h14M13 6l6 6-6 6"/>',
	"arrow_up": '<path d="M12 19V5M6 11l6-6 6 6"/>',
	"arrow_down": '<path d="M12 5v14M6 13l6 6 6-6"/>',
	"arrow_left": '<path d="M19 12H5M11 6l-6 6 6 6"/>',
	"arrow_right": '<path d="M5 12h14M13 6l6 6-6 6"/>',
	"pause": '<rect x="6" y="5" width="4.2" height="14" rx="1.2" fill="{C}" stroke="none"/><rect x="13.8" y="5" width="4.2" height="14" rx="1.2" fill="{C}" stroke="none"/>',
	"play": '<path d="M8 5.5l11 6.5-11 6.5z" fill="{C}"/>',
	"restart": '<path d="M4.5 12a7.5 7.5 0 1 0 2.4-5.5"/><path d="M4.5 3.8v4.6h4.6"/>',
	"undo": '<path d="M9 14L4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
	"hint": '<path d="M9 18h6M10 21.2h4"/><path d="M12 2.8a6.2 6.2 0 0 0-3.9 11c.7.6 1 1.3 1 2.2h5.8c0-.9.3-1.6 1-2.2A6.2 6.2 0 0 0 12 2.8z"/>',
	"settings": '<path d="M12 3.2l1.6 2.3 2.7-.6.6 2.7 2.4 1.4-1.2 2.5 1.2 2.5-2.4 1.4-.6 2.7-2.7-.6L12 20.8l-1.6-2.3-2.7.6-.6-2.7-2.4-1.4L5.9 12.5 4.7 10l2.4-1.4.6-2.7 2.7.6z"/><circle cx="12" cy="12" r="3.2"/>',
	"coin": '<circle cx="12" cy="12" r="9.2" fill="{C}" stroke="none"/><circle cx="12" cy="12" r="5.6" stroke="#0E1424" stroke-opacity=".35" stroke-width="1.8"/>',
	"star": '<path d="M12 2.8l2.8 5.8 6.4.9-4.6 4.5 1.1 6.4L12 17.4l-5.7 3 1.1-6.4-4.6-4.5 6.4-.9z" fill="{C}" stroke="none"/>',
	"lock": '<rect x="5" y="10.5" width="14" height="10.5" rx="2.2"/><path d="M8 10.5V7.8a4 4 0 0 1 8 0v2.7"/>',
	"close": '<path d="M6 6l12 12M18 6L6 18"/>',
	"check": '<path d="M5 12.5l4.5 4.5L19 7"/>',
	"trophy": '<path d="M8 3.8h8V9a4 4 0 0 1-8 0z"/><path d="M8 5.8H5.2A3.2 3.2 0 0 0 8 10M16 5.8h2.8A3.2 3.2 0 0 1 16 10M12 13v4M8.5 21h7M9.5 17h5"/>',
	"bag": '<path d="M5 8h14l-1.2 13H6.2z"/><path d="M9 10V6.5a3 3 0 0 1 6 0V10"/>',
	"home": '<path d="M4 11l8-7 8 7"/><path d="M6.5 9.5V20h11V9.5"/>',
	"user": '<circle cx="12" cy="8" r="4"/><path d="M4.5 21a7.5 7.5 0 0 1 15 0"/>',
	"flame": '<path d="M12 2.8c1 4 5.2 5.4 5.2 10.4a5.2 5.2 0 0 1-10.4 0c0-2.8 1.6-4 1.9-6 1 .9 1.6 2 1.6 3.2 1.2-2 1.9-4.4 1.7-7.6z" fill="{C}" stroke="none"/>',
	"book": '<path d="M12 6.5C10.5 5 8 4.5 4 4.5V19c4 0 6.5.5 8 2 1.5-1.5 4-2 8-2V4.5c-4 0-6.5.5-8 2z"/><path d="M12 6.5V21"/>',
	"puzzle": '<path d="M5 8.5h3.2a2.3 2.3 0 1 1 4.6 0H16v3.2a2.3 2.3 0 1 1 0 4.6V19.5H5v-3.4a2.3 2.3 0 1 0 0-4.4z"/>',
	"bolt": '<path d="M13.5 2.5L4.5 13.8h6.6l-1 7.7 9.4-11.6h-6.7z" fill="{C}" stroke="none"/>',
	"gear": '<path d="M12 3.2l1.6 2.3 2.7-.6.6 2.7 2.4 1.4-1.2 2.5 1.2 2.5-2.4 1.4-.6 2.7-2.7-.6L12 20.8l-1.6-2.3-2.7.6-.6-2.7-2.4-1.4L5.9 12.5 4.7 10l2.4-1.4.6-2.7 2.7.6z"/><circle cx="12" cy="12" r="3.2"/>',
}

static var _cache := {}


## Texture for an icon at `px` pixels in `color`. Cached per (name, size, color).
static func tex(icon_name: String, px := 40, color := Color("#EEF2FA")) -> Texture2D:
	var key := "%s|%d|%s" % [icon_name, px, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var body: String = SVG.get(icon_name, SVG["close"])
	var svg := (TPL % body).replace("{C}", "#" + color.to_html(false))
	var img := Image.new()
	if img.load_svg_from_string(svg, float(px) / 24.0) != OK:
		Log.warn("icon failed: " + icon_name)
		return null
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t
