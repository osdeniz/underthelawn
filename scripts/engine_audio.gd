class_name MowerEngine
extends AudioStreamPlayer
## Procedural mower engine: a small synth so the prototype ships with no audio
## assets. Fundamental "putt" tone + harmonics + intake noise, low-passed, with
## an extra shredding-hiss layer that rises while blades are actually cutting.

@export var idle_hz: float = 42.0
@export var max_hz: float = 96.0
@export var mix_rate: float = 22050.0

## 0..1 how hard the engine is working (driven by mower speed).
var throttle: float = 0.0
## 0..1 how much grass is being shredded right now.
var cut_load: float = 0.0

var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _lp: float = 0.0
var _noise_lp: float = 0.0
var _wobble: float = 0.0
var _smooth_throttle: float = 0.0
var _smooth_cut: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = mix_rate
	gen.buffer_length = 0.12
	stream = gen
	autoplay = false
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	if _playback == null:
		return
	_smooth_throttle = lerpf(_smooth_throttle, clampf(throttle, 0.0, 1.0), clampf(delta * 6.0, 0.0, 1.0))
	_smooth_cut = lerpf(_smooth_cut, clampf(cut_load, 0.0, 1.0), clampf(delta * 9.0, 0.0, 1.0))
	_fill()


func _fill() -> void:
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var inv_sr := 1.0 / mix_rate
	var freq := lerpf(idle_hz, max_hz, _smooth_throttle)
	var lp_a := 0.16 + 0.20 * _smooth_throttle
	var gain := 0.30 + 0.20 * _smooth_throttle

	for _i in frames:
		# Slow wobble keeps the idle from sounding like a pure oscillator.
		_wobble += inv_sr * 5.3
		if _wobble > 1.0:
			_wobble -= 1.0
		var f := freq * (1.0 + 0.035 * sin(_wobble * TAU))

		_phase += f * inv_sr
		if _phase >= 1.0:
			_phase -= 1.0

		var saw := _phase * 2.0 - 1.0
		var square := 1.0 if _phase < 0.42 else -1.0
		var tone := saw * 0.55 + square * 0.30 + sin(_phase * TAU) * 0.55
		tone += sin(_phase * TAU * 2.0) * 0.22
		tone += sin(_phase * TAU * 3.0) * 0.12

		var noise := _rng.randf_range(-1.0, 1.0)
		_noise_lp += (noise - _noise_lp) * 0.35
		var hiss := noise - _noise_lp  # cheap high-pass = grass shredding

		var raw := tone * 0.5 + noise * 0.14 + hiss * (0.10 + 0.55 * _smooth_cut)
		_lp += (raw - _lp) * lp_a

		var s := clampf(_lp * (gain + 0.10 * _smooth_cut), -1.0, 1.0)
		_playback.push_frame(Vector2(s, s))
