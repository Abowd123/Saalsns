extends Node
## Autoload "Music": one looping track at a time with crossfade. Bus "Music".

const FADE := 1.2
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _current_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working in the pause menu
	_a = _make()
	_b = _make()


func _make() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func play(path: String) -> void:
	if path == _current_path:
		return
	_current_path = path
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var incoming := _b if _a.playing else _a
	var outgoing := _a if incoming == _b else _b
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(incoming, "volume_db", 0.0, FADE)
	if outgoing.playing:
		tw.tween_property(outgoing, "volume_db", -60.0, FADE)
		tw.chain().tween_callback(outgoing.stop)


func stop() -> void:
	_current_path = ""
	for p in [_a, _b]:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, FADE)
			tw.tween_callback(p.stop)
