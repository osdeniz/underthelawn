extends SceneTree
## One-off asset generator. Writes the placeholder textures and sounds that
## REFERENCE.md §5 and §14 describe to disk as real files, so the game only ever
## LOADS files (the sprint brief forbids runtime synthesis).
##
## Run:  Godot --headless --path . --script res://tools/gen_assets.gd
## Replace any output with real art/recordings of the same name at any time.

const SR := 44100


## Existing files are left alone: real art or recordings dropped into
## textures/ or audio/ must never be overwritten by the placeholder generator.
## Delete a file first if you want it regenerated.
static func _skip(path: String) -> bool:
	if FileAccess.file_exists(path):
		print("  atlandi (dosya var): %s" % path.get_file())
		return true
	return false


func _initialize() -> void:
	print("--- asset uretimi (var olan dosyalara dokunulmaz) ---")
	_grass_albedo(512)
	_grass_normal(256)
	_tuft_silhouette(512)
	_leaf_particle()
	_siding(256)
	_shingles(256)
	_bark(256)
	_wood(256)
	_asphalt(512)
	_dirt(256)
	_cloud_billboard(256)
	_engine_loop()
	_grass_cut()
	_discovery_chime()
	print("--- bitti ---")
	quit()


# ---------------------------------------------------------------- noise helpers

func _hash2(x: int, y: int, seed_value: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed_value * 1442695040888963407) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177
	h = h & 0x7fffffff
	return float(h % 100000) / 100000.0


## Value noise that wraps at `period`, so the texture tiles seamlessly.
func _wrapped_noise(u: float, v: float, period: int, seed_value: int) -> float:
	var fx := u * float(period)
	var fy := v * float(period)
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _hash2(posmod(x0, period), posmod(y0, period), seed_value)
	var b := _hash2(posmod(x0 + 1, period), posmod(y0, period), seed_value)
	var c := _hash2(posmod(x0, period), posmod(y0 + 1, period), seed_value)
	var d := _hash2(posmod(x0 + 1, period), posmod(y0 + 1, period), seed_value)
	return lerp(lerp(a, b, tx), lerp(c, d, tx), ty)


func _fbm(u: float, v: float, base_period: int, octaves: int, seed_value: int) -> float:
	var total := 0.0
	var amp := 1.0
	var norm := 0.0
	var period := base_period
	for o in octaves:
		total += _wrapped_noise(u, v, period, seed_value + o * 131) * amp
		norm += amp
		amp *= 0.5
		period *= 2
	return total / norm


# ---------------------------------------------------------------- textures (§5)

## Green blotches + clipping scratches + dry yellow tips, seamless.
func _grass_albedo(size: int) -> void:
	if _skip("res://textures/grass_albedo.png"):
		return
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	# Green-dominant rather than olive: red pulled down, green pushed up.
	var dark := Color(0.098, 0.255, 0.072)
	var mid := Color(0.180, 0.420, 0.125)
	var light := Color(0.270, 0.560, 0.180)
	var dry := Color(0.470, 0.520, 0.230)

	for y in size:
		for x in size:
			var u := float(x) / float(size)
			var v := float(y) / float(size)
			# Broad patchiness, then fine blade grain.
			var patch := _fbm(u, v, 4, 4, 11)
			var grain := _fbm(u, v, 48, 3, 27)
			var t := clampf(patch * 0.65 + grain * 0.45, 0.0, 1.0)
			var col := dark.lerp(mid, clampf(t * 1.6, 0.0, 1.0))
			col = col.lerp(light, clampf((t - 0.55) * 1.9, 0.0, 1.0))
			# Dry yellow tips where the fine grain peaks.
			var dryness := clampf((grain - 0.74) * 3.4, 0.0, 1.0)
			col = col.lerp(dry, dryness * 0.35)   # less dry-yellow dirt
			# Faint clipping scratches: thin high-frequency streaks.
			var streak := _wrapped_noise(u * 0.35 + v * 2.4, v * 9.0, 64, 91)
			if streak > 0.86:
				col = col.lerp(light, (streak - 0.86) * 4.0)
			img.set_pixel(x, y, col)

	img.generate_mipmaps()
	var err := img.save_png("res://textures/grass_albedo.png")
	print("  grass_albedo.png %dx%d -> %s" % [size, size, "ok" if err == OK else str(err)])


