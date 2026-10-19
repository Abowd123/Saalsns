extends Node
## Autoload: short UI and game sounds with a small voice pool.

const SOUNDS := {
	"tap": "res://assets/audio/tap.wav",
	"pop": "res://assets/audio/pop.wav",
	"correct": "res://assets/audio/correct.wav",
	"wrong": "res://assets/audio/wrong.wav",
	"coin": "res://assets/audio/coin.wav",
	"whoosh": "res://assets/audio/whoosh.wav",
	"star1": "res://assets/audio/star1.wav",
	"star2": "res://assets/audio/star2.wav",
	"star3": "res://assets/audio/star3.wav",
	"win": "res://assets/audio/win.wav",
}
const VOICES := 8

var volume_db := -4.0
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working in the pause menu
	for key in SOUNDS:
		_streams[key] = load(SOUNDS[key])
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)


func play(key: String, pitch := 1.0) -> void:
	if not _streams.has(key):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[key]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
