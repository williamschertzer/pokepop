class_name Sfx
extends Node
## Retro blips, synthesised in code like the web version's oscillators.
## Each sound is rendered once to a small WAV and cached.

const RATE := 22050
const VOICES := 10

var muted := false
var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func blip(freq: float, dur: float, type := "square", vol := 0.03) -> void:
	if muted:
		return
	freq = snappedf(freq, 20.0)
	var key := "%d|%.3f|%s|%.3f" % [freq, dur, type, vol]
	var stream: AudioStreamWAV = _cache.get(key)
	if stream == null:
		stream = _render(freq, dur, type, vol)
		_cache[key] = stream
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.play()


## Frequency falls to half over the sound and volume fades out, like the
## exponential ramps in the original.
func _render(freq: float, dur: float, type: String, vol: float) -> AudioStreamWAV:
	var n := int((dur + 0.02) * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var f1 := maxf(40.0, freq * 0.5)
	var amp := vol * 6.0
	for i in n:
		var t := float(i) / RATE
		var k := clampf(t / dur, 0.0, 1.0)
		var f := freq * pow(f1 / freq, k)
		phase = fmod(phase + f / RATE, 1.0)
		var v: float
		match type:
			"square": v = 1.0 if phase < 0.5 else -1.0
			"triangle": v = 4.0 * absf(phase - 0.5) - 1.0
			"sawtooth": v = 2.0 * phase - 1.0
			_: v = sin(phase * TAU)
		var g := amp * pow(0.0001 / maxf(vol, 0.0001), k) if t < dur else 0.0
		data.encode_s16(i * 2, int(clampf(v * g, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