## Normal map derived from the same fine grain height field.
func _grass_normal(size: int) -> void:
	if _skip("res://textures/grass_normal.png"):
		return
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var strength := 2.4
	for y in size:
		for x in size:
			var u := float(x) / float(size)
			var v := float(y) / float(size)
			var step := 1.0 / float(size)
			var hl := _fbm(u - step, v, 40, 3, 27)
			var hr := _fbm(u + step, v, 40, 3, 27)
			var hd := _fbm(u, v - step, 40, 3, 27)
			var hu := _fbm(u, v + step, 40, 3, 27)
			var n := Vector3((hl - hr) * strength, (hd - hu) * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	var err := img.save_png("res://textures/grass_normal.png")
	print("  grass_normal.png %dx%d -> %s" % [size, size, "ok" if err == OK else str(err)])


## Dense pointed-blade silhouette on transparent ground, rooted at the bottom.
func _tuft_silhouette(size: int) -> void:
	if _skip("res://textures/grass_blade_tuft.png"):
		return
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260822
	var blades := 22

	for b in blades:
		var root_x := (float(b) + rng.randf_range(0.15, 0.85)) / float(blades)
		var fan := (root_x - 0.5) * rng.randf_range(0.20, 0.44)
		var tip_x := clampf(root_x + fan, 0.01, 0.99)
		var height := rng.randf_range(0.45, 1.0)
		var half_w := rng.randf_range(0.019, 0.033)
		# Dark green at the root, brighter green at the tip; only a hint of dry
		# yellow so the clump reads as grass rather than straw.
		var root_col := Color(0.063, 0.169, 0.043).lerp(Color(0.110, 0.235, 0.075), rng.randf())
		var tip_col := Color(0.267, 0.451, 0.145).lerp(Color(0.365, 0.478, 0.180), rng.randf())

		var steps := size * 3
		for s in steps:
			var t := float(s) / float(steps - 1)
			var cx := lerpf(root_x, tip_x, t * t * 0.72 + t * 0.28)
			var cy := t * height
			var w := half_w * (1.0 - 0.80 * t)
			var px := cx * float(size)
			var py := float(size - 1) - cy * float(size)
			var span := maxi(int(ceil(w * float(size))), 1)
			var col := root_col.lerp(tip_col, t)
			for dx in range(-span - 1, span + 2):
				var xi := int(round(px)) + dx
				var yi := int(round(py))
				if xi < 0 or xi >= size or yi < 0 or yi >= size:
					continue
				var edge := clampf(1.0 - absf(float(dx)) / (float(span) + 1.0), 0.0, 1.0)
				var a := clampf(edge * 2.6, 0.0, 1.0)
				var prev := img.get_pixel(xi, yi)
				if a > prev.a:
					img.set_pixel(xi, yi, Color(col.r, col.g, col.b, a))

	img.generate_mipmaps()
	var err := img.save_png("res://textures/grass_blade_tuft.png")
	print("  grass_blade_tuft.png %dx%d, %d bicak -> %s" % [size, size, blades, "ok" if err == OK else str(err)])


## 12x32 thin leaf for the clipping particles (§9).
func _leaf_particle() -> void:
	if _skip("res://textures/leaf_particle.png"):
		return
	var w := 12
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in h:
		var v := float(y) / float(h - 1)
		var taper: float = sin(v * PI)
		var half := taper * float(w) * 0.34
		var center := float(w) * 0.5 + sin(v * PI * 0.8) * 0.9
		var col := Color(0.24, 0.46, 0.13).lerp(Color(0.51, 0.62, 0.20), v)
		for x in w:
			var d: float = absf(float(x) + 0.5 - center)
			if d > half:
				continue
			var edge: float = clampf((half - d) / maxf(half, 0.001) * 2.2, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, edge))
	var err := img.save_png("res://textures/leaf_particle.png")
	print("  leaf_particle.png %dx%d -> %s" % [w, h, "ok" if err == OK else str(err)])


