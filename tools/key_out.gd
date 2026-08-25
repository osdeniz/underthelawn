extends SceneTree
## Turns an AI "transparent" image into a real transparent PNG.
##
## Image tools routinely DRAW the transparency checkerboard instead of writing
## an alpha channel, so what arrives is a grey checked pattern with the object
## painted on top. This finds the two checker greys, erases them, and — the part
## that matters — reconstructs the soft shadow: a shadow on a checkerboard is
## just the checker multiplied down, so `alpha = 1 - darkness` gives back a
## proper alpha shadow instead of a grey smear.
##
##   Godot --headless --path . --script res://tools/key_out.gd
##
## Reads textures/hub/restore_*.jpg and writes <name>.png beside them.

const TARGETS: Array[String] = [
	"res://textures/hub/restore_swing.jpg",
	"res://textures/hub/restore_lantern.jpg",
	"res://textures/hub/restore_greenhouse.jpg",
	"res://textures/hub/restore_clinic.jpg",
	"res://textures/hub/restore_mast.jpg",
	"res://textures/hub/restore_station.jpg",
	"res://textures/hub/restore_farm.jpg",
	"res://textures/hub/restore_barn.jpg",
	"res://textures/hub/restore_homes.jpg",
	"res://textures/hub/restore_watchtower.jpg",
]
## How far a pixel may sit from a checker grey and still count as background.
const KEY_TOLERANCE := 0.055
## How dark a NEUTRAL pixel may get and still be read as shadow rather than
## object. Measured: a cast shadow reaches ~0.57 below its checker square, so the
## original 0.45 threshold kept most of every shadow as opaque grey. Genuine
## artwork in these overlays is all tinted and never reaches this branch.
const SHADOW_MIN := 0.92
## Colour must be this neutral to be checker or shadow; anything tinted is art.
## Raised from 0.10 after measuring: JPEG noise pushes a grey shadow past 0.10,
## so half of every shadow was being kept as opaque grey. Object colours are far
## above this (wood ~0.25, lamp glass ~0.5), so nothing real is at risk.
const MAX_SATURATION := 0.19


## Flat-background keying, which is exact: one reference value everywhere, so a
## soft coloured glow resolves correctly. (Over a drawn checkerboard it cannot —
## that is two unknowns per pixel, its colour and its alpha, against one
## equation.) The key colour is MEASURED per file rather than assumed: generators
## drift from the magenta they were asked for, and JPEG pulls it further, so
## these arrived around (0.85, 0.25, 0.70) and (0.98, 0.35, 0.95) in two batches.
const FLAT_MODE := true
## How far from the measured key a pixel may sit and still be background.
const FLAT_CLEAR := 0.16
## Beyond this it is fully opaque artwork; between the two it is an edge.
const FLAT_SOLID := 0.42
## How far blue may exceed the warmer channels before it is read as leftover
## key spill. The scene has no genuinely blue-dominant surfaces.
const DESPILL_SLACK := 0.06
## Alpha a pixel needs before it counts as part of the object for trimming.
const TRIM_ALPHA := 0.15


func _initialize() -> void:
	for path in TARGETS:
		if FLAT_MODE:
			_key_flat(path)
		else:
			_key(path)
	quit()


## Exact keying against a flat background: alpha comes straight from how far the
## pixel sits from the key colour, so glows and shadows both survive intact.
func _key_flat(path: String) -> void:
	var img := Image.new()
	if img.load(path) != OK:
		print("  %s okunamadi" % path)
		return
	img.convert(Image.FORMAT_RGBA8)
	var key := _measure_key(img)
	# Magenta's signature is "red and blue high, green low", and this artwork is
	# a warm palette where that combination never occurs. So the amount of key
	# in a pixel is measurable directly, which is far more reliable than the
	# distance in RGB: distance confuses "half transparent" with "a colour that
	# happens to sit near the key", and that is what left a pink halo.
	var key_magenta := (key.r + key.b) * 0.5 - key.g
	var cleared := 0
	var edged := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var magenta := (c.r + c.b) * 0.5 - c.g
			var mix := clampf(magenta / maxf(key_magenta, 0.001), 0.0, 1.0)
			var a := 1.0 - mix
			if a <= 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				cleared += 1
				continue
			if a >= 0.995:
				continue                       # solid artwork, untouched
			# Un-premultiply: recover the object's own colour from the observed
			# blend, then despill any magenta the JPEG smeared into the edge by
			# pulling blue no higher than green allows in this warm palette.
			var r := clampf((c.r - key.r * mix) / a, 0.0, 1.0)
			var g := clampf((c.g - key.g * mix) / a, 0.0, 1.0)
			var b := clampf((c.b - key.b * mix) / a, 0.0, 1.0)
			b = minf(b, maxf(g, r) + DESPILL_SLACK)
			r = minf(r, maxf(g, b) + DESPILL_SLACK * 2.0)
			img.set_pixel(x, y, Color(r, g, b, a))
			edged += 1
	# Trim to the object's own bounds. Where the generator happened to place it
	# on the canvas is arbitrary, so the game should not inherit that choice —
	# a trimmed layer can be positioned by data instead (projects.json
	# layer_rect).
	# get_used_rect() counts any alpha above zero, and JPEG noise leaves a haze
	# of nearly-transparent pixels at the borders, so it returned the whole
	# canvas every time. Bounds are measured against a real visibility floor.
	var bounds := _opaque_bounds(img, TRIM_ALPHA)
	if bounds.size.x > 0 and bounds.size.y > 0:
		img = img.get_region(bounds)
	var err := img.save_png(path.get_basename() + ".png")
	print("  %-26s key=(%.2f,%.2f,%.2f) silinen=%d kenar=%d kirpma=%s %s" % [
		path.get_file(), key.r, key.g, key.b, cleared, edged,
		str(bounds.size), "ok" if err == OK else "HATA"])


## The object's bounding box, ignoring the near-transparent haze around it.
func _opaque_bounds(img: Image, floor_alpha: float) -> Rect2i:
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < floor_alpha:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i(0, 0, img.get_width(), img.get_height())
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## The background colour, taken as the average of a thin border strip. Measured
## per image because the generator's magenta drifts between batches.
func _measure_key(img: Image) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var total := Vector3.ZERO
	var count := 0
	for y in range(0, h, 5):
		for x in range(0, w, 5):
			if x > w * 0.02 and x < w * 0.98 and y > h * 0.02 and y < h * 0.98:
				continue
			var c := img.get_pixel(x, y)
			total += Vector3(c.r, c.g, c.b)
			count += 1
	if count == 0:
		return Color(1, 0, 1)
	total /= float(count)
	return Color(total.x, total.y, total.z)


func _key(path: String) -> void:
	var img := Image.new()
	if img.load(path) != OK:
		print("  %s okunamadi" % path)
		return
	img.convert(Image.FORMAT_RGBA8)
	var checks := _find_checker(img)
	if checks.is_empty():
		print("  %s: dama deseni bulunamadi - atlandi" % path.get_file())
		return
	var light: float = checks[0]
	var dark: float = checks[1]
	var cell := maxi(_find_cell(img, light, dark), 4)

	var cleared := 0
	var shadowed := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var value := (c.r + c.g + c.b) / 3.0
			var saturation := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			if saturation > MAX_SATURATION:
				continue                      # tinted: this is the artwork
			var ref := light if absf(value - light) < absf(value - dark) else dark
			var delta := value - ref
			if absf(delta) <= KEY_TOLERANCE:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				cleared += 1
			elif delta < 0.0:
				var darkness := clampf(-delta / maxf(ref, 0.001), 0.0, 1.0)
				if darkness >= (1.0 - SHADOW_MIN):
					continue
				img.set_pixel(x, y, Color(0, 0, 0, darkness))
				shadowed += 1
	# Inside a shadow the two checker squares land on different alphas, which
	# leaves the pattern visible as a grid of holes. Averaging the alpha over one
	# checker cell erases a symmetric alternating pattern exactly, while a soft
	# shadow's gradient survives it. Fully opaque artwork is left alone, so the
	# object's own edges stay sharp.
	_smooth_alpha(img, cell)
	var out := path.get_basename() + ".png"
	var err := img.save_png(out)
	print("  %-26s dama=%.2f/%.2f kare=%d silinen=%d golge=%d %s" % [
		path.get_file(), light, dark, cell, cleared, shadowed,
		"ok" if err == OK else "HATA"])


