class_name Horn
extends RefCounted
## Prozedural erzeugter Hupton (zwei Töne, leicht verzerrt) als AudioStreamWAV.
## WAV statt Generator: wird im Web als "Sample" abgespielt und kostet kaum CPU.

const MIX_RATE := 22050
static var _stream: AudioStreamWAV


static func stream() -> AudioStreamWAV:
	if _stream:
		return _stream
	var seconds := 0.5
	var n := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MIX_RATE
		var s := sin(TAU * 370.0 * t) + 0.8 * sin(TAU * 466.0 * t) + 0.25 * sin(TAU * 740.0 * t)
		s = tanh(s * 1.6) * 0.55
		var v := int(clampf(s, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	# Exakt ganze Perioden für nahtlose Schleife: 0,5 s enthält 185 bzw. 233 Perioden
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_stream = w
	return w


## Erzeugt einen 3D-Player für die Hupe eines Fahrzeugs.
static func make_player() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream()
	p.unit_size = 10.0
	p.max_distance = 80.0
	p.volume_db = -4.0
	p.position = Vector3(0, 0.8, -1.5)
	return p
