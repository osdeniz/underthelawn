class_name TextureLibrary
extends RefCounted
## Textures are looked for on disk first (res://textures/), exactly as the
## SceneKit TextureLibrary did (§5). Missing files are reported once and either
## fall back to a flat colour (ground) or are generated procedurally (tuft
## silhouette, radial fake-AO) so the sprint is playable without art.

const DIR := "res://textures/"
const EXTENSIONS: Array[String] = [".png", ".jpg", ".jpeg", ".webp"]

static var _cache := {}
static var _warned := {}


static func find(base_name: String) -> Texture2D:
	if _cache.has(base_name):
		return _cache[base_name]
	for ext in EXTENSIONS:
		var path := DIR + base_name + ext
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_cache[base_name] = tex
				return tex
	_cache[base_name] = null
	return null


static func warn_missing(base_name: String, consequence: String) -> void:
	if _warned.has(base_name):
		return
	_warned[base_name] = true
	print("[TextureLibrary] textures/%s.png yok -> %s" % [base_name, consequence])
	push_warning("TextureLibrary: %s eksik, %s" % [base_name, consequence])


## Nine pointed blade silhouettes on transparent ground, rooted at the bottom
## edge, green with dry yellow tips (§5).
static func tuft_silhouette(size: int = 128) -> Texture2D:
	var found := find("grass_blade_tuft")
	if found != null:
		return found
	warn_missing("grass_blade_tuft", "prosedurel silüet uretiliyor")
	if _cache.has("__tuft_generated"):
		return _cache["__tuft_generated"]

	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260822
	var blades := 14
	for b in blades:
		# Root spread along the bottom, tips fanning out from the centre.
		var root_x := (float(b) + 0.5) / float(blades)
		var fan := (root_x - 0.5) * 0.34
		var tip_x := clampf(root_x + fan, 0.02, 0.98)
		var height := rng.randf_range(0.55, 0.99)
		var half_w := rng.randf_range(0.026, 0.042)

		var steps := size * 2
		for s in steps:
			var t := float(s) / float(steps - 1)
			# Slight outward curve towards the tip.
			var cx := lerpf(root_x, tip_x, t * t * 0.7 + t * 0.3)
			var cy := t * height
			var w := half_w * (1.0 - 0.72 * t)
			var px := int(cx * float(size))
			var py := size - 1 - int(cy * float(size))
			var span := maxi(int(w * float(size)), 1)
			for dx in range(-span, span + 1):
				var x := px + dx
				if x < 0 or x >= size or py < 0 or py >= size:
					continue
				# Green at the root, dry yellow at the tip.
				var col := Color(0.20, 0.42, 0.13).lerp(Color(0.58, 0.70, 0.26), t)
				var edge := 1.0 - absf(float(dx)) / float(span + 1)
				img.set_pixel(x, py, Color(col.r, col.g, col.b, clampf(edge * 2.4, 0.0, 1.0)))

	var tex := ImageTexture.create_from_image(img)
	_cache["__tuft_generated"] = tex
	return tex


## Thin leaf silhouette for the clipping particles, 12x32 per §9.
static func leaf_particle() -> Texture2D:
	var found := find("leaf_particle")
	if found != null:
		return found
	warn_missing("leaf_particle", "prosedurel yaprak uretiliyor")
	if _cache.has("__leaf_generated"):
		return _cache["__leaf_generated"]

	var w := 12
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in h:
		var v := float(y) / float(h - 1)
		# Pointed at both ends, widest a third of the way up.
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
	var tex := ImageTexture.create_from_image(img)
	_cache["__leaf_generated"] = tex
	return tex


## Radial black gradient used for every fake contact shadow (§13).
static func ao_radial(size: int = 128) -> Texture2D:
	var found := find("ao_radial")
	if found != null:
		return found
	if _cache.has("__ao_generated"):
		return _cache["__ao_generated"]

	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - half, float(y) - half).length() / half
			var a := clampf(1.0 - smoothstep(0.15, 1.0, d), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a * 0.55))
	var tex := ImageTexture.create_from_image(img)
	_cache["__ao_generated"] = tex
	return tex
