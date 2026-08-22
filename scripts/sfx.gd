class_name Sfx
extends RefCounted
## Tiny runtime SFX generator so no audio files are needed.


## Descending/ascending bell arpeggio used when a secret is uncovered.
static func make_chime(sample_rate: int = 22050) -> AudioStreamWAV:
	var freqs := [523.25, 659.25, 783.99, 1046.50]
	var duration := 1.8
	var frames := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)

	for i in frames:
		var t := float(i) / float(sample_rate)
		var s := 0.0
		for k in freqs.size():
			var start := float(k) * 0.10
			if t <= start:
				continue
			var lt := t - start
			var env: float = exp(-lt * 2.4)
			var f: float = freqs[k]
			s += sin(TAU * f * lt) * env * (0.9 - 0.12 * float(k))
			s += sin(TAU * f * 2.0 * lt) * env * 0.18
		s = clampf(s * 0.20, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


## Short muffled thud for the reveal pop.
static func make_thud(sample_rate: int = 22050) -> AudioStreamWAV:
	var duration := 0.45
	var frames := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in frames:
		var t := float(i) / float(sample_rate)
		var env: float = exp(-t * 9.0)
		var raw := sin(TAU * lerpf(120.0, 45.0, minf(t * 4.0, 1.0)) * t)
		raw += rng.randf_range(-1.0, 1.0) * 0.5
		lp += (raw - lp) * 0.09
		var s := clampf(lp * env * 1.6, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav
