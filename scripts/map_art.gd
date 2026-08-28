class_name MapArt
extends RefCounted
## The drawn half of the case map (G13.5).
##
## Every mark on both layers is generated: parchment as an ImageTexture, roads,
## the creek, the square and the pins as `draw_*` calls. Hand-painted sheets can
## replace the parchment by dropping `textures/map/world_map.png` or
## `town_map.png` in; the ink is always drawn on top, so the pins stay readable
## either way.
##
## Kept out of TownMap so the screen file stays about behaviour and this one
## stays about marks on paper.

static var _sheets := {}


## A parchment sheet: warm paper, blotches, and a darker rim, in a texture the
## screen can stretch. Cached per seed — this is not cheap to build.
static func parchment(size: int, seed_value: int) -> ImageTexture:
	if _sheets.has(seed_value):
		return _sheets[seed_value]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.012
	var grain := FastNoiseLite.new()
	grain.seed = seed_value + 1
	grain.frequency = 0.22
	var half := float(size) * 0.5
	for y in size:
		for x in size:
			var blot := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var fleck := grain.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var shade := lerpf(0.88, 1.06, blot) * lerpf(0.97, 1.03, fleck)
			# The rim is darker and warmer: old paper, handled at the edges.
			var to_edge := maxf(absf(float(x) - half), absf(float(y) - half)) / half
			var rim := clampf((to_edge - 0.62) * 2.4, 0.0, 1.0)
			var c := GameConfig.MAP_PARCHMENT.lerp(
				GameConfig.MAP_PARCHMENT_DARK, rim * 0.75) * shade
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	var tex := ImageTexture.create_from_image(img)
	_sheets[seed_value] = tex
	return tex


# ---------------------------------------------------------------- region

## The wider region: a coast down the west, hills, and the roads leaving town.
## Everything except our own circle is drawn faint — the world exists and is
## closed, which is the whole job of that layer.
static func draw_region(canvas: Control, rect: Rect2, clouds: float) -> void:
	var faint := GameConfig.MAP_INK_FAINT
	# Coast: a wavering line down the left, with water hatching beyond it.
	var coast := PackedVector2Array()
	for i in 22:
		var t := float(i) / 21.0
		var x := 0.10 + sin(t * 6.0) * 0.022 + t * 0.03
		coast.append(rect.position + rect.size * Vector2(x, t))
	canvas.draw_polyline(coast, GameConfig.MAP_WATER, 4.0, true)
	for i in 14:
		var t := float(i) / 13.0
		var from := rect.position + rect.size * Vector2(0.02, 0.04 + t * 0.92)
		var to := from + Vector2(rect.size.x * 0.05, 0.0)
		canvas.draw_line(from, to, Color(0.44, 0.56, 0.58, 0.35), 2.0, true)

	# Hills across the north and east, as simple humps.
	var hill_rng := RandomNumberGenerator.new()
	hill_rng.seed = 33
	# Hills, drawn in a firmer ink than the fog that goes over them: at the old
	# alpha the whole region read as blank paper.
	var hill_ink := Color(0.40, 0.32, 0.24, 0.75)
	for i in 22:
		var at := rect.position + rect.size * Vector2(
			0.16 + hill_rng.randf() * 0.80, 0.08 + hill_rng.randf() * 0.56)
		var w := rect.size.x * hill_rng.randf_range(0.05, 0.11)
		_hump(canvas, at, w, hill_ink)
		# A second, smaller hump behind each: ranges, not lone bumps.
		_hump(canvas, at + Vector2(w * 0.34, -w * 0.16), w * 0.62,
			Color(hill_ink.r, hill_ink.g, hill_ink.b, 0.45))

	# Roads: two that leave town and run off the sheet, one of them east.
	_ink_path(canvas, rect, [Vector2(0.36, 0.56), Vector2(0.52, 0.50),
		Vector2(0.70, 0.47), Vector2(0.95, 0.42)], faint, 3.0)
	_ink_path(canvas, rect, [Vector2(0.36, 0.56), Vector2(0.30, 0.74),
		Vector2(0.22, 0.94)], faint, 3.0)

	# Fog over everything that is not ours. Drifts, very slowly.
	var drift := sin(clouds * 0.35) * rect.size.x * 0.02
	canvas.draw_rect(rect, Color(0.80, 0.74, 0.62, 0.30))
	for i in 5:
		var band := Rect2(rect.position + Vector2(drift, rect.size.y * 0.16 * float(i)),
			Vector2(rect.size.x, rect.size.y * 0.10))
		canvas.draw_rect(band, Color(0.84, 0.78, 0.66, 0.10))


## The town's own mark on the region map: a cluster of roofs.
static func draw_town_mark(canvas: Control, at: Vector2, radius: float,
		ink: Color) -> void:
	for spec: Vector2 in [Vector2(-0.7, 0.1), Vector2(0.0, -0.2), Vector2(0.7, 0.15)]:
		var base := at + Vector2(spec.x * radius, spec.y * radius)
		var w := radius * 0.5
		canvas.draw_rect(Rect2(base - Vector2(w * 0.5, 0.0),
			Vector2(w, w * 0.9)), ink)
		var roof := PackedVector2Array([
			base + Vector2(-w * 0.62, 0.0), base + Vector2(0.0, -w * 0.62),
			base + Vector2(w * 0.62, 0.0)])
		canvas.draw_colored_polygon(roof, ink)


# ---------------------------------------------------------------- town

