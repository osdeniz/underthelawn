extends SceneTree
## Measures the chakram's outer silhouette from the traced SVG the user supplied
## (textures/chakram1.0.svg) and prints a GDScript outline for BladeMower.
##
## Method: rasterise the SVG, find the filled centroid, then for each angle
## march outward and keep the LAST filled pixel — that is the outer boundary,
## regardless of the trace's interior detail lines. The shape has 4-fold
## symmetry, so the four 90 deg sectors are AVERAGED to cancel trace noise.
## Output is (radius, lateral) in the arm's local frame, scaled so the horn tip
## sits at BLADE_ARM_REACH.

const SAMPLES := 22          # outline points per arm side of the sector
const ANGLE_STEPS := 720     # polar resolution


func _initialize() -> void:
	var tex := load("res://textures/chakram1.0.svg") as Texture2D
	if tex == null:
		print("HATA: chakram1.0.svg yuklenemedi")
		quit(1)
		return
	var img := tex.get_image()
	img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	print("raster: %dx%d format=%d" % [w, h, img.get_format()])

	# Centroid of filled pixels.
	var sx := 0.0
	var sy := 0.0
	var n := 0
	for y in h:
		for x in w:
			if _filled(img, x, y):
				sx += float(x)
				sy += float(y)
				n += 1
	if n == 0:
		print("HATA: dolu piksel yok - SVG saydam mi?")
		quit(1)
		return
	var cx := sx / float(n)
	var cy := sy / float(n)
	print("dolu piksel=%d merkez=(%.1f, %.1f)" % [n, cx, cy])

	# Polar outer radius per angle.
	var max_reach := float(maxi(w, h))
	var radial := PackedFloat32Array()
	radial.resize(ANGLE_STEPS)
	for i in ANGLE_STEPS:
		var a := TAU * float(i) / float(ANGLE_STEPS)
		var dx := cos(a)
		var dy := sin(a)
		var last := 0.0
		var r := 2.0
		while r < max_reach:
			var px := int(cx + dx * r)
			var py := int(cy + dy * r)
			if px < 0 or py < 0 or px >= w or py >= h:
				break
			if _filled(img, px, py):
				last = r
			r += 1.0
		radial[i] = last

	# Arm axis = the angle with the greatest radius.
	var best := 0
	for i in ANGLE_STEPS:
		if radial[i] > radial[best]:
			best = i
	var axis_deg := 360.0 * float(best) / float(ANGLE_STEPS)
	print("en uzak aci=%.1f derece (yaricap %.1f px)" % [axis_deg, radial[best]])

	# Average the four sectors around that axis.
	var quarter := ANGLE_STEPS / 4
	var sector := PackedFloat32Array()
	sector.resize(quarter)
	for k in quarter:
		var acc := 0.0
		for arm in 4:
			var idx := (best - quarter / 2 + k + arm * quarter + ANGLE_STEPS * 2) % ANGLE_STEPS
			acc += radial[idx]
		sector[k] = acc / 4.0

	var peak := 0.0
	for v in sector:
		peak = maxf(peak, v)
	var scale := GameConfig.BLADE_ARM_REACH / peak
	print("olcek=%.5f (zirve %.1f px -> %.2f birim)" % [scale, peak, GameConfig.BLADE_ARM_REACH])

	# Emit the FULL outer contour as one closed polygon. The shape is
	# star-shaped about its centre (every ray meets the boundary exactly once,
	# the crescent notch included), so the polar samples ARE the polygon.
	# Averaging the four sectors first cancels trace noise and forces exact
	# 4-fold symmetry.
	var out_count := 128
	print("")
	print("const PLATE_OUTLINE: Array[Vector2] = [")
	var line := "\t"
	for i in out_count:
		var a := TAU * float(i) / float(out_count)
		# Fold the angle into the averaged sector, then read it back out.
		var fold := fposmod(a - TAU * float(best) / float(ANGLE_STEPS) + PI * 0.25, PI * 0.5)
		var k := int(round(fold / (PI * 0.5) * float(quarter))) % quarter
		var r: float = sector[k] * scale
		line += "Vector2(%.4f, %.4f), " % [cos(a) * r, sin(a) * r]
		if i % 4 == 3:
			print(line)
			line = "\t"
	if line.strip_edges() != "":
		print(line)
	print("]")
	quit()


static func _filled(img: Image, x: int, y: int) -> bool:
	var c := img.get_pixel(x, y)
	# potrace output is black fill on a transparent ground; accept either an
	# alpha shape or a dark-on-light one.
	if c.a > 0.5:
		return c.a > 0.5 and (c.r + c.g + c.b) < 2.4
	return false