## Horizontal siding panels, 32 px rows with a shadow line between (§5).
func _siding(size: int) -> void:
	if _skip("res://textures/siding_albedo.png"):
		return
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var base := Color(0.78, 0.77, 0.72)
	for y in size:
		var row := y % 32
		var shade := 1.0 - 0.16 * (float(row) / 31.0)
		if row >= 30:
			shade = 0.62   # gap shadow
		for x in size:
			var n := _fbm(float(x) / size, float(y) / size, 24, 2, 51) * 0.08
			var c := base * (shade - n)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	print("  siding_albedo.png -> %s" % ("ok" if img.save_png("res://textures/siding_albedo.png") == OK else "HATA"))


## Shingle rows, every other row offset half a tile (§5).
func _shingles(size: int) -> void:
	if _skip("res://textures/roof_shingles_albedo.png"):
		return
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var base := Color(0.42, 0.26, 0.20)
	var row_h := 24
	var tile_w := 42
	for y in size:
		var row := y / row_h
		var in_row := y % row_h
		for x in size:
			var off := (tile_w / 2) if row % 2 == 1 else 0
			var in_tile := (x + off) % tile_w
			var shade := 1.0 - 0.22 * (float(in_row) / float(row_h - 1))
			if in_row >= row_h - 3 or in_tile < 2:
				shade = 0.55
			var n := _hash2(x / 7, y / 7, 77) * 0.10
			img.set_pixel(x, y, base * (shade - n + 0.05))
	img.generate_mipmaps()
	print("  roof_shingles_albedo.png -> %s" % ("ok" if img.save_png("res://textures/roof_shingles_albedo.png") == OK else "HATA"))


## Vertically streaked bark (§5).
func _bark(size: int) -> void:
	if _skip("res://textures/bark_albedo.png"):
		return
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var dark := Color(0.24, 0.17, 0.11)
	var light := Color(0.42, 0.32, 0.22)
	for y in size:
		for x in size:
			# Stretch noise vertically for streaks.
			var n := _fbm(float(x) / size, float(y) / size * 0.18, 18, 3, 33)
			var ridge := absf(sin(float(x) * 0.35 + n * 6.0))
			img.set_pixel(x, y, dark.lerp(light, clampf(n * 0.6 + ridge * 0.35, 0.0, 1.0)))
	img.generate_mipmaps()
	print("  bark_albedo.png -> %s" % ("ok" if img.save_png("res://textures/bark_albedo.png") == OK else "HATA"))


## Grainy fence wood, horizontal grain (§5).
func _wood(size: int) -> void:
	if _skip("res://textures/wood_albedo.png"):
		return
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var dark := Color(0.45, 0.33, 0.20)
	var light := Color(0.66, 0.52, 0.34)
	for y in size:
		for x in size:
			var n := _fbm(float(x) / size * 0.15, float(y) / size, 20, 3, 91)
			var grain := sin(float(y) * 0.22 + n * 9.0) * 0.5 + 0.5
			img.set_pixel(x, y, dark.lerp(light, clampf(n * 0.5 + grain * 0.4, 0.0, 1.0)))
	img.generate_mipmaps()
	print("  wood_albedo.png -> %s" % ("ok" if img.save_png("res://textures/wood_albedo.png") == OK else "HATA"))


## Dark asphalt with faint cracks (§5).
func _asphalt(size: int) -> void:
	if _skip("res://textures/asphalt_albedo.png"):
		return
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var base := Color(0.16, 0.16, 0.17)
	for y in size:
		for x in size:
			var u := float(x) / size
			var v := float(y) / size
			var n := _fbm(u, v, 40, 3, 13) * 0.10
			var crack := _wrapped_noise(u * 3.0, v * 3.0, 12, 57)
			var c := base + Color(n, n, n)
			if crack > 0.485 and crack < 0.515:
				c = c * 0.55
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	print("  asphalt_albedo.png -> %s" % ("ok" if img.save_png("res://textures/asphalt_albedo.png") == OK else "HATA"))