## The town sheet: the square, the paths out of it, the creek and its bridge,
## and blocks of plots. Laid out to agree with the diorama.
static func draw_town(canvas: Control, rect: Rect2, clouds: float) -> void:
	var ink := GameConfig.MAP_INK
	var faint := GameConfig.MAP_INK_FAINT

	# The creek: north-west to south-east, through the low ground.
	var creek := PackedVector2Array()
	for i in 24:
		var t := float(i) / 23.0
		var x := 0.30 + t * 0.52
		var y := 0.30 + t * 0.52 + sin(t * 5.0) * 0.05
		creek.append(rect.position + rect.size * Vector2(x, y))
	canvas.draw_polyline(creek, GameConfig.MAP_WATER, 9.0, true)
	canvas.draw_polyline(creek, Color(0.58, 0.70, 0.70, 0.5), 4.0, true)

	var square := rect.position + rect.size * Vector2(0.45, 0.46)
	# Paths from the square to each quarter of the town.
	for target: Vector2 in [Vector2(0.20, 0.70), Vector2(0.30, 0.64),
			Vector2(0.64, 0.58), Vector2(0.74, 0.40), Vector2(0.24, 0.36),
			Vector2(0.85, 0.31)]:
		_ink_path(canvas, rect, [Vector2(0.45, 0.46), target], faint, 5.0)

	# The bridge, where the main path meets the creek.
	var bridge := rect.position + rect.size * Vector2(0.575, 0.60)
	canvas.draw_line(bridge + Vector2(-22, -14), bridge + Vector2(22, -14), ink, 4.0)
	canvas.draw_line(bridge + Vector2(-22, 14), bridge + Vector2(22, 14), ink, 4.0)

	# The square itself.
	canvas.draw_circle(square, rect.size.x * 0.045, Color(0.72, 0.66, 0.52, 0.85))
	canvas.draw_arc(square, rect.size.x * 0.045, 0.0, TAU, 32, ink, 3.0, true)

	# Plot blocks: faint rectangles that make the paper read as a settlement
	# rather than a diagram.
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	for i in 26:
		var at := Vector2(0.12 + rng.randf() * 0.78, 0.16 + rng.randf() * 0.72)
		if at.distance_to(Vector2(0.45, 0.46)) < 0.07:
			continue
		var box := Rect2(rect.position + rect.size * at,
			Vector2(rect.size.x * rng.randf_range(0.03, 0.06),
				rect.size.y * rng.randf_range(0.012, 0.028)))
		canvas.draw_rect(box, Color(0.55, 0.46, 0.34, 0.22))
		canvas.draw_rect(box, Color(0.40, 0.32, 0.22, 0.35), false, 1.5)

	# A cloud shadow crossing the paper, so the map is not a still image.
	var shadow_x := fmod(clouds * 0.06, 1.4) - 0.2
	canvas.draw_rect(Rect2(rect.position
		+ Vector2(rect.size.x * shadow_x, 0.0),
		Vector2(rect.size.x * 0.22, rect.size.y)),
		Color(0.30, 0.26, 0.18, 0.05))


# ---------------------------------------------------------------- pieces

## A map pin: a teardrop with a ring, in the state's colour.
static func draw_pin(canvas: Control, at: Vector2, radius: float,
		colour: Color) -> void:
	var tip := at + Vector2(0.0, radius * 1.5)
	var body := PackedVector2Array([
		at + Vector2(-radius * 0.72, radius * 0.34), tip,
		at + Vector2(radius * 0.72, radius * 0.34)])
	canvas.draw_colored_polygon(body, colour.darkened(0.15))
	canvas.draw_circle(at, radius, colour.darkened(0.3))
	canvas.draw_circle(at, radius * 0.84, colour)
	canvas.draw_circle(at, radius * 0.52, colour.lightened(0.45))


## A restored building on the town map: a roofed box.
static func draw_building(canvas: Control, at: Vector2, radius: float) -> void:
	var wall := Color(0.86, 0.80, 0.66)
	var ink := GameConfig.MAP_INK
	var box := Rect2(at - Vector2(radius, radius * 0.2),
		Vector2(radius * 2.0, radius * 1.2))
	canvas.draw_rect(box, wall)
	canvas.draw_rect(box, ink, false, 2.0)
	var roof := PackedVector2Array([
		at + Vector2(-radius * 1.15, -radius * 0.2),
		at + Vector2(0.0, -radius * 1.1),
		at + Vector2(radius * 1.15, -radius * 0.2)])
	canvas.draw_colored_polygon(roof, Color(0.58, 0.32, 0.26))


## A dashed line, for the route already walked.
static func draw_dotted(canvas: Control, from: Vector2, to: Vector2,
		colour: Color, width: float, step: float) -> void:
	var span := from.distance_to(to)
	if span < 1.0:
		return
	var dir := (to - from) / span
	var travelled := 0.0
	while travelled < span:
		var a := from + dir * travelled
		var b := from + dir * minf(travelled + step * 0.55, span)
		canvas.draw_line(a, b, colour, width, true)
		travelled += step


## A path drawn through fractional points, with a pale casing under the ink so
## it reads as a road rather than a pencil stroke.
static func _ink_path(canvas: Control, rect: Rect2, points: Array,
		colour: Color, width: float) -> void:
	var line := PackedVector2Array()
	for point_any: Variant in points:
		line.append(rect.position + rect.size * (point_any as Vector2))
	if line.size() < 2:
		return
	canvas.draw_polyline(line, Color(0.90, 0.84, 0.68, 0.6), width + 4.0, true)
	canvas.draw_polyline(line, colour, width, true)


static func _hump(canvas: Control, at: Vector2, width: float,
		colour: Color) -> void:
	var arc := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		arc.append(at + Vector2((t - 0.5) * width, -sin(t * PI) * width * 0.46))
	canvas.draw_polyline(arc, colour, 3.0, true)
