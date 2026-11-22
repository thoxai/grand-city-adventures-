class_name EngineAudio
extends AudioStreamPlayer3D
## Prozedural erzeugter Motorsound (kein externes Audio-Asset noetig).
## Tonhoehe folgt der Geschwindigkeit, Lautstaerke dem Gaspedal.

const MIX_RATE := 22050.0

var rpm := 0.0          # 0..1
var throttle_load := 0.0  # 0..1
var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0
var _phase2 := 0.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.12
	stream = gen
	# Im Web ist "Sample"-Wiedergabe Standard; Generatoren brauchen Stream-Wiedergabe
	playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	unit_size = 8.0
	max_distance = 60.0
	volume_db = -8.0


func start() -> void:
	if not playing:
		play()
		_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func stop_engine() -> void:
	stop()
	_playback = null


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var freq := 38.0 + rpm * 120.0
	var amp := 0.18 + throttle_load * 0.22
	var inc := freq / MIX_RATE
	var inc2 := freq * 0.5 / MIX_RATE
	for i in frames:
		_phase = fmod(_phase + inc, 1.0)
		_phase2 = fmod(_phase2 + inc2, 1.0)
		var saw := _phase * 2.0 - 1.0
		var sub := sin(_phase2 * TAU)
		var s := (saw * 0.45 + sub * 0.55) * amp
		_playback.push_frame(Vector2(s, s))