## Earthy dirt (§5).
func _dirt(size: int) -> void:
	if _skip("res://textures/dirt_albedo.png"):
		return
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	var dark := Color(0.30, 0.21, 0.13)
	var light := Color(0.48, 0.36, 0.24)
	for y in size:
		for x in size:
			var n := _fbm(float(x) / size, float(y) / size, 14, 4, 29)
			var pebble := _hash2(x / 5, y / 5, 43)
			var c := dark.lerp(light, n)
			if pebble > 0.93:
				c = c.lerp(Color(0.55, 0.50, 0.44), 0.5)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	print("  dirt_albedo.png -> %s" % ("ok" if img.save_png("res://textures/dirt_albedo.png") == OK else "HATA"))


## Soft radial blob cluster for the cloud billboards (§12).
func _cloud_billboard(size: int) -> void:
	if _skip("res://textures/cloud_billboard.png"):
		return
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 314159
	var blobs: Array[Vector3] = []
	for b in 9:
		blobs.append(Vector3(
			rng.randf_range(0.22, 0.78),
			rng.randf_range(0.38, 0.62),
			rng.randf_range(0.10, 0.22)))
	for y in size:
		for x in size:
			var uv := Vector2(float(x) / size, float(y) / size)
			var a := 0.0
			for blob in blobs:
				var d := uv.distance_to(Vector2(blob.x, blob.y)) / blob.z
				a += exp(-d * d * 1.6)
			a = clampf(a * 0.55, 0.0, 0.92)
			img.set_pixel(x, y, Color(1.0, 1.0, 0.99, a))
	img.generate_mipmaps()
	print("  cloud_billboard.png -> %s" % ("ok" if img.save_png("res://textures/cloud_billboard.png") == OK else "HATA"))


# ---------------------------------------------------------------- audio (§14)

func _write_wav(path: String, samples: PackedFloat32Array, gain: float) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var s := clampf(samples[i] * gain, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = data
	var err := wav.save_to_wav(path)
	print("  %s  %.2fs -> %s" % [path.get_file(), float(samples.size()) / float(SR),
		"ok" if err == OK else str(err)])


## 85 Hz fundamental + 6 harmonics at 1/k (saw-like) + 10% amplitude modulation
## at 13 Hz ("pat-pat") + tanh saturation. Exactly 1 s, so it loops seamlessly:
## 85 and 13 both complete whole cycles in one second.
func _engine_loop() -> void:
	if _skip("res://audio/mower_engine_loop.wav"):
		return
	var count := SR
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / float(SR)
		var s := 0.0
		for k in range(1, 8):
			s += sin(TAU * 85.0 * float(k) * t) / float(k)
		var am := 1.0 + 0.10 * sin(TAU * 13.0 * t)
		out[i] = tanh(s * am * 0.9)
	_write_wav("res://audio/mower_engine_loop.wav", out, 0.85)


## 0.16 s white noise through a one-pole lowpass sweeping 2800 -> 500 Hz, fast
## attack and exponential decay.
func _grass_cut() -> void:
	if _skip("res://audio/grass_cut.wav"):
		return
	var count := int(SR * 0.16)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var lp := 0.0
	for i in count:
		var t := float(i) / float(SR)
		var progress := float(i) / float(count)
		var cutoff := lerpf(2800.0, 500.0, progress)
		var a := 1.0 - exp(-TAU * cutoff / float(SR))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		var attack := clampf(t / 0.004, 0.0, 1.0)
		out[i] = lp * attack * exp(-t * 22.0)
	_write_wav("res://audio/grass_cut.wav", out, 1.1)


## E6 (1318.5 Hz) then B6 (1975.5 Hz) 0.12 s later, exponential decay, 0.7 s.
func _discovery_chime() -> void:
	if _skip("res://audio/discovery_chime.wav"):
		return
	var count := int(SR * 0.7)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / float(SR)
		var s := sin(TAU * 1318.5 * t) * exp(-t * 4.2)
		if t > 0.12:
			var t2 := t - 0.12
			s += sin(TAU * 1975.5 * t2) * exp(-t2 * 4.6) * 0.85
		out[i] = s
	_write_wav("res://audio/discovery_chime.wav", out, 0.5)