## Box-averages the alpha channel over one checker cell. Separable and running
## sum, so it costs two passes instead of radius-squared per pixel — the naive
## version was 2.2 billion reads per image and took minutes in GDScript.
## Solid artwork keeps its own alpha, so object edges stay sharp.
func _smooth_alpha(img: Image, cell: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var radius := maxi(cell / 2, 2)
	var span := radius * 2 + 1

	var alpha := PackedFloat32Array()
	var solid := PackedByteArray()
	alpha.resize(w * h)
	solid.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var i := y * w + x
			alpha[i] = c.a
			solid[i] = 1 if (c.a >= 0.995 and (c.r + c.g + c.b) > 0.02) else 0

	# Horizontal pass.
	var pass_one := PackedFloat32Array()
	pass_one.resize(w * h)
	for y in h:
		var row := y * w
		var total := 0.0
		for x in range(-radius, radius + 1):
			total += alpha[row + clampi(x, 0, w - 1)]
		for x in w:
			pass_one[row + x] = total / float(span)
			total -= alpha[row + clampi(x - radius, 0, w - 1)]
			total += alpha[row + clampi(x + radius + 1, 0, w - 1)]

	# Vertical pass, written straight back into the image.
	for x in w:
		var total := 0.0
		for y in range(-radius, radius + 1):
			total += pass_one[clampi(y, 0, h - 1) * w + x]
		for y in h:
			var i := y * w + x
			if solid[i] == 0:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, total / float(span)))
			total -= pass_one[clampi(y - radius, 0, h - 1) * w + x]
			total += pass_one[clampi(y + radius + 1, 0, h - 1) * w + x]


## Checker cell size, measured from a clean border row: the distance between
## brightness flips IS the cell width.
func _find_cell(img: Image, light: float, dark: float) -> int:
	var mid := (light + dark) * 0.5
	var y := int(img.get_height() * 0.02)
	var runs: Array[int] = []
	var run := 0
	var was := img.get_pixel(0, y).r > mid
	for x in img.get_width():
		var now := img.get_pixel(x, y).r > mid
		if now == was:
			run += 1
			continue
		if run > 2:
			runs.append(run)
		run = 1
		was = now
	if runs.is_empty():
		return 0
	runs.sort()
	return runs[runs.size() / 2]          # median run length


## The two checker greys, taken from a border strip where the object rarely is.
func _find_checker(img: Image) -> Array:
	var counts := {}
	var w := img.get_width()
	var h := img.get_height()
	for y in range(0, h, 7):
		for x in range(0, w, 7):
			# Border strip only: 6% in from each edge.
			if x > w * 0.06 and x < w * 0.94 and y > h * 0.06 and y < h * 0.94:
				continue
			var c := img.get_pixel(x, y)
			var saturation := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			if saturation > MAX_SATURATION:
				continue
			var bucket := int(round((c.r + c.g + c.b) / 3.0 * 100.0))
			counts[bucket] = int(counts.get(bucket, 0)) + 1
	if counts.size() < 2:
		return []
	var ranked: Array = counts.keys()
	ranked.sort_custom(func(a: int, b: int) -> bool:
		return int(counts[a]) > int(counts[b]))
	# The two most common greys, far enough apart to be a checker rather than
	# one grey plus its own noise.
	var first: float = float(ranked[0]) / 100.0
	for candidate: int in ranked:
		var value := float(candidate) / 100.0
		if absf(value - first) >= 0.05:
			return [maxf(first, value), minf(first, value)]
	return []
